#!/bin/sh

set -ex

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1

export UBUNTU_MIRROR="${UBUNTU_MIRROR:-"http://archive.ubuntu.com/ubuntu/"}"
mv /etc/apt/sources.list /etc/apt/sources.list_backup
. /etc/os-release
cat <<EOF >> /etc/apt/sources.list
deb [arch=amd64 trusted=yes] ${UBUNTU_MIRROR} ${VERSION_CODENAME} main restricted universe multiverse
deb [arch=amd64 trusted=yes] ${UBUNTU_MIRROR} ${VERSION_CODENAME}-updates main restricted universe multiverse
deb [arch=amd64 trusted=yes] ${UBUNTU_MIRROR} ${VERSION_CODENAME}-security main restricted universe multiverse
EOF

# Default directory for bennu source code to be located.
export BENNU_DIR="${BENNU_DIR:-"/root/Desktop/bennu"}"

# Set default timezone to UTC
ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
# ln -fs /usr/share/zoneinfo/America/Denver /etc/localtime

# ------------------------------------------------------------------------------
# Extra apt repositories.
# These must be configured before the package list below is installed.
# ------------------------------------------------------------------------------

# Microsoft repo, for vscode.
# NOTE: the key is stored ASCII-armored so that 'gpg' isn't needed at this point.
mkdir -p /usr/share/keyrings/
wget -qO /usr/share/keyrings/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc
mkdir -p /etc/apt/sources.list.d/
cat << EOF > /etc/apt/sources.list.d/vscode.sources
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.asc
EOF

apt-get update

# Common flags for every apt-get install in this script
APT_INSTALL='apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold'

# ------------------------------------------------------------------------------
# Build up the package list, then install everything in a single apt-get call.
# ------------------------------------------------------------------------------

# apt itself
PACKAGES="apt-utils apt-transport-https ca-certificates gpg"

# man pages. They only add ~10-20MB to the image size.
PACKAGES="$PACKAGES man-db manpages-dev"

# bennu build dependencies
PACKAGES="$PACKAGES build-essential cmake g++ gcc libasio-dev libboost-date-time-dev libboost-filesystem-dev libboost-program-options-dev libboost-python-dev libboost-system-dev libboost-thread-dev libfreetype6-dev libssl-dev libzmq5-dev"

# pybennu build dependencies
PACKAGES="$PACKAGES git wget python3 python3-dev python3-pip liblapack-dev libboost-dev ninja-build pipx checkinstall zstd"

# gobennu build dependencies
# NOTE: gobennu isn't built by default (see below), so golang isn't installed.
# PACKAGES="$PACKAGES golang-go"

# network debug tools
PACKAGES="$PACKAGES wireshark nmap ncat"

# vscode, for development
PACKAGES="$PACKAGES code"

# additional tools
# NOTE: the phenix ntp app by default will configure ntp on clients by injecting /etc/ntp.conf
# However, ntp isn't installed by default anymore on ubuntu. Therefore, we install it here.
PACKAGES="$PACKAGES collectd ftp pv python3-setuptools python3-twisted python3-wheel python3-ipython socat tcpdump tmux telnet vsftpd nano vim jq ntp libusb-1.0-0 unzip libssl3 xrdp xorgxrdp remmina remmina-plugin-rdp remmina-plugin-secret epiphany-browser"

$APT_INSTALL $PACKAGES

# Create initial vscode workspace
mkdir -p /root/Desktop/
cat >> /root/Desktop/bennu.code-workspace << EOF
{
  "folders": [
    {
	"path" : "$BENNU_DIR"
    }
  ],
  "settings": {}
}
EOF
# Install vscode extensions
# Settings for vscode proxy, if necessary
update-ca-certificates
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
# Install C/C++ Extension
code --no-sandbox --user-data-dir="/root/.vscode" --install-extension ms-vscode.cpptools
# Install Makefile Tools
code --no-sandbox --user-data-dir="/root/.vscode" --install-extension ms-vscode.makefile-tools
# Install Python Extension
code --no-sandbox --user-data-dir="/root/.vscode" --install-extension ms-python.python
# Install Python Debugger Extension
code --no-sandbox --user-data-dir="/root/.vscode" --install-extension ms-python.debugpy
# Add vscode alias
echo "alias vscode='code --no-sandbox --user-data-dir=/root/.vscode'" >> /root/.bash_aliases


