#!/bin/bash

set -ex

cat > /etc/apt/sources.list.d/updates.list <<EOF
deb http://us.archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends xubuntu-core epiphany-browser wireshark-gtk python3-pip python-is-python3 micro

# install python dependencies for soap demo tools
pip3 install python-snap7==1.3 dnp3-python==0.2.3b3

# Install filebeat and zeek for soap scorch demo
# if you are behind a proxy and get certificate errors, change `curl` to `curl --insecure`
curl -LO https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.17.21-amd64.deb
dpkg -i filebeat-7.17.21-amd64.deb

## uncomment the lines below if your are behind a proxy and get certificate errors with apt
# sudo tee /etc/apt/apt.conf.d/99-no-verify  <<EOF
# Acquire::https::Verify-Peer "false";
# Acquire::https::Verify-Host "false";
# EOF

echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' | tee /etc/apt/sources.list.d/security:zeek.list

# if you are behind a proxy and get certificate errors, change `curl` to `curl --insecure`
curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
apt update
DEBIAN_FRONTEND=noninteractive apt install zeek-6.0 -y

# install msfconsole for soap demo
set -e
# if you are behind a proxy and get certificate errors, change `curl` to `curl --insecure`
curl -L https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb | bash

apt clean