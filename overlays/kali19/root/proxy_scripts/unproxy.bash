#!/usr/bin/env bash

function os_type() {
case $(uname) in
  Linux )
     command -v cmd.exe > /dev/null && { WSL=1; echo "Windows Subsystem for Linux detected"; }
     command -v apt-get > /dev/null && { DEBIAN=1; echo "apt-get detected, probably Debian"; return; }
     command -v dnf > /dev/null && { FEDORA=1; echo "dnf detected, definitely Fedora"; return; }
     command -v yum > /dev/null && { RHEL=1; echo "yum detected, probably RHEL or CentOS"; return; }
     command -v zypper > /dev/null && { SUSE=1; echo "zypper detected, probably OpenSUSE"; return; }
     command -v pkg > /dev/null && { FREEBSD=1; echo "pkg detected, probably FreeBSD"; return; }
     ;;
  Darwin )
     DARWIN=1
     ;;
  * )
     ;;
esac
}
os_type


# TODO: get these variables to work with the EOL commands
proxy="http://proxy.sandia.gov:80/"
noproxy="127.0.0.1,localhost,.sandia.gov,gitlab.sandia.gov,::1,10.,172.16.,192.16.,*.local,169.254/16,*.srn.sandia.gov"


echo "Unsetting system environment variables..."
sed -i 's/.*proxy.*//' /etc/environment
sed -i 's/.*PROXY.*//' /etc/environment
sed -i -r '/^\s*$/d' /etc/environment

# Configure for just your user
echo "Configuring wget for user $(whoami)..."
sed -i 's/.*proxy.*//' ~/.wgetrc
sed -i -r '/^\s*$/d' ~/.wgetrc

echo "Configuring curl for user $(whoami)..."
sed -i 's/.*proxy.*//' ~/.curlrc
sed -i -r '/^\s*$/d' ~/.curlrc


echo "Configuring git..."
git config --global --unset core.gitproxy
git config --global --unset http.proxy
git config --global --unset http.sslVerify
 # This might be necessary in some cases
git config --global --unset http.emptyAuth


echo "Configuring pip..."
sed -i 's/.*proxy.*//' ~/.config/pip/pip.conf
sed -i -r '/^\s*$/d' ~/.config/pip/pip.conf


if [ $DEBIAN ] ; then
echo "Configuring apt..."
sed -i 's/.*proxy.*//' /etc/apt/apt.conf
sed -i -r '/^\s*$/d' /etc/apt/apt.conf
#sudo apt-get update -y -qq
#echo "Downloading certificate..."
#wget --user "$(whoami)" --ask-password -O sandia.crt https://prod.sandia.gov/firefox/bc.pem --no-check-certificate
#echo "Installing certificate..."
#sudo apt-get install -y -qq ca-certificates
#sudo cp sandia.crt /usr/share/ca-certificates/mozilla/sandia.crt
#sudo bash -c "echo 'mozilla/sandia.crt' >> /etc/ca-certificates.conf"
#sudo update-ca-certificates

elif [ $RHEL ] ; then
echo "Configuring yum..."
sudo bash -c "cat >> /etc/yum.conf" << 'EOL'
proxy=http://proxy.sandia.gov:80
EOL
echo "Downloading certificate..."
wget --user "$(whoami)" --ask-password -O sandia.crt https://prod.sandia.gov/firefox/bc.pem
echo "Installing certificate..."
sudo yum install ca-certificates
sudo update-ca-trust enable
sudo cp sandia.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

elif [ $DARWIN ] ; then
bash -c "cat >> ~/.bash_profile" << 'EOL'
export http_proxy=http://proxy.sandia.gov:80
export HTTP_PROXY=http://proxy.sandia.gov:80
export https_proxy=http://proxy.sandia.gov:80
export all_proxy=http://proxy.sandia.gov:80
export no_proxy=*.local,169.254/16,*.sandia.gov,*.srn.sandia.gov,localhost,127.0.0.1,::1
EOL
echo "gem: --http-proxy http://proxy.sandia.gov:80" >> ~/.gemrc

fi