# Setup desktop shortcuts
# vscode Desktop shortcut
cat << EOF > /root/Desktop/vscode.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Terminal=False
Exec=code --no-sandbox --user-data-dir="/root/.vscode" /root/Desktop/bennu.code-workspace --disable-workspace-trust
Icon=/usr/share/code/resources/app/resources/linux/code.png
EOF
# Wireshark Desktop shortcut
cp /usr/share/applications/org.wireshark.Wireshark.desktop /root/Desktop/.
# Remmina Desktop shortcut
cp /usr/share/applications/org.remmina.Remmina.desktop /root/Desktop/.
# GNOME Web Desktop shortcut
cp /usr/share/applications/org.gnome.Epiphany.desktop /root/Desktop/.
# Set desktop shortcuts to executable
chmod +x /root/Desktop/*.desktop

# Add the desktop shortcut for /README.md
ln -s /README.md /root/Desktop/README.md

PREFIX=${PREFIX:-/usr/local}
export ZMQ_PREFIX=${PREFIX}
export ZMQ_DRAFT_API=1

# Download bennu GitHub repo to compile from scratch.
# NOTE: Change this to utilize a different version/branch of bennu for initial setup.
git clone https://github.com/sandialabs/sceptre-bennu.git $BENNU_DIR

# Install helics and libzmq for pybennu
cd $BENNU_DIR/src/pybennu/
# OPTIONAL: Compile helics from source
# make helics-install
wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/helics_3.6.1-1_amd64.deb -O /tmp/helics.deb
apt-get install -y /tmp/helics.deb
rm -f /tmp/helics.deb

# OPTIONAL: Compile libzmq from source
# make libzmq-install
wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/libzmq_4.3.4-1_amd64.deb -O /tmp/libzmq.deb
apt-get install -y /tmp/libzmq.deb
rm -f /tmp/libzmq.deb

# Build and install bennu
cd $BENNU_DIR
mkdir build
cd build
cmake ../ -DCMAKE_INSTALL_PREFIX=/usr
make -j"$(nproc)"
make install

# Install pybennu
pip install uv==0.12.7 packaging==25.0 'uv-build>=0.9.7'
cd $BENNU_DIR/src/pybennu/
pip install -U pip
# OPTIONAL: Install pyZMQ & pyHelics with an offline clone
#PYZMQ_PATH=$BENNU_DIR/src/pybennu/build/pyzmq/
#git clone https://github.com/zeromq/pyzmq.git@v27.2.0 $PYZMQ_PATH
#sed -i -e "s_git+https://github.com/zeromq/pyzmq.git@v27.2.0_file://$PYZMQ_PATH_" pyproject.toml
#PYHELICS_PATH=$BENNU_DIR/src/pybennu/build/pyhelics/
#git clone https://github.com/GMLC-TDC/pyhelics.git@v3.6.1 $PYHELICS_PATH
#sed -i -e "s_git+https://github.com/GMLC-TDC/pyhelics.git@v3.6.1_file://$PYHELICS_PATH_" pyproject.toml
pip install -e .

# Build and install gobennu
#cd $BENNU_DIR/src/gobennu
#go mod download
#make

# install labjack libraries for pybennu-siren
# NOTE: pushd/popd cannot be used here due to the fact this isn't bash
PREV="$(pwd)"
mkdir -p /tmp/labjack
cd /tmp/labjack
wget -q https://files.labjack.com/installers/LJM/Linux/x64/beta/LabJack-LJM_2025-02-12.zip -O labjack.zip
unzip labjack.zip
./labjack_ljm_installer.run --noprogress --nox11 --accept --nodiskspace || true
cd "$PREV"
rm -rf /tmp/labjack

# Set sticky bit on brash binary
brash=$(which bennu-brash)
if ! [ -z "$brash" ]
then
    chmod u+s $brash
fi

# Configure FTP service and allow "sceptre" user
sed -i 's/pam_service_name=vsftpd/pam_service_name=ftp/g' /etc/vsftpd.conf
echo "sceptre" >> /etc/vsftpd.allowed_users
cat <<EOF >> /etc/vsftpd.conf
write_enable=YES
file_open_mode=0777
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
userlist_deny=NO
userlist_enable=YES
userlist_file=/etc/vsftpd.allowed_users
EOF

# Add "sceptre" user, set their login shell to Brash
adduser sceptre --UID 1001 --gecos "" --shell /usr/bin/bennu-brash --disabled-login || true
echo "sceptre:sceptre" | chpasswd

# The ntp phenix app assumes ntpd, can't differentate when to use timesyncd
# Therefore, for compatibility use the "old" way of ntpd instead.
# https://serverfault.com/a/1016367
systemctl disable systemd-timesyncd
systemctl enable ntp

# Make ssh listen on all addresses (including localhost)
# so that it works with phenix tunnler out of the box
# also make sure ssh is enabled
echo "ListenAddress 0.0.0.0" | tee -a /etc/ssh/sshd_config
systemctl enable ssh

# Aliases for common pybennu commands
cat << EOF >> "/root/.bash_aliases"
alias prun='pybennu-power-solver start'
alias pstart='pybennu-power-solver start -d'
alias pstop='pybennu-power-solver stop'
alias prestart='pybennu-power-solver restart -d'
alias plogs='tail -f /var/log/bennu-pybennu.*'
alias preset='pybennu-power-solver stop;rm -f /var/log/bennu-pybennu.*'
alias pconf='vim /etc/sceptre/config.ini'
alias pyconf='vim /etc/sceptre/*.yaml'
EOF

# Ensure /etc is owned by root
# This fixes funkyness if overlay files on the host running the build aren't owned by root
chown -R root:root /etc

# Create new SSL cert & fix permissions for xrdp
rm /etc/xrdp/key.pem /etc/xrdp/cert.pem
openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 3650 -subj "/CN=bennu-dev"
chown xrdp:xrdp /etc/xrdp/key.pem /etc/xrdp/cert.pem /etc/xrdp/rsakeys.ini

# Set xrdp desktop session
echo xfce4-session > /root/.xsession
chmod +x /root/.xsession

apt-get -y clean || true
