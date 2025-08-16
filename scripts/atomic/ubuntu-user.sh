##############################################################################
# INSTALLS:
#   [ Ubuntu user ]
#     - Adds a non-root user account called "ubuntu" with sudo permissions
##############################################################################
# ------------------------------------------------ Ubuntu User ---------------------------------------------------
# don't fail if user already exists
useradd --create-home --shell /bin/bash ubuntu || true
usermod -aG sudo ubuntu
echo 'ubuntu   ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/ubuntu
echo 'ubuntu:ubuntu' | chpasswd
