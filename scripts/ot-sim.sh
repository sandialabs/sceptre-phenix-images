set -ex

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1

# Set timezone information
ln -fs /usr/share/zoneinfo/America/Denver /etc/localtime

apt-get install -y apt-utils

# Install Man Pages
apt-get install -y man-db manpages-dev

# Install the OT-Sim/PandaPower APT Requirements
apt-get install -y python3 python3-pip python2.7-dev python3-setuptools build-essential cmake libboost-dev libczmq-dev libxml2-dev libzmq5-dev pkg-config python3-dev python3-pip software-properties-common git

# Install Go lang 1.21.8
wget -O go.tgz https://golang.org/dl/go1.21.8.linux-amd64.tar.gz && tar -C /usr/local -xzf go.tgz && rm go.tgz && ln -s /usr/local/go/bin/* /usr/local/bin

# Make move to /opt and git clone the ot-sim project
cd /opt
git clone https://github.com/patsec/ot-sim.git

# Move into ot-sim
cd /opt/ot-sim

# Compile OT Sim
cmake -S . -B build && sudo cmake --build build -j$(nproc) --target install && sudo ldconfig && sudo make -C src/go install

# Compile OT Sim Python
sudo python3 -m pip install src/python

# Install Hivemind
wget -O hivemind.gz https://github.com/DarthSim/hivemind/releases/download/v1.1.0/hivemind-v1.1.0-linux-amd64.gz
gunzip hivemind.gz
sudo mv hivemind /usr/local/bin/hivemind
sudo chmod +x /usr/local/bin/hivemind

# Install MBPoll
wget -O- http://www.piduino.org/piduino-key.asc | sudo apt-key add -
sudo add-apt-repository 'deb http://apt.piduino.org xenial piduino'
sudo apt update
sudo apt install mbpoll -y

# Install OpenDSS
sudo python3 -m pip install opendssdirect.py~=0.8.4

# Install PandaPower Requirements
sudo python3 -m pip install pandapower==2.14.11
sudo python3 -m pip install pandas==2.0.3
sudo python3 -m pip install numba==0.58.1

# Change root password
echo "root:SiaSd3te" | chpasswd

# Add "sceptre" user set their login shell to bash
adduser sceptre --UID 1001 --gecos "" --shell /bin/bash --disabled-login || true
echo "sceptre:sceptre" | chpasswd

#Ensure /etc is owned by root
chown -R root:root /etc

## Clean APT install
apt-get -y clean || true
