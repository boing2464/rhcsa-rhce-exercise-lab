#!/bin/bash

sudo echo -e "
[BaseOS]
name="BaseOS Repo"
baseurl=https://downloads.redhat.com/redhat/rhel/rhel-8-beta/baseos/x86_64/
gpgcheck=0
enabled=1
" > /etc/yum.repos.d/baseos.repo

sudo echo -e "
[AppStream]
name="AppStream Repo"
baseurl=https://downloads.redhat.com/redhat/rhel/rhel-8-beta/appstream/x86_64/
gpgcheck=0
enabled=1
" > /etc/yum.repos.d/appstream.repo

sed -i 's/enabled=1/enabled=0/g' /etc/yum/pluginconf.d/subscription-manager.conf

mount /dev/sr1 /mnt
sh /mnt/VBoxLinuxAdditions.run
#mount /opt/VBoxGuestAdditions.iso /mnt
#sh /mnt/VBoxLinuxAdditions.run
#echo /opt/VBoxGuestAdditions.iso /mnt iso9660 loop 0 0 >> /etc/fstab
touch /root/vbox-additions.txt
