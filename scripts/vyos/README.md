# VyOS Image Builder

The `build-vyos.sh` script can be used to easily build a `vyos.qc2` VM image
using the source code from the latest stable branch (currently `v1.5` -
circinus).

The script first uses a Docker image to build the qcow2 from source, then
optionally uses a separate Docker image to inject the miniccc binary and set
up the miniccc service to run at bootup.

The build_vyos() function was inspired by
[this forum post.](https://forum.vyos.io/t/build-for-qemu-or-vmware/15885/4)

## Usage

```bash
Usage: ./build-vyos.sh [-m <path to miniccc>]
```

## Requirements

- Docker

> [!IMPORTANT]
> This build script was tested on a Ubuntu 22.04 host with Docker version 28.3.0

## miniccc Agent

The build script has a command line option to install and configure the
`miniccc` agent inside the final qcow2 image. To use this feature, use the
`-m <path to miniccc binary>` option when running the script.

> [!WARNING]
> Using `phenix image inject-miniexe` will not work with the VyOS image as built
> by this script due to the differences in VyOS's image filesystem layout.
