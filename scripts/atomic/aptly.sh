set -x
export DEBIAN_FRONTEND=noninteractive
mv /etc/apt/sources.list /etc/apt/sources.list_backup

. /etc/os-release

cat <<EOF >> /etc/apt/sources.list
deb [arch=amd64 trusted=yes] http://archive.ubuntu.com/ubuntu/ ${VERSION_CODENAME} main restricted universe
deb [arch=amd64 trusted=yes] http://archive.ubuntu.com/ubuntu/ ${VERSION_CODENAME}-updates main restricted universe
deb [arch=amd64 trusted=yes] http://archive.ubuntu.com/ubuntu/ ${VERSION_CODENAME}-security main restricted universe
EOF

apt-get update
# apt-get install -y ca-certificates apt-transport-https
# apt-get clean

# mkdir -p /etc/apt/sources.list.d/
# cat <<EOF >> /etc/apt/sources.list.d/aptly.list
# deb [arch=amd64 trusted=yes] https://apt.sceptre.dev /
# EOF

# apt-get update
