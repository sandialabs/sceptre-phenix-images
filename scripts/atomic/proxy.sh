set -x
export no_proxy=<host>
export http_proxy=<host>:port
export https_proxy=<host>:port
apt-get update
apt-get install -y ca-certificates curl git
curl -kSL <cert> -o /usr/local/share/ca-certificates/<cert>.crt
update-ca-certificates
