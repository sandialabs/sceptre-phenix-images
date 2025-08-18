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

## Startup Script Injection

As part of the build, a startup script is added to the automated postconfig
bootup script. This startup script loops over any scripts found in
`/config/scripts/custom/*` and executes it. Due to how the squashfs filesystem
works and is partitioned, to run a set of VyOS commands at boot, inject a
script to the location: `/boot/rw/config/scripts/custom/`. For example, the
phenix `vrouter` core user app creates the following injection:

```yaml
src: /phenix/experiments/foobar/vrouter/foo.boot
dst: /boot/vyos/rw/config/scripts/custom/vyos.script
```

> [!IMPORTANT]
> To use the `vyos.qc2` image successfully, you must set the
> `inject_partition` to `3`. Additionally, the memory needs to be at least 2G,
> and the `os_type` must be `vyos`. For example, in the phenix topology:
>
> ```yaml
> hardware:
>   drives:
>     - image: vyos.qc2
>       inject_partition: 3
>   memory: 2048
>   os_type: vyos
> ```
