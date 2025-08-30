#!/bin/bash

set -ex

# remove systemd-resolved because it interferes with dnsmasq
apt remove --purge -y systemd-resolved

# disable system services, minirouter starts it's own processes
systemctl disable dnsmasq
systemctl disable bird