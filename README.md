# phenix image
`phenix image` is a tool for quickly creating vm images with debian-based OSes. It is a wrapper of the [vmdb2](https://vmdb2.liw.fi/) tool which, in turn, is a wrapper of qemu-img, parted, kpartx, and debootstrap. It works in two steps:

1. Create an image configuration by specifying things like release code, packages, scripts to run after building, and filesystem overlays.
2. Build the image.

## How it works
In step 1, the tool compiles command line arguments, scripts, and filesystem overlay paths on disk into an `Image` vmdb configuration file in the phenix datastore. The scripts and overlays are specified on the command line by path. In step 2, the tool runs vmdb2 with the generated `Image` config which then creates the VM image. The examples below show how to build commonly-used images from configs saved in the repo and how to create those configs from command-line arguments, scripts, and overlays saved in the repo.

## Prerequisites
- Ubuntu 18.04+ (`lsb_release -rs`)
- Packages:
  - `python3 python3-cliapp python3-jinja2 python3-yaml cmdtest debootstrap parted kpartx qemu-kvm`
- The easiest way to install dependencies:
  - `apt install -y vmdb2 qemu-kvm && apt remove -y vmdb2`
  - This will install the required dependencies for vmdb2 (and therefore phenix image) and then uninstall the standard 'vmdb2' package, since phenix bundles a [custom version of 'vmdb2'](https://github.com/glattercj/vmdb2/releases/tag/v1.0)

# Examples

### bennu
- Official SCEPTRE image used for running bennu in experiments (includes brash shell)

    ```bash
    phenix image create -O /phenix/vmdb2/overlays/bennu,/phenix/vmdb2/overlays/brash -T /phenix/vmdb2/scripts/aptly,/phenix/vmdb2/scripts/bennu --format qcow2 --release focal -c bennu
    phenix image build bennu -o /phenix -c -x
    ```

### kali19
- Kali 2019 image built with XFCE, kali-linux-top10, PEAT, Bettercap, some custom caplets, and some commonly used tools

    ```bash
    phenix image create -O /phenix/vmdb2/overlays/kali19 -T /phenix/vmdb2/scripts/aptly,/phenix/vmdb2/scripts/kali19 --mirror http://http.kali.org/kali --debootstrap-append="--components=main,non-free,contrib" --variant mingui --release kali-rolling --size 20G --format qcow2 -c kali19
    phenix image build kali19 -o /phenix -c -x
    ```

### Ubuntu 
- Basic Ubunutu 
 
    ```bash
    phenix image create /phenix/vmdb2/scripts/aptly,/phenix/vmdb2/scripts/ubuntu --format qcow2 --release focal -c ubuntu
    phenix image build ubuntu -o /phenix -c -x
    ```

## Proxy Info
Note if building images behind a proxy, you may also need to edit and add the `proxy` script to your build.

## Image Update
If you change overlays and/or scripts on disk and rebuild an image with the same image config file, the changes will not be reflected in the newly built image. This is because the image is built from the config, not from the scripts/overlays on disk. Therefore, you have to update the config before you rebuild the image. To do so without having to re-run `phenix image create` and all of its command-line arguments just run `phenix image update name` where `name` is the name of your config. This command will update the config file with any changes made to the overlays and scripts on disk. Moreover, if they cannot be found on disk, no changes will be made to that overlay/script that cannot be found.
