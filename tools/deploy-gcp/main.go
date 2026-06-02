// Package main provides the GCP deploy tool for nethermind-tdx images.
//
// Mirrors tools/deploy-azure: clone repo, `make build GCP=true` produces a
// tar.gz (containing disk.raw), then `go run tools/deploy-gcp/main.go deploy
// --disk-path build/<image>.tar.gz ...` uploads it to a user-supplied GCS
// bucket, creates a GCE image with TDX guest-OS features, opens the prover
// firewall ports, and launches a Confidential VM with TDX enabled.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/storage"
	"github.com/spf13/cobra"
	"google.golang.org/protobuf/proto"
)

const (
	projectTag = "surgetdx"
)

// firewallPorts is the same set of TCP ports the Azure NSG opens for the
// prover stack. Defined once so deploy + delete refer to the same list.
var firewallPorts = []string{
	"22",    // SSH (restricted by source range)
	"8080",  // raiko2 / tdx-init webserver
	"8545",  // execution client JSON-RPC HTTP
	"8551",  // engine API (JWT)
	"8645",
	"8745",
	"8018",
	"8547",  // L2 execution client (taiko)
	"8548",
	"8552",
	"30303", // p2p (TCP+UDP — UDP handled by separate rule)
	"30313",
}

// DeploymentInfo is persisted to ~/.surgetdx/deployments-gcp/<id>.json so
// `delete` can tear down exactly the resources `deploy` created.
type DeploymentInfo struct {
	ID                 string    `json:"id"`
	ProjectID          string    `json:"project_id"`
	Zone               string    `json:"zone"`
	Region             string    `json:"region"`
	InstanceName       string    `json:"instance_name"`
	ImageName          string    `json:"image_name"`
	DataDiskName       string    `json:"data_disk_name"`
	Network            string    `json:"network"`
	Subnetwork         string    `json:"subnetwork"`
	FirewallSSHName    string    `json:"firewall_ssh_name"`
	FirewallSvcsName   string    `json:"firewall_services_name"`
	FirewallP2PName    string    `json:"firewall_p2p_name"`
	Bucket             string    `json:"bucket"`
	StagingObject      string    `json:"staging_object"`
	CreatedAt          time.Time `json:"created_at"`
}

// GCPClient bundles the long-lived clients we use across resource operations.
type GCPClient struct {
	ctx        context.Context
	projectID  string
	instances  *compute.InstancesClient
	images     *compute.ImagesClient
	disks      *compute.DisksClient
	firewalls  *compute.FirewallsClient
	storage    *storage.Client
}

