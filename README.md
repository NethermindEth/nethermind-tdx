# Nethermind in TDX

This repository holds an experiment in running the Nethermind execution client
through a TDX TEE.

The project is currently based on the recent Flashbots experiments with TDX,
namely:
* [T(EE)-Stack demo: running a validator in TDX](https://collective.flashbots.net/t/t-ee-stack-demo-running-a-validator-in-tdx/3551/5)
* [Building Secure Ethereum Blocks on Minimal Intel TDX Confidential VMs](https://collective.flashbots.net/t/building-secure-ethereum-blocks-on-minimal-intel-tdx-confidential-vms/3795)

The full process here is comprised of the generation of a minimal
TDX-compatible VM that includes the Nethermind client and only a number of
essential packages and processes.

This is done through Yocto, an open source project that helps developers
create specific custom Linux-based systems. Through it, multiple layers, from
system utilities to applications, are put on top of each other to describe
the system's configuration and build process. This build is reproducible,
which means we can use the measurement of the resulting image for TDX
attestations - and any change in the build process should lead to different
measurements.

Currently, we're using the Flashbots Yocto setup as a base and doing minimal
patching to include our layers and recipes, and exclude unnecessary ones.

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
in `artifacts/`.

#### Local Build

Preferably, use a VM for the build, as this will install packages that may
not be desirable later on.

Then, set up your Yocto environment:

```bash
make setup-local
```

This will install some Yocto dependencies.

Then, build the image:

```bash
# you can use `make setup-git` to set up a mock git user for cloning
make azure-image
```

#### Docker Build

If you don't want to install Yocto on your machine, you can use the provided
Dockerfile to build the image. This is essentially the same as the local
build, but it runs inside a Docker container.

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

You can run the VM locally, in a non-TDX machine. This is really useful for
debugging and testing purposes.

In order to run the VM, you need to start an `swtpm` instance first. This is
the TPM that will be used in the VM. In a separate terminal, run:

```bash
make start-swtpm
```

This will start a `swtpm` instance in the foreground. It will listen for
incoming connections, and once a connected process exits, it will exit as
well. It will also create a `tpmstatedir` directory in the project root with
the state of the TPM.

Then, run the VM:

```bash
make run-local
```

This will run the VM using [QEMU](https://www.qemu.org/).
