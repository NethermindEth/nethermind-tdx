# Nethermind TDX

This is a repository based on [Flashbots Images](https://github.com/flashbots/flashbots-images) for implementations with Nethermind TDX.

Based on the Flashbots toolkit, this provides a minimal, hardened Linux image designed for confidential computing environments, tailored for the execution of a [Surge](https://www.surge.wtf/) TDX Prover, as well as an Ethereum Full Node. In both of these use-cases, the block execution happens in a trusted environment, allowing for the attestation of such instances as trusted.

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

   # Build with GCP compatibility
   make build IMAGE=surge-tdx-prover GCP=true

   # View all available targets
   make help
   ```

### Measuring TDX Boot Process

**Export TDX measurements** for the built image:
```bash
# Standard TDX measurements
make measure FILE=build/surge-tdx-prover_<version>.efi

# GCP-specific measurements
make measure-gcp FILE=build/surge-tdx-prover_<version>.efi
```

This generates measurement files in the `build/` directory for attestation and verification.

### Running Images

**Create persistent storage** (for stateful applications):
   ```bash
   qemu-img create -f qcow2 persistent.qcow2 2048G
   ```

**Run QEMU**:
  ```bash
  sudo qemu-system-x86_64 \
    -enable-kvm \
    -machine type=q35,smm=on \
    -m 16384M \
    -nographic \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd \
    -drive file=/usr/share/edk2/x64/OVMF_VARS.4m.fd,if=pflash,format=raw \
    -kernel build/surge-tdx-prover_<version>.efi \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-scsi-pci,id=scsi0 \
    -drive file=persistent.qcow2,format=qcow2,if=none,id=disk0 \
    -device scsi-hd,drive=disk0,bus=scsi0.0,channel=0,scsi-id=0,lun=10
  ```

**With TDX confidential computing** (requires TDX-enabled hardware/hypervisor):
  ```bash
  sudo qemu-system-x86_64 \
    -accel kvm \
    -machine type=q35,kernel_irqchip=split,confidential-guest-support=tdx0 \
    -object '{"qom-type":"tdx-guest","id":"tdx0","quote-generation-socket":{"type":"unix","path":"/var/run/tdx-qgs/qgs.socket"}}' \
    -cpu host,-kvm-steal-time,-kvmclock \
    -m 16384M \
    -nographic \
    -kernel build/surge-tdx-prover_<version>.efi \
    # ... rest of options same as above
  ```

> [!NOTE]
>
> Depending on your Linux distro, these commands may require changing the
> supplied OVMF paths or installing your distro's OVMF package.

## Building Without Lima (Unsupported)

### Prerequisites

1. **Install Nix** (single user mode is sufficient):

    ```bash
    sh <(curl -L https://nixos.org/nix/install) --no-daemon
    ```

2. **Enable Nix experimental features** in `~/.config/nix/nix.conf`:

    ```conf
    experimental-features = nix-command flakes
    ```

3. **Install Debian archive keyring** (temporary requirement):

    ```bash
    # On Ubuntu/Debian
    sudo apt install debian-archive-keyring
    # On other systems, download via package manager or use Docker approach below
    ```

### Building

```bash
# Enter the development environment
nix develop -c $SHELL

# Build a specific image
mkosi --force --image-id surge-tdx-prover -I surge-tdx-prover.conf

# Build with profiles
mkosi --force --image-id surge-tdx-prover -I surge-tdx-prover.conf --profile=devtools
mkosi --force --image-id surge-tdx-prover -I surge-tdx-prover.conf --profile=azure
mkosi --force --image-id surge-tdx-prover -I surge-tdx-prover.conf --profile=azure,devtools
mkosi --force --image-id surge-tdx-prover -I surge-tdx-prover.conf --profile=gcp
```

### Troubleshooting

- If you encounter `mkosi was forbidden to unshare namespaces`, try
adding an apparmor profile like so:

  ```bash
    sudo cat <<EOF > /etc/apparmor.d/mkosi
    abi <abi/4.0>,
    include <tunables/global>

    /nix/store/*-mkosi-*/bin/mkosi flags=(default_allow) {
      userns,
    }
    EOF

    sudo systemctl reload apparmor
  ```

- If you encounter `unshare: setgroups failed: Operation not permitted`,
try to disable apparmor's restriction:

  ```bash
  sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0

  sudo -c 'echo "kernel.apparmor_restrict_unprivileged_userns=0" >> /etc/sysctl.conf'
  ```

- If you encounter `bootctl: unrecognized option '--root=/buildroot'`, you'll need to upgrade to a newer version of systemd (at least v250), which is only supported by recent versions of Ubuntu.

## Utilities

### Unpacking Images

To extract the contents of a built image for inspection:

```bash
# Unpack a VHD image
./scripts/unpack_image.sh build/surge-tdx-prover_<version>.vhd

# Unpack a GCP tar.gz image
./scripts/unpack_image.sh build/surge-tdx-prover_<version>.tar.gz

# Unpack an EFI file directly
./scripts/unpack_image.sh build/surge-tdx-prover_<version>.efi
```

This extracts the EFI file, kernel, initrd, and unpacks the initrd contents for inspection.
