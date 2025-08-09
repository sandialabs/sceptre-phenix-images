##############################################################################
# INSTALLS:
#   [ Docker ]
#     - Set of platform as a service products that use OS-level virtualization
#       to deliver software in packages called containers
#       * https://www.docker.com
##############################################################################
# --------------------------------------------------- Docker -----------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl &>/dev/null; then
    apt-get update && apt-get install -y curl
fi
curl -fsSL get.docker.com | bash
sed -i -e 's/ulimit -Hn/ulimit -n/g' /etc/init.d/docker # Fix from https://forums.docker.com/t/etc-init-d-docker-62-ulimit-error-setting-limit-invalid-argument-problem/139424
DOCKER_RAMDISK=true /etc/init.d/docker start
# Wait for docker socket to be available
while [ ! -S /var/run/docker.sock ]; do sleep 1; done
service docker status
while ! ps aux | grep -q [d]ockerd; do sleep 1; done
# You can now run docker commands...
