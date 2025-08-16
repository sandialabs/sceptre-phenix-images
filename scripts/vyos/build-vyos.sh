#!/usr/bin/env bash

# This script will build a VyOS qcow2 image inside a docker container. The
# VyOS version is set to 'current' and matches v1.5. Optionally, the full
# path to a miniccc binary can be passed as another command line argument
# and it will be injected into the final image, including a startup script
# that runs on bootup. The final qcow2 image will be at: ./vyos.qc2
#
#   Usage: ./build-vyos.sh [-m <path to miniccc>]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CWD=$(pwd)

set -o pipefail # If using pipe in commands, fail for any non-exit 0
set -o errexit # Exit immediately if a command exits with a non-zero status

function docker_build() {
    docker build -t inject-miniccc -f - . <<-'DONE'
# use AWS public repo to avoid Docker Hub limits
FROM public.ecr.aws/lts/ubuntu:24.04
RUN apt update && apt install -y qemu-utils squashfs-tools
COPY <<END inject.sh
#!/usr/bin/env bash

set -o pipefail # If using pipe in commands, fail for any non-exit 0
set -o nounset # Error on unset variables
set -o errexit # Exit immediately if a command exits with a non-zero status

FILE=\$(ls vyos-build/build/*.qcow2)
VERSION=\$(basename \$FILE | cut -d- -f2)
DATESTAMP=\$(basename \$FILE | cut -d- -f4)

# mount squashfs rootfs as rw
MOUNT=/tmp/mount
BOOT_PATH=\$MOUNT/boot
VERSION_DIR=\$VERSION-rolling-\$DATESTAMP
SQUASH_PATH=\$BOOT_PATH/vyos
SQUASHFS=\$VERSION-rolling-\$DATESTAMP.squashfs
ROOTFS=\$SQUASH_PATH/squashfs-root
mkdir -p \$MOUNT
qemu-nbd -c /dev/nbd0 \$FILE
sleep 3 # settle
mount /dev/nbd0p3 \$MOUNT
cd \$BOOT_PATH/\$VERSION_DIR
unsquashfs \$SQUASHFS
cd \$BOOT_PATH
mv \$VERSION_DIR vyos # rename to work with phenix config injections
sed -i -e "s/\$VERSION_DIR/vyos/g" grub/grub.cfg.d/vyos-versions/\$VERSION_DIR.cfg # fixup cfg to match ^
cd \$SQUASH_PATH
rm \$SQUASHFS # old fs

# branding
tee \$ROOTFS/usr/share/vyos/templates/login/default_motd.j2 <<EOF
██████╗ ██╗  ██╗███████╗███╗  ██╗██╗██╗  ██╗
██╔══██╗██║  ██║██╔════╝████╗ ██║██║╚██╗██╔╝
██████╔╝███████║█████╗  ██╔██╗██║██║ ╚███╔╝
██╔═══╝ ██╔══██║██╔══╝  ██║╚████║██║ ██╔██╗
██║     ██║  ██║███████╗██║ ╚███║██║██╔╝╚██╗
╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚══╝╚═╝╚═╝  ╚═╝
____________________________________________
Welcome to VyOS!

   ┌── ┐
   . VyOS {{ version_data.version }}
   └ ──┘  {{ version_data.release_train }}
____________________________________________
EOF

# copy miniccc binary
cp /root/miniccc \$ROOTFS/usr/local/bin/miniccc
chmod +x \$ROOTFS/usr/local/bin/miniccc

# create miniccc service
tee \$ROOTFS/etc/systemd/system/miniccc.service <<EOF
[Unit]
Description=miniccc Agent
[Service]
ExecStart=/usr/local/bin/miniccc -serial /dev/virtio-ports/cc -level debug
[Install]
WantedBy=multi-user.target
EOF

# start miniccc service at boot
mkdir -p \$ROOTFS/etc/systemd/system/multi-user.target.wants
ln -s /etc/systemd/system/miniccc.service \$ROOTFS/etc/systemd/system/multi-user.target.wants/miniccc.service

# add main startup script
tee \$ROOTFS/opt/vyatta/etc/config/scripts/vyos-postconfig-bootup.script <<-'EOF'
#!/bin/sh
for file in /config/scripts/custom/*; do
  echo \$file
  chmod +x \$file
  sg vyattacfg -c \$file
done
EOF

# add initial custom startup script
mkdir -p \$ROOTFS/opt/vyatta/etc/config/scripts/custom
tee \$ROOTFS/opt/vyatta/etc/config/scripts/custom/vyos.script <<-'EOF'
#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
configure
set interface ethernet eth0 address dhcp
set service ssh
commit
save
exit
EOF

# cleanup
#   - Squashfs opts ref: https://github.com/vyos/vyos-build/blob/c5d52ac7b9a2cf4c85a638ef65fbf073e366f9c1/data/defaults.toml#L21
mksquashfs \$ROOTFS \$SQUASHFS -comp xz -Xbcj x86 -b 256k -always-use-fragments -no-recovery
rm -rf \$ROOTFS
cd /root
umount /tmp/mount
qemu-nbd -d /dev/nbd0
END
RUN chmod +x inject.sh
ENTRYPOINT ["/inject.sh"]
DONE
}

function inject_miniccc() {
    cd $CWD
    if [ ! -f "$1" ]; then
        echo ""
        echo "!!!! miniccc binary not found - not injecting !!!!"
        echo ""
        exit 1
    fi
    docker_build
    cp $1 $CWD/miniccc
    docker run --rm \
        -v /dev:/dev \
        -v /lib/modules:/lib/modules \
        -v $CWD:/root \
        -w /root --privileged --cap-add=ALL \
        inject-miniccc /root/miniccc
    rm $CWD/miniccc
    docker rmi inject-miniccc
}

# ref: https://forum.vyos.io/t/build-for-qemu-or-vmware/15885/4
function build_vyos() {
    usage() { echo -e "\nusage: $0 [-h] [-m <path to miniccc>] [-p <comma-separated list of packages>]"; exit 1; }
    while getopts "m:p:h" opt; do
        case "$opt" in
            m) MINICCC_PATH=$OPTARG ;;
            p) PACKAGES=$OPTARG ;;
            h) usage ;;
            \?) echo "invalid option: -$OPTARG" >&2; usage ;;
        esac
    done

    # must be sudo (needed for cleanup)
    if [[ $EUID -ne 0 ]]; then
        echo "this script must be run as root"
        exit 1
    fi

    # must have docker
    if ! command -v docker &> /dev/null; then
        echo "docker must be installed (and in your PATH) to use this build script - exiting"
        exit 1
    fi

    # must be clean directory
    if [ -d vyos-build ]; then
       echo "vyos-build directory already exists - exiting"
       exit 1
    fi

    # format packages
    if [ -n "$PACKAGES" ]; then
        # set IFS to comma to split the string into an array
        IFS=',' read -r -a elements <<< "$PACKAGES"

        # initialize an empty array to store the formatted elements
        formatted=()

        # loop through each element, add double quotes, and append a comma and space
        for element in "${elements[@]}"; do
            # trim leading/trailing whitespace from the element
            trimmed=$(echo "$element" | xargs)
            formatted+=("\"$trimmed\", ") # Add a trailing comma and space
        done

        # join the formatted elements
        PACKAGES=$(echo -e "${formatted[@]}")
    fi

    # fetch build files
    cd $CWD
    git clone -b current --single-branch https://github.com/vyos/vyos-build
    cd vyos-build
    git pull

    # fix losetup not populating the partitions on the image
    sed -i 's/losetup --show/losetup --partscan --show/' scripts/image-build/raw_image.py

    # add qemu build flavor
    cat << EOF > data/build-flavors/qemu.toml
build_type = "release"
image_format = "qcow2"
packages = [$PACKAGES"qemu-guest-agent", "vim"]
EOF

    # build vyos
    docker pull ghcr.io/sandialabs/sceptre-phenix-images/vyos-build:current
    docker run --rm \
        -v /dev:/dev \
        -v $CWD/vyos-build:/root \
        -w /root --privileged \
        -e GOSU_UID=$(id -u) -e GOSU_GID=$(id -g) \
        vyos/vyos-build:current \
        bash -c "sudo make -j$(nproc) qemu"

    if [ -f "$MINICCC_PATH" ]; then
        inject_miniccc $MINICCC_PATH
    else
        echo ""
        echo "---- miniccc binary not found - not injecting ----"
        echo ""
    fi
    cleanup
}

function cleanup() {
    FILE=$(ls $CWD/vyos-build/build/*.qcow2)
    FINAL=vyos.qc2

    if [ -f $FILE ]; then
        mv $FILE $FINAL
        echo ""
        echo "---------------"
        echo "Final image: $FINAL"
        echo "---- DONE! ----"
        echo ""
        rm -rf vyos-build
        exit 0
    else
        echo ""
        echo "!!!! final image not found - expected it at 'vyos-build/build/*.qcow2' !!!!"
        echo ""
        exit 1
    fi
    cd $SCRIPT_DIR
}

build_vyos $@
