# phenix image build script for a customized Kali Linux image for the HARMONIE-SPS LDRD

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y scapy python3-pip python3-all python3-dev python3-doc python3-venv python3-crcmod python3-wheel python3-setuptools pybind11-dev python3-pybind11 cmake gcc
pip3 install helics pyopendnp3 python-dateutil elasticsearch~=7.17

apt-get install -y firefox-esr kali-desktop-xfce kali-linux-default tcpdump nmap wireshark jq kali-grant-root dos2unix zip unzip tree nano arping

# Kali Linux uses ntpsec (a hardened fork of NTP) instead of ntp, and comes installed with it by default.
# This is problematic from a SCEPTRE perspective, since the ntp app just assumes everything uses NTP, and
# injects /etc/ntp.conf on all Linux systems. To work around this, make ntpsec's configuration a symlink
# to /etc/ntp.conf, so it uses the NTP configuration injected by SCEPTRE.
mv /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.bak
ln -s /etc/ntp.conf /etc/ntpsec/ntp.conf
systemctl enable ntpsec

dpkg-reconfigure kali-grant-root

echo "root:toor" | chpasswd
