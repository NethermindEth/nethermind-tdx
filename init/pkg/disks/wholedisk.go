package disks

import "regexp"

var (
	// Whole SCSI/SATA/virtio-blk disks: sda, sdb, vda, ... — a whole disk has
	// no trailing partition number (sda1 is a partition). Azure attaches data
	// disks via this naming.
	scsiWholeDiskRe = regexp.MustCompile(`^(sd|vd)[a-z]+$`)
	// Whole NVMe namespaces: nvme0n1, nvme1n2, ... — a partition adds a pN
	// suffix (nvme0n1p1). GCP attaches data disks as NVMe.
	nvmeWholeDiskRe = regexp.MustCompile(`^nvme\d+n\d+$`)
)

// isWholeDisk reports whether a /proc/partitions device name refers to a whole
// disk rather than a partition. It understands both SCSI/SATA/virtio (sdX/vdX)
// and NVMe (nvmeXnY) naming so the same image works on Azure (SCSI) and GCP
// (NVMe).
func isWholeDisk(name string) bool {
	return scsiWholeDiskRe.MatchString(name) || nvmeWholeDiskRe.MatchString(name)
}
