# Nethermind in TDX

This repository contains an experiment in running the Nethermind execution client
within a TDX TEE (Trusted Execution Environment).

The project is currently based on recent Flashbots experiments with TDX,
specifically:
* [T(EE)-Stack demo: running a validator in TDX](https://collective.flashbots.net/t/t-ee-stack-demo-running-a-validator-in-tdx/3551/5)
* [Building Secure Ethereum Blocks on Minimal Intel TDX Confidential VMs](https://collective.flashbots.net/t/building-secure-ethereum-blocks-on-minimal-intel-tdx-confidential-vms/3795)

The full process involves generating a minimal TDX-compatible VM that includes
the Nethermind client and only essential packages and processes.

This is accomplished using Yocto, an open-source project that helps developers
create custom Linux-based systems. Through Yocto, multiple layers, from
system utilities to applications, are stacked to describe the system's
configuration and build process. This build is reproducible, meaning we can
use the measurement of the resulting image for TDX attestations - any change
in the build process should lead to different measurements.

Currently, we're using the Flashbots Yocto setup as a base and applying minimal
patches to include our layers and recipes while excluding unnecessary ones.

## Building the image

### Environment

First of all, copy the `.env.example` file to `.env` and set the variables
as described in the file.

```bash
cp .env.example .env
```

These variables will apply to both build methods mentioned below. For a test
run, you can leave the variables as is. The `DEBUG_TWEAKS_ENABLED` is
important for a development image, allowing root access to the VM.

For more details on each variable, check your `.env` file.

### Lighthouse

For now, the Lighthouse binary is being built outside the Yocto build process
and the final binary is copied into the image.

In order to build Lighthouse, you need Cargo installed. Check the
[Cargo documentation](https://doc.rust-lang.org/cargo/getting-started/installation.html)
for instructions.

Then, in order to build Lighthouse and copy it into the `meta-lighthouse-bin` layer,
run:

```bash
make setup-lighthouse
```

### Build

There are two options for building the image:
1. Building it locally on a machine with Yocto instaled.
2. Building it through a Docker image.

Both methods are slightly resource-intensive. You need around:
* 4 CPU cores
* 8GB of RAM
* 100GB of free disk space
* For a local build, make sure your OS is supported by Yocto. We're using
Ubuntu 22.04 - not 24.04.

Both methods will take a few hours to complete, and will result in an image
in `artifacts/`. It will also generate a `measurements.json` file in the
`artifacts/` directory, which contains the measurements of the built image.

#### Local Build

Preferably use a specific machine for the build, as this will e.g. install
packages that you might not want to have on your main system. You might also
want to check out the [Docker Build](#docker-build) section for an alternative
approach if you're not using a specific machine for the build.

The local build also requires [Go](https://go.dev/) to be installed. You can
either follow the [official instructions](https://go.dev/doc/install) or
install it by running:

```bash
# either follow the official instructions or run this
make setup-go
source ~/.profile
```

This will install Go on your machine and add it to your PATH through
`~/.profile`.

Then, set up your environment:

```bash
make setup-local
```

This will install some Yocto dependencies, create the `build` and `artifacts`
directories, and also compile the Go [measured-boot](https://github.com/flashbots/measured-boot)
utility.

Finally, build the image:

```bash
# you can use `make setup-git` to set up a mock git user for cloning
make azure-image
```

#### Docker Build

The Docker build follows the same process as the local build, but it runs
inside a Docker container through a specific `Dockerfile`. This allows for
a more isolated and portable environment for compilation, and doesn't
require installing build dependencies directly on the machine.

First, if you don't have Docker installed, install it. You can do it by
running:

```bash
# not needed if you have docker installed already
make setup-docker
```

This will set up the Docker `apt` repository and install Docker in your
machine.

Then, build the image:

```bash
make azure-image-docker
```

## Running the image

### Local Deployment

You can run the VM locally even in a non-TDX machine. This is really useful
for debugging and testing purposes.

We'll use [QEMU](https://www.qemu.org/) to run the VM. Ensure your machine
supports [KVM](https://www.linux-kvm.org/). Most modern processors, and
therefore most bare-metal machines, support KVM. However, if you're using a
VM, you might need to enable nested virtualization. This feature is supported
by some cloud providers but not all. You can use the `kvm-ok` command to
verify if your machine supports KVM.

First, in order to provide a TPM device to the VM, you need to start an
`swtpm` instance before running the VM. This will emulate a TPM device in the
host machine. In a separate terminal, run:

```bash
make start-swtpm
```

This will start a `swtpm` instance in the foreground. It will listen for
incoming connections, and once a connected process exits, it will exit as
well. It will also create a `tpmstatedir` directory in the project root with
the state of the TPM.

Then, run the VM. You can specify the size of the persistent disk to be
created (in case it doesn't exist) by setting the `DISK_SIZE` environment
variable. Below is an example of running the VM with a 10GB persistent disk:

```bash
DISK_SIZE=10G make run-local
```

This will, if needed, create a 10GB persistent QCOW2 disk image to be used
by the VM in `persistent.cow2` and run the VM using
[QEMU](https://www.qemu.org/). The image has disk encryption enabled by
default on the persistent disk, and you might notice the encryption process
when booting.

You can choose a different path for the persistent disk by setting the
`PERSISTENT_DISK` environment variable in `.env`.
