set -ex

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1

# TODO: delete aptly (internal) and aptly.sh (oss)? no longer needed?

# Set default timezone to UTC
ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
# ln -fs /usr/share/zoneinfo/America/Denver /etc/localtime

apt-get update

apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" apt-utils apt-transport-https

# man pages. They only add ~10-20MB to the image size.
apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" man-db manpages-dev

# NOTE: the phenix ntp app by default will configure ntp on clients by injecting /etc/ntp.conf
# However, ntp isn't installed by default anymore on ubuntu. Therefore, we install it here.
apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" libzmq5-dev collectd ftp pv python3 python3-pip python3-setuptools python3-twisted python3-wheel python3-ipython socat tcpdump tmux telnet vsftpd wget git nano vim jq ntp ca-certificates libusb-1.0-0 unzip libssl3 python3-dev cmake ninja-build libboost-dev

# Install build dependencies to aid development. If a smaller image is needed, comment out this line.
apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" gcc g++ build-essential make libunwind-dev libunwind8

PREFIX=${PREFIX:-/usr/local}
export ZMQ_PREFIX=${PREFIX}
export ZMQ_DRAFT_API=1

# NOTE: bennu and pybennu come from GitHub releases which are built by GitHub Actions (CI/CD pipeline)
# Install helics and libzmq for pybennu
wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/helics_3.6.1-1_amd64.deb -O /tmp/helics.deb
apt-get install -y /tmp/helics.deb
rm -f /tmp/helics.deb

wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/libzmq_4.3.4-1_amd64.deb -O /tmp/libzmq.deb
apt-get install -y /tmp/libzmq.deb
rm -f /tmp/libzmq.deb

# bennu (C++)
wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/bennu.deb -O /tmp/bennu.deb
apt-get install -y /tmp/bennu.deb
rm -f /tmp/bennu.deb

# pybennu (Python)
wget https://github.com/sandialabs/sceptre-bennu/releases/latest/download/pybennu-6.0.0-py3-none-any.whl -O /tmp/pybennu-6.0.0-py3-none-any.whl
pip install /tmp/pybennu-6.0.0-py3-none-any.whl
rm -f /tmp/pybennu-6.0.0-py3-none-any.whl

# Cleanup
apt-get autoremove -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

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

# Change root's password
echo "root:SiaSd3te" | chpasswd

# Add "sceptre" user, set their login shell to Brash
adduser sceptre --UID 1001 --gecos "" --shell /usr/bin/bennu-brash --disabled-login || true
echo "sceptre:sceptre" | chpasswd

# The ntp phenix app assumes ntpd, can't differentate when to use timesyncd
# Therefore, for compatibility use the "old" way of ntpd instead.
# https://serverfault.com/a/1016367
systemctl disable systemd-timesyncd
systemctl enable ntp

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

apt-get -y clean || true