func main() {
	rootCmd := &cobra.Command{
		Use:   "surgetdx-vm-gcp",
		Short: "GCP VM deployment tool for SurgeTDX / Taiko TDX images",
	}

	deployCmd := &cobra.Command{
		Use:   "deploy",
		Short: "Deploy a new TDX confidential VM",
		RunE:  deployCommand,
	}

	deleteCmd := &cobra.Command{
		Use:   "delete [deployment-id]",
		Short: "Delete a deployment (and its image, firewall rules, staging object)",
		Args:  cobra.ExactArgs(1),
		RunE:  deleteCommand,
	}

	listCmd := &cobra.Command{
		Use:   "list",
		Short: "List all deployments",
		RunE:  listCommand,
	}

	deployCmd.Flags().String("id", "", "Deployment ID (required)")
	deployCmd.Flags().String("disk-path", "", "Path to the .tar.gz image produced by `make build GCP=true` (required)")
	deployCmd.Flags().String("project", "", "GCP project ID (required)")
	deployCmd.Flags().String("zone", "us-central1-a", "GCE zone (must support the chosen machine type / TDX)")
	deployCmd.Flags().String("machine-type", "c3-standard-4", "GCE machine type (must be TDX-capable, e.g. c3-standard-*)")
	deployCmd.Flags().Int("storage-gb", 100, "Size of the attached data disk in GB")
	deployCmd.Flags().String("allowed-ip", "0.0.0.0/0", "CIDR allowed to reach SSH (port 22)")
	deployCmd.Flags().String("network", "default", "VPC network name")
	deployCmd.Flags().String("subnetwork", "", "Subnetwork (defaults to the network's auto subnet in the chosen region)")
	deployCmd.Flags().String("bucket", "", "GCS bucket used to stage the image (required; user-managed)")
	deployCmd.Flags().Bool("keep-staging", false, "Keep the uploaded tar.gz in the bucket after image creation")

	for _, name := range []string{"id", "disk-path", "project", "bucket"} {
		_ = deployCmd.MarkFlagRequired(name)
	}

	rootCmd.AddCommand(deployCmd, deleteCmd, listCmd)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func createGCPClient(ctx context.Context, projectID string) (*GCPClient, error) {
	c := &GCPClient{ctx: ctx, projectID: projectID}

	var err error
	if c.instances, err = compute.NewInstancesRESTClient(ctx); err != nil {
		return nil, fmt.Errorf("instances client: %w", err)
	}
	if c.images, err = compute.NewImagesRESTClient(ctx); err != nil {
		return nil, fmt.Errorf("images client: %w", err)
	}
	if c.disks, err = compute.NewDisksRESTClient(ctx); err != nil {
		return nil, fmt.Errorf("disks client: %w", err)
	}
	if c.firewalls, err = compute.NewFirewallsRESTClient(ctx); err != nil {
		return nil, fmt.Errorf("firewalls client: %w", err)
	}
	if c.storage, err = storage.NewClient(ctx); err != nil {
		return nil, fmt.Errorf("storage client: %w", err)
	}
	return c, nil
}

func (c *GCPClient) close() {
	if c == nil {
		return
	}
	_ = c.instances.Close()
	_ = c.images.Close()
	_ = c.disks.Close()
	_ = c.firewalls.Close()
	_ = c.storage.Close()
}

func deployCommand(cmd *cobra.Command, _ []string) error {
	ctx := context.Background()

	deploymentID, _ := cmd.Flags().GetString("id")
	diskPath, _ := cmd.Flags().GetString("disk-path")
	projectID, _ := cmd.Flags().GetString("project")
	zone, _ := cmd.Flags().GetString("zone")
	machineType, _ := cmd.Flags().GetString("machine-type")
	storageGB, _ := cmd.Flags().GetInt("storage-gb")
	allowedIP, _ := cmd.Flags().GetString("allowed-ip")
	network, _ := cmd.Flags().GetString("network")
	subnetwork, _ := cmd.Flags().GetString("subnetwork")
	bucket, _ := cmd.Flags().GetString("bucket")
	keepStaging, _ := cmd.Flags().GetBool("keep-staging")

	// Region is derived from zone (e.g. us-central1-a -> us-central1) and is
	// used to name the default auto-subnetwork.
	region, err := regionFromZone(zone)
	if err != nil {
		return err
	}

	deploymentFile := getDeploymentFile(deploymentID)
	if _, err := os.Stat(deploymentFile); err == nil {
		return fmt.Errorf("deployment with ID '%s' already exists", deploymentID)
	}

	diskInfo, err := os.Stat(diskPath)
	if err != nil {
		return fmt.Errorf("failed to stat disk file: %w", err)
	}

	client, err := createGCPClient(ctx, projectID)
	if err != nil {
		return err
	}
	defer client.close()

	resourceBase := fmt.Sprintf("%s-%s", projectTag, sanitizeID(deploymentID))
	stagingObject := fmt.Sprintf("%s.tar.gz", resourceBase)
	deployment := DeploymentInfo{
		ID:               deploymentID,
		ProjectID:        projectID,
		Zone:             zone,
		Region:           region,
		InstanceName:     resourceBase,
		ImageName:        resourceBase,
		DataDiskName:     fmt.Sprintf("%s-storage", resourceBase),
		Network:          network,
		Subnetwork:       subnetwork,
		FirewallSSHName:  fmt.Sprintf("%s-allow-ssh", resourceBase),
		FirewallSvcsName: fmt.Sprintf("%s-allow-svcs", resourceBase),
		FirewallP2PName:  fmt.Sprintf("%s-allow-p2p", resourceBase),
		Bucket:           bucket,
		StagingObject:    stagingObject,
		CreatedAt:        time.Now(),
	}

	fmt.Println()
	fmt.Println("📋 Deployment Configuration:")
	fmt.Println("─────────────────────────────────────────────────────────────")
	fmt.Printf("   Deployment ID:     %s\n", deploymentID)
	fmt.Printf("   Project:           %s\n", projectID)
	fmt.Printf("   Zone / Region:     %s / %s\n", zone, region)
	fmt.Printf("   Machine type:      %s\n", machineType)
	fmt.Printf("   Disk image:        %s (%.1f GB)\n", diskPath, float64(diskInfo.Size())/(1024*1024*1024))
	fmt.Printf("   Data disk:         %d GB\n", storageGB)
	fmt.Printf("   SSH allowed CIDR:  %s\n", allowedIP)
	fmt.Printf("   Network:           %s\n", network)
	if subnetwork != "" {
		fmt.Printf("   Subnetwork:        %s\n", subnetwork)
	}
	fmt.Printf("   Staging bucket:    gs://%s/%s\n", bucket, stagingObject)
	fmt.Println("─────────────────────────────────────────────────────────────")

	fmt.Printf("\n🚀 Starting deployment '%s' in project '%s'...\n", deploymentID, projectID)

	fmt.Println("⬆️  Uploading disk image to GCS...")
	if err := uploadToGCS(client, bucket, stagingObject, diskPath); err != nil {
		return fmt.Errorf("failed to upload disk image: %w", err)
	}

	fmt.Println("📦 Creating GCE image with TDX guest-OS features...")
	if err := createImage(client, deployment); err != nil {
		_ = deleteStagingObject(client, deployment) // best-effort cleanup
		return fmt.Errorf("failed to create image: %w", err)
	}

	fmt.Println("💾 Creating data disk...")
	if err := createDataDisk(client, deployment, int64(storageGB)); err != nil {
		return fmt.Errorf("failed to create data disk: %w", err)
	}

	fmt.Println("🔒 Creating firewall rules...")
	if err := createFirewallRules(client, deployment, allowedIP); err != nil {
		return fmt.Errorf("failed to create firewall rules: %w", err)
	}

	fmt.Println("🖥️  Creating confidential VM...")
	if err := createInstance(client, deployment, machineType); err != nil {
		return fmt.Errorf("failed to create VM: %w", err)
	}

	if err := saveDeploymentInfo(deployment); err != nil {
		return fmt.Errorf("failed to save deployment info: %w", err)
	}

	externalIP := getInstanceExternalIP(client, deployment)

	if !keepStaging {
		fmt.Println("🧹 Removing staging object (image is detached from the upload now)...")
		if err := deleteStagingObject(client, deployment); err != nil {
			fmt.Printf("⚠️  Could not delete staging object: %v\n", err)
		} else {
			deployment.StagingObject = "" // mark deleted in saved state
			_ = saveDeploymentInfo(deployment)
		}
	}

	fmt.Println("\n✅ Deployment completed successfully!")
	fmt.Println("\n📋 Deployment Details:")
	fmt.Printf("   ID:                %s\n", deployment.ID)
	fmt.Printf("   Project:           %s\n", deployment.ProjectID)
	fmt.Printf("   Zone:              %s\n", deployment.Zone)
	fmt.Printf("   Instance:          %s\n", deployment.InstanceName)
	if externalIP != "" {
		fmt.Printf("   External IP:       %s\n", externalIP)
		fmt.Println("\n💻 Next steps:")
		fmt.Printf("   1. Inject your SSH key:\n")
		fmt.Printf("        curl -X POST -d \"$(cut -d' ' -f2 ~/.ssh/id_ed25519.pub)\" http://%s:8080\n", externalIP)
		fmt.Printf("   2. SSH into the VM:\n")
		fmt.Printf("        ssh root@%s\n", externalIP)
	} else {
		fmt.Println("   External IP:       (not yet assigned — check `gcloud compute instances describe`)")
	}
	fmt.Println("\n🗑️  To delete this deployment:")
	fmt.Printf("   go run tools/deploy-gcp/main.go delete %s\n", deploymentID)
	return nil
}

// uploadToGCS streams the local file into the user-supplied bucket. Object
// naming is deterministic so `delete` can find and remove it.
func uploadToGCS(client *GCPClient, bucket, object, localPath string) error {
	f, err := os.Open(localPath)
	if err != nil {
		return err
	}
	defer f.Close()

	// Per docs the writer is committed on Close(). Use a long timeout so large
	// images on slow networks still succeed.
	ctx, cancel := context.WithTimeout(client.ctx, 2*time.Hour)
	defer cancel()

	w := client.storage.Bucket(bucket).Object(object).NewWriter(ctx)
	w.ChunkSize = 16 * 1024 * 1024 // 16 MiB resumable chunks
	w.ContentType = "application/gzip"
	if _, err := io.Copy(w, f); err != nil {
		_ = w.Close()
		return fmt.Errorf("upload to gs://%s/%s: %w", bucket, object, err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("finalize upload gs://%s/%s: %w", bucket, object, err)
	}
	return nil
}

func deleteStagingObject(client *GCPClient, d DeploymentInfo) error {
	if d.Bucket == "" || d.StagingObject == "" {
		return nil
	}
	return client.storage.Bucket(d.Bucket).Object(d.StagingObject).Delete(client.ctx)
}

// createImage builds a GCE Image from the uploaded tar.gz. The two
// guest-OS-features we set are what makes the image usable on TDX-capable
// confidential VMs.
func createImage(client *GCPClient, d DeploymentInfo) error {
	rawSource := fmt.Sprintf("https://storage.googleapis.com/%s/%s", d.Bucket, d.StagingObject)
	req := &computepb.InsertImageRequest{
		Project: d.ProjectID,
		ImageResource: &computepb.Image{
			Name:        proto.String(d.ImageName),
			Description: proto.String(fmt.Sprintf("SurgeTDX image for deployment %s", d.ID)),
			RawDisk: &computepb.RawDisk{
				Source:        proto.String(rawSource),
				ContainerType: proto.String("TAR"),
			},
			GuestOsFeatures: []*computepb.GuestOsFeature{
				// UEFI_COMPATIBLE: image boots via the UEFI firmware (the disk
				//   is a GPT/ESP layout produced by mkosi.profiles/gcp/mkosi.postoutput).
				// TDX_CAPABLE: lets the image be used on Intel TDX confidential VMs.
				// GVNIC: C3 machine types (the only TDX-capable family) support
				//   *only* the Google Virtual NIC. Without this feature the image
				//   cannot be attached to a C3 instance and creation fails.
				// VIRTIO_SCSI_MULTIQUEUE: recommended for disk throughput on C3.
				{Type: proto.String("UEFI_COMPATIBLE")},
				{Type: proto.String("TDX_CAPABLE")},
				{Type: proto.String("GVNIC")},
				{Type: proto.String("VIRTIO_SCSI_MULTIQUEUE")},
			},
			Labels: map[string]string{
				"project":    projectTag,
				"deployment": sanitizeID(d.ID),
			},
		},
	}
	op, err := client.images.Insert(client.ctx, req)
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func createDataDisk(client *GCPClient, d DeploymentInfo, sizeGB int64) error {
	req := &computepb.InsertDiskRequest{
		Project: d.ProjectID,
		Zone:    d.Zone,
		DiskResource: &computepb.Disk{
			Name:   proto.String(d.DataDiskName),
			SizeGb: proto.Int64(sizeGB),
			Type:   proto.String(fmt.Sprintf("zones/%s/diskTypes/pd-ssd", d.Zone)),
			Labels: map[string]string{
				"project":    projectTag,
				"deployment": sanitizeID(d.ID),
			},
		},
	}
	op, err := client.disks.Insert(client.ctx, req)
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

// createFirewallRules attaches three rules to the project's VPC, all scoped to
// instances tagged with the deployment ID so they don't affect other VMs:
//   - SSH: TCP/22 from `allowedIP`
//   - Services: TCP/<prover ports>, from anywhere
//   - P2P: UDP/30303 (TCP/30303 is part of the services rule)
func createFirewallRules(client *GCPClient, d DeploymentInfo, allowedIP string) error {
	tag := instanceTag(d.ID)

	// Split SSH out because it has a narrower source range.
	ssh := &computepb.Firewall{
		Name:        proto.String(d.FirewallSSHName),
		Network:     proto.String(fmt.Sprintf("global/networks/%s", d.Network)),
		Direction:   proto.String("INGRESS"),
		Priority:    proto.Int32(1000),
		TargetTags:  []string{tag},
		SourceRanges: []string{allowedIP},
		Allowed: []*computepb.Allowed{{
			IPProtocol: proto.String("tcp"),
			Ports:      []string{"22"},
		}},
	}

	servicePorts := make([]string, 0, len(firewallPorts)-1)
	for _, p := range firewallPorts {
		if p == "22" {
			continue
		}
		servicePorts = append(servicePorts, p)
	}
	svcs := &computepb.Firewall{
		Name:         proto.String(d.FirewallSvcsName),
		Network:      proto.String(fmt.Sprintf("global/networks/%s", d.Network)),
		Direction:    proto.String("INGRESS"),
		Priority:     proto.Int32(1001),
		TargetTags:   []string{tag},
		SourceRanges: []string{"0.0.0.0/0"},
		Allowed: []*computepb.Allowed{{
			IPProtocol: proto.String("tcp"),
			Ports:      servicePorts,
		}},
	}

	p2p := &computepb.Firewall{
		Name:         proto.String(d.FirewallP2PName),
		Network:      proto.String(fmt.Sprintf("global/networks/%s", d.Network)),
		Direction:    proto.String("INGRESS"),
		Priority:     proto.Int32(1002),
		TargetTags:   []string{tag},
		SourceRanges: []string{"0.0.0.0/0"},
		Allowed: []*computepb.Allowed{{
			IPProtocol: proto.String("udp"),
			Ports:      []string{"30303"},
		}},
	}

	for _, fw := range []*computepb.Firewall{ssh, svcs, p2p} {
		op, err := client.firewalls.Insert(client.ctx, &computepb.InsertFirewallRequest{
			Project:          d.ProjectID,
			FirewallResource: fw,
		})
		if err != nil {
			return fmt.Errorf("insert firewall %s: %w", fw.GetName(), err)
		}
		if err := op.Wait(client.ctx); err != nil {
			return fmt.Errorf("wait firewall %s: %w", fw.GetName(), err)
		}
	}
	return nil
}

func createInstance(client *GCPClient, d DeploymentInfo, machineType string) error {
	netIface := &computepb.NetworkInterface{
		Network: proto.String(fmt.Sprintf("global/networks/%s", d.Network)),
		// C3 (the TDX-capable family) only supports the Google Virtual NIC.
		// Pin it explicitly so creation doesn't fall back to VIRTIO_NET.
		NicType: proto.String("GVNIC"),
		AccessConfigs: []*computepb.AccessConfig{{
			Type: proto.String("ONE_TO_ONE_NAT"),
			Name: proto.String("External NAT"),
		}},
	}
	if d.Subnetwork != "" {
		netIface.Subnetwork = proto.String(fmt.Sprintf("regions/%s/subnetworks/%s", d.Region, d.Subnetwork))
	}

	imageURL := fmt.Sprintf("projects/%s/global/images/%s", d.ProjectID, d.ImageName)

	instance := &computepb.Instance{
		Name:        proto.String(d.InstanceName),
		MachineType: proto.String(fmt.Sprintf("zones/%s/machineTypes/%s", d.Zone, machineType)),
		Tags: &computepb.Tags{
			Items: []string{instanceTag(d.ID)},
		},
		Disks: []*computepb.AttachedDisk{
			{
				Boot:       proto.Bool(true),
				AutoDelete: proto.Bool(true),
				InitializeParams: &computepb.AttachedDiskInitializeParams{
					SourceImage: proto.String(imageURL),
					DiskSizeGb:  proto.Int64(20),
				},
			},
			{
				Boot:       proto.Bool(false),
				AutoDelete: proto.Bool(false),
				Source:     proto.String(fmt.Sprintf("zones/%s/disks/%s", d.Zone, d.DataDiskName)),
			},
		},
		NetworkInterfaces: []*computepb.NetworkInterface{netIface},
		ShieldedInstanceConfig: &computepb.ShieldedInstanceConfig{
			EnableVtpm:                proto.Bool(true),
			EnableIntegrityMonitoring: proto.Bool(true),
			EnableSecureBoot:          proto.Bool(false),
		},
		ConfidentialInstanceConfig: &computepb.ConfidentialInstanceConfig{
			ConfidentialInstanceType: proto.String("TDX"),
		},
		// TDX VMs can't migrate live and must restart on host maintenance.
		// OnHostMaintenance MUST be TERMINATE for confidential VMs; keep
		// AutomaticRestart so the prover comes back after a host event.
		Scheduling: &computepb.Scheduling{
			OnHostMaintenance: proto.String("TERMINATE"),
			AutomaticRestart:  proto.Bool(true),
		},
		Labels: map[string]string{
			"project":    projectTag,
			"deployment": sanitizeID(d.ID),
		},
	}

	op, err := client.instances.Insert(client.ctx, &computepb.InsertInstanceRequest{
		Project:          d.ProjectID,
		Zone:             d.Zone,
		InstanceResource: instance,
	})
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func getInstanceExternalIP(client *GCPClient, d DeploymentInfo) string {
	inst, err := client.instances.Get(client.ctx, &computepb.GetInstanceRequest{
		Project:  d.ProjectID,
		Zone:     d.Zone,
		Instance: d.InstanceName,
	})
	if err != nil {
		return ""
	}
	for _, ni := range inst.GetNetworkInterfaces() {
		for _, ac := range ni.GetAccessConfigs() {
			if ip := ac.GetNatIP(); ip != "" {
				return ip
			}
		}
	}
	return ""
}

func deleteCommand(_ *cobra.Command, args []string) error {
	ctx := context.Background()
	deploymentID := args[0]

	d, err := loadDeploymentInfo(deploymentID)
	if err != nil {
		return fmt.Errorf("failed to load deployment info: %w", err)
	}

	fmt.Printf("This will delete all resources for deployment '%s':\n", deploymentID)
	fmt.Printf("  - Instance:        %s\n", d.InstanceName)
	fmt.Printf("  - Boot image:      %s\n", d.ImageName)
	fmt.Printf("  - Data disk:       %s\n", d.DataDiskName)
	fmt.Printf("  - Firewall rules:  %s, %s, %s\n", d.FirewallSSHName, d.FirewallSvcsName, d.FirewallP2PName)
	if d.StagingObject != "" {
		fmt.Printf("  - Staging object:  gs://%s/%s\n", d.Bucket, d.StagingObject)
	}

	fmt.Print("\nAre you sure you want to continue? [y/N]: ")
	var response string
	_, _ = fmt.Scanln(&response)
	if strings.ToLower(response) != "y" && strings.ToLower(response) != "yes" {
		fmt.Println("Deletion cancelled.")
		return nil
	}

	client, err := createGCPClient(ctx, d.ProjectID)
	if err != nil {
		return err
	}
	defer client.close()

	fmt.Println("\n🗑️  Deleting resources...")

	fmt.Println("  Deleting instance...")
	if err := deleteInstance(client, d); err != nil {
		fmt.Printf("  ⚠️  Failed to delete instance: %v\n", err)
	}

	fmt.Println("  Deleting data disk...")
	if err := deleteDataDisk(client, d); err != nil {
		fmt.Printf("  ⚠️  Failed to delete data disk: %v\n", err)
	}

	for _, fw := range []string{d.FirewallSSHName, d.FirewallSvcsName, d.FirewallP2PName} {
		fmt.Printf("  Deleting firewall %s...\n", fw)
		if err := deleteFirewall(client, d.ProjectID, fw); err != nil {
			fmt.Printf("  ⚠️  Failed to delete firewall %s: %v\n", fw, err)
		}
	}

	fmt.Println("  Deleting image...")
	if err := deleteImage(client, d); err != nil {
		fmt.Printf("  ⚠️  Failed to delete image: %v\n", err)
	}

	if d.StagingObject != "" {
		fmt.Println("  Deleting staging object...")
		if err := deleteStagingObject(client, d); err != nil {
			fmt.Printf("  ⚠️  Failed to delete staging object: %v\n", err)
		}
	}

	_ = os.Remove(getDeploymentFile(deploymentID))
	fmt.Println("\n✅ Deployment deleted.")
	return nil
}

func deleteInstance(client *GCPClient, d DeploymentInfo) error {
	op, err := client.instances.Delete(client.ctx, &computepb.DeleteInstanceRequest{
		Project:  d.ProjectID,
		Zone:     d.Zone,
		Instance: d.InstanceName,
	})
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func deleteDataDisk(client *GCPClient, d DeploymentInfo) error {
	op, err := client.disks.Delete(client.ctx, &computepb.DeleteDiskRequest{
		Project: d.ProjectID,
		Zone:    d.Zone,
		Disk:    d.DataDiskName,
	})
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func deleteFirewall(client *GCPClient, projectID, name string) error {
	op, err := client.firewalls.Delete(client.ctx, &computepb.DeleteFirewallRequest{
		Project:  projectID,
		Firewall: name,
	})
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func deleteImage(client *GCPClient, d DeploymentInfo) error {
	op, err := client.images.Delete(client.ctx, &computepb.DeleteImageRequest{
		Project: d.ProjectID,
		Image:   d.ImageName,
	})
	if err != nil {
		return err
	}
	return op.Wait(client.ctx)
}

func listCommand(_ *cobra.Command, _ []string) error {
	deploymentDir := getDeploymentDir()
	entries, err := os.ReadDir(deploymentDir)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("No deployments found.")
			return nil
		}
		return err
	}

	fmt.Println("📋 SurgeTDX GCP Deployments:")
	fmt.Println("─────────────────────────────────────────────────────────────")
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		id := strings.TrimSuffix(entry.Name(), ".json")
		d, err := loadDeploymentInfo(id)
		if err != nil {
			continue
		}
		fmt.Printf("ID: %-15s | Project: %-20s | Zone: %-15s | Created: %s\n",
			d.ID, d.ProjectID, d.Zone, d.CreatedAt.Format("2006-01-02 15:04"))
	}

	if len(entries) == 0 {
		fmt.Println("(no local deployment files found)")
	}
	return nil
}

// instanceTag is what we attach to the VM and target with firewall rules.
// Must match the network-tag format: lowercase letters, digits, hyphens.
func instanceTag(id string) string {
	return fmt.Sprintf("%s-%s", projectTag, sanitizeID(id))
}

// sanitizeID lowercases and replaces invalid chars so a user-supplied id can
// be safely used as part of a GCE resource name / label / network tag.
func sanitizeID(id string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(id) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9', r == '-':
			b.WriteRune(r)
		default:
			b.WriteRune('-')
		}
	}
	return b.String()
}

func regionFromZone(zone string) (string, error) {
	idx := strings.LastIndex(zone, "-")
	if idx <= 0 {
		return "", fmt.Errorf("invalid zone %q (expected e.g. us-central1-a)", zone)
	}
	return zone[:idx], nil
}

func getDeploymentDir() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".surgetdx", "deployments-gcp")
}

func getDeploymentFile(deploymentID string) string {
	return filepath.Join(getDeploymentDir(), fmt.Sprintf("%s.json", deploymentID))
}

func saveDeploymentInfo(d DeploymentInfo) error {
	if err := os.MkdirAll(getDeploymentDir(), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(getDeploymentFile(d.ID), data, 0o644)
}

func loadDeploymentInfo(deploymentID string) (DeploymentInfo, error) {
	var d DeploymentInfo
	data, err := os.ReadFile(getDeploymentFile(deploymentID))
	if err != nil {
		return d, err
	}
	return d, json.Unmarshal(data, &d)
}
