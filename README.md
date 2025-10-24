# Nethermind TDX

This is a repository based on [Flashbots Images](https://github.com/flashbots/flashbots-images) for implementations with Nethermind TDX.

Based on the Flashboxes toolkit, this provides a minimal, hardened Linux image designed for confidential computing environments, tailored for the execution of a [Surge](https://www.surge.wtf/) TDX Prover, as well as an Ethereum Full Node. In both of these use-cases, the block execution happens in a trusted environment, allowing for the attestation of such instances as trusted.

## 🚀 Quick Start

### Prerequisites

In order to build images, you'll need to install [Lima](https://lima-vm.io/) for your operating system. Building images without Lima is possible, but due to inconsistencies between distributions, it is not supported for generating official reproducible images.

### Building Images

1. **Enter the development environment**:
   ```bash
   nix develop -c $SHELL
   ```

2. **Build a specific image**:
   ```bash
   # Build the Surge TDX Prover image
   make build IMAGE=surge-tdx-prover

   # Build with development tools
   make build IMAGE=surge-tdx-prover DEV=true
   
   # Build with Azure compatibility and development tools
   make build IMAGE=surge-tdx-prover AZURE=true DEV=true
   ```

### Running Images


**Create persistent storage** (for stateful applications):
   ```bash
   qemu-img create -f qcow2 persistent.qcow2 2048G
   ```

**Run QEMU** (OVMF can be based on EDK2):
    ```bash
    qemu-system-x86_64 \
	-kernel build/tdx-debian.efi \
	-netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 \
	-device virtio-net-pci,netdev=net0 \
	-device virtio-scsi-pci,netdev=scsi0 \
	-drive file=persistent.qcow2,format=qcow2,if=none,id=disk0 \
	-device scsi-hd,drive=disk0,bus=scsi0.0,channel=0,scsi-id=0,lun=10 \
	-accel kvm \
	-machine type=q35,kernel_irqchip=split,confidential-guest-support=tdx0 \
	-object '{"qom-type":"tdx-guest","id":"tdx0","quote-generation-socket":{"type":"unix","path":"/var/run/tdx-qgs/qgs.socket"}}' \
	-cpu host,-kvm-steal-time,-kvmclock \
	-m 16384M \
	-nographic \
	-bios OVMF.fd
    ```
