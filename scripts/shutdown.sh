#!/bin/bash
set -eo pipefail

## Guidance from:
## https://systemd.io/BUILDING_IMAGES/
## https://lonesysadmin.net/2013/03/26/preparing-linux-template-vms/

# Remove /etc/machine-id
cloud-init clean --logs --machine-id --seed --configs all

# Remove the /var/lib/systemd/random-seed file
rm /var/lib/systemd/random-seed

# Remove /etc/hostname
rm /etc/hostname

# Remove SSH host keys
rm -f /etc/ssh/*key*

# Prevent writing shell history
set +o history

# Remove user accounts
if getent passwd "$(logname)"; then
    userdel --force --remove "$(logname)"
fi

if getent passwd "$(cloud-init query system_info.default_user.name)"; then
    userdel --force --remove "$(cloud-init query system_info.default_user.name)"
fi

# Remove logs
rm -rf /var/log/apt/*
rm -rf /var/log/journal/*
rm -f /var/log/cloud-init-output.log
rm -f /var/log/cloud-init.log
truncate --size 0 /var/log/alternatives.log
truncate --size 0 /var/log/apport.log
truncate --size 0 /var/log/bootstrap.log
truncate --size 0 /var/log/btmp
truncate --size 0 /var/log/dpkg.log
truncate --size 0 /var/log/faillog
truncate --size 0 /var/log/lastlog
truncate --size 0 /var/log/unattended-upgrades/unattended-upgrades-dpkg.log
truncate --size 0 /var/log/unattended-upgrades/unattended-upgrades-shutdown.log
truncate --size 0 /var/log/unattended-upgrades/unattended-upgrades.log
truncate --size 0 /var/log/wtmp

# Clean /tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Zero out free space
cat /dev/zero > ~root/zeros.file || sync && rm ~root/zeros.file

# Shut down
poweroff
