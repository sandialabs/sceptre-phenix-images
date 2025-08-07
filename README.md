# phenix image
`phenix image` is a tool for quickly creating vm images with debian-based OSes. It is a wrapper of the [vmdb2](https://vmdb2.liw.fi/) tool which, in turn, is a wrapper of qemu-img, parted, kpartx, and debootstrap. It works in two steps:

1. Create an image configuration by specifying things like release code, packages, scripts to run after building, and filesystem overlays.
2. Build the image.

## Pre-built Images
Pre-built qcow2 images are available as [Packages](https://github.com/orgs/sandialabs/packages?repo_name=sceptre-phenix-images). They are stored in OCI registry format (due to size constraints) and require the [oras](https://oras.land/docs/installation) client to download. Once you have the oras client installed you can download with a command like:

```
oras pull ghcr.io/sandialabs/sceptre-phenix-images/bennu.qc2:latest
```
Images are built weekly and saved for 90 days. View the [Github workflow](./.github/workflows/image-build.yml) for the details on how images are built.

## How it works
In step 1, the tool compiles command line arguments, scripts, and filesystem overlay paths on disk into an `Image` vmdb configuration file in the phenix datastore. The scripts and overlays are specified on the command line by path.

In step 2, the tool runs vmdb2 with the generated `Image` config which then creates the VM image. The image commands below show how to build commonly-used images from configs saved in the repo and how to create those configs from command-line arguments, scripts, and overlays saved in the repo.

## Images

### Proxy Info
Note if building images behind a proxy, you may also need to edit and add the `proxy` script to your build.

### bennu
Official SCEPTRE image used for running bennu in experiments (includes brash shell).

The max size of the VM disk in the example below is set to 10 gigabytes, but can be customized as needed. Running the built command will result in `/phenix/bennu.qc2`.

```bash
phenix image create -O /phenix/vmdb2/overlays/bennu,/phenix/vmdb2/overlays/brash -T /phenix/vmdb2/scripts/aptly,/phenix/vmdb2/scripts/bennu --format qcow2 --release jammy -c bennu --size 10G
phenix image build bennu -o /phenix -c -x
```

### Ubuntu 
Basic Ubuntu image with a few packages added. The Ubuntu version built can be changed via `--release`, e.g. `--release focal` will build Ubuntu 20.04 LTS (Focal Fossa). 

The max size of the VM disk in the example below is set to 10 gigabytes, but can be customized as needed. Running the built command will result in `/phenix/ubuntu.qc2`.
 
```bash
phenix image create -T /phenix/vmdb2/scripts/ubuntu,/phenix/vmdb2/scripts/ubuntu-user --format qcow2 --release noble -c ubuntu --size 10G
phenix image build ubuntu -o /phenix -c -x
```

## Image Update
If you change overlays and/or scripts on disk and rebuild an image with the same image config file, the changes will not be reflected in the newly built image. This is because the image is built from the config, not from the scripts/overlays on disk. Therefore, you have to update the config before you rebuild the image. To do so without having to re-run `phenix image create` and all of its command-line arguments just run `phenix image update name` where `name` is the name of your config. This command will update the config file with any changes made to the overlays and scripts on disk. Moreover, if they cannot be found on disk, no changes will be made to that overlay/script that cannot be found.
