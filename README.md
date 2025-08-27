# Images

[![image-build](https://github.com/sandialabs/sceptre-phenix-images/actions/workflows/image-build.yml/badge.svg)](https://github.com/sandialabs/sceptre-phenix-images/actions/workflows/image-build.yml) [![release-cleanup](https://github.com/sandialabs/sceptre-phenix-images/actions/workflows/release-cleanup.yml/badge.svg)](https://github.com/sandialabs/sceptre-phenix-images/actions/workflows/release-cleanup.yml)

This repository contains configuration files, overlays, and scripts used by
`phenix image`, a tool used to quickly generate debian-based qcow2 VM images.
`phenix image` is a wrapper of the [vmdb2](https://vmdb2.liw.fi/) tool which,
in turn, is a wrapper of qemu-img, parted, kpartx, and debootstrap.

> [!TIP]
> Run `phenix image -h` to see additional help and options

## How It Works

Images configs are stored inside the phenix database in the `yaml` format. The
yaml configs are used as input to create a final `.vmdb` config which is passed
to the `vmdb2` tool inside the phenix container and used to build the image.

VM images can be built by `phenix image` using one of 3 methods:

### 1. From scratch
> [!IMPORTANT]
> This is the normal method for building images

First create the image config with optional overlays/scripts, then build it:

```bash
phenix image create -T ./scripts/foobar.sh -r focal -f qcow2 -c foo
phenix image build -o . -c -x foo
```

### 2. From a previously-created image config (e.g. `foo.yml`)
> [!NOTE]
> This can be useful when moving image configs to different locations.
> You can extract an image config from the phenix datastore using
> the command: `phenix cfg get image/foo -p > foo.yml`

First ingest the config into the phenix database, then build:

```bash
phenix cfg create ./configs/foo.yml
phenix image build -o . -c -x foo
```

### 3. From a previously-created vmdb config (e.g. `foo.vmdb`)
> [!NOTE]
> This can be useful if you need to edit the .vmdb config manually
> because the image .vmdb template doesn't have what you need. An
> example would be using a different disk partitioning setup for using
> UEFI boot.

Build the image directly:

```bash
phenix image build -o . -c -x ./configs/foo.vmdb
```

## Pre-Built Images
Pre-built qcow2 images are available as
[Packages](https://github.com/orgs/sandialabs/packages?repo_name=sceptre-phenix-images).
They are stored in OCI registry format (due to size constraints) and require
the [oras](https://oras.land/docs/installation) client to download. Once you
have the oras client installed you can download with a command like:

```bash
oras pull ghcr.io/sandialabs/sceptre-phenix-images/bennu.qc2:latest
```

> [!NOTE]
> This example will download the latest version of bennu.qc2 to your current
> working directory

> [!IMPORTANT]
> Images are built weekly and saved for 90 days. View the
> [Github workflow](./.github/workflows/image-build.yml)
> for the details on how images are built.

## Default packages

Inside the
[core phenix code](https://github.com/sandialabs/sceptre-phenix/blob/main/src/go/api/image/constants.go#L96),
some default packages are automatically added to the packages list for
installation via apt:

- Default packages:
  * curl
  * ethtool
  * ncat
  * net-tools
  * openssh-server
  * rsync
  * ssh
  * tcpdump
  * tmux
  * vim
  * wget

> [!TIP]
> You can disable the above "default packages" via the `--skip-default-pkgs`
> command line argument

Additionally, some packages are added based on the `--variant` and `--release`
arguments:

- For the `minbase` variant, if the release matches the following
  distributions, the corresponding packages are added:

    | **_Debian_**        | **_Kali_**          | **_Ubuntu_**          |
    | ------------------- | ------------------- | --------------------- |
    | dbus                | default-jdk         | linux-image-generic   |
    | gpg                 | linux-image-amd64   | linux-headers-generic |
    | initramfs-tools     | linux-headers-amd64 |                       |
    | linux-image-amd64   |                     |                       |
    | linux-headers-amd64 |                     |                       |
    | locales             |                     |                       |

- For the `mingui` variant, if the release matches the following
  distributions, the correpsonding packages are added:

    | **_Debian_**   | **_Kali_**        | **_Ubuntu_**    |
    | -------------- | ----------------- | --------------- |
    | wmctrl         | kali-desktop-xfce | wmctrl          |
    | xdotool        | wmctrl            | xdotool         |
    | xfce4          | xdotool           | xubuntu-desktop |
    | xfce4-terminal |                   |                 |

---

## Makefile
A Makefile is included that has recipes for example vanilla images and other
common images. Run `make` by itself to see a list of targets and
short decriptions. For each target, the Makefile first checks if the image
already exists in the phenix database. If the image already exists, the
recipe will not continue. To fix this, first delete the existing image by
running `phenix image delete <target>`, then retry the `make <target>` command.
In addition to creating and building the phenix image, the Makefile also runs
`phenix image inject-miniexe ...` to automatically inject the `miniccc` binary
into the image after it has finished building. One additional helper target
included is `make clean` - after confirmation, this recipe will remove the
following files in the same directory as the Makefile:
`*.log *.qc2 *.tar *.vmdb`. More details on the image recipes available in
the Makefile are shown below.

> [!TIP]
> If building images behind a proxy, you may also need to edit and add the
> `scripts/atomic/proxy.sh` script to your build.

> [!CAUTION]
> If you change overlays and/or scripts on disk and rebuild an image with the
> same image config file, the changes will not be reflected in the newly built
> image. This is because the image is built from the config, not from the
> scripts/overlays on disk. Therefore, you have to update the config before you
> rebuild the image. To do so without having to re-run `phenix image create` and
> all of its command-line arguments just run `phenix image update name` where
> `name` is the name of your config. This command will update the config file
> with any changes made to the overlays and scripts on disk. Moreover, if they
> cannot be found on disk, no changes will be made to that overlay/script that
> cannot be found.

## Vanilla Linux Images

| **_Target_** | **_OS / Release_**  | **_Includes_** | **_Notes_** | **_GUI?_** |
| ------------ | ------------------- | -------------- | ----------- | ---------- |
| bookworm | Debian / bookworm | | | :white_check_mark: |
| kali | Kali / kali-rolling | `kali-tools-top10` | | :white_check_mark: |
| jammy | Ubuntu / jammy | | | :white_check_mark: |
| noble | Ubuntu / noble | | | :white_check_mark: |

## Experiment Linux Images

| **_Target_** | **_OS / Release_** | **_Includes_** | **_Notes_** | **_GUI?_** |
| ------------ | ------------------ | -------------- | ----------- | ---------- |
| bennu | Ubuntu / jammy | Bennu, Brash | Official SCEPTRE image used for running bennu in experiments (includes brash shell) | :x: |
| docker-hello-world | Ubuntu / jammy | Docker | Shows how you can run a service (dockerd) inside the chroot image build environment | :x: |
| ntp | Ubuntu / jammy | [ntpd](https://linux.die.net/man/8/ntpd) | Network time protocol server | :x: |
| vyos | VyOS / 1.5 | [VyOS](https://docs.vyos.io/en/latest/) | Open-source enterprise-grade router platform | :x: |
