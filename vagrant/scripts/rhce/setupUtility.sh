#!/bin/bash

function del_DNS {
  sudo sed -i "/192.168.13.2/d" /etc/resolv.conf
  sudo sed -i "/192.168.14.110/d" /etc/resolv.conf
  sudo sed -i '/10.0.2.3/d' /etc/resolv.conf
}

function setup_Ansible_User {
  if [ `grep -e "^ansible:" /etc/passwd | wc -l` -eq 0 ]; then
    sudo useradd ansible
    echo password | sudo passwd --stdin ansible
    sudo echo "ansible ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansible
    sudo su - ansible -c "echo|ssh-keygen -t rsa -b 4096" 
  fi
}

function setup_IF_DNS {
  if [ `ip a l | grep ens33|wc -l` -gt 0 ]; then
      ipaddress=`nmcli c s 'System ens33'|grep ipv4.addresses|awk '{print $2}'|cut -d'/' -f 1`
      sudo nmcli c m 'System ens33' ipv4.dns 192.168.14.100 ipv4.dns-search example.com
      sudo nmcli c m ens32 ipv4.dns 192.168.14.100 ipv4.dns-search example.com
      sudo nmcli networking off && sudo nmcli networking on
  else
      ipaddress=`nmcli c s 'System enp0s8'|grep ipv4.addresses|awk '{print $2}'|cut -d'/' -f 1`
      sudo nmcli c m 'System enp0s8' ipv4.dns 192.168.14.100 ipv4.dns-search example.com
      sudo nmcli c m enp0s3 ipv4.dns 192.168.14.100 ipv4.dns-search example.com
      sudo nmcli networking off && sudo nmcli networking on
  fi
  sleep 5
  del_DNS
}

function setup_public_container_registry {
  if [ ! -d /opt/registry ]; then
    sudo parted -s /dev/sdb mklabel gpt
    sudo parted -s /dev/sdb unit mib mkpart primary 1 100%
    sudo parted -s /dev/sdb set 1 lvm on
    sudo partprobe /dev/sdb
    sudo pvcreate /dev/sdb1
    sudo vgcreate vg1 /dev/sdb1
    sudo lvcreate -n lvregistry1 -L4G vg1
    sudo mkfs.xfs /dev/vg1/lvregistry1
    sudo mkdir -p /opt/registry
    sudo echo /dev/vg1/lvregistry1 /opt/registry xfs defaults 1 2 >> /etc/fstab
    sudo mount -a
    sudo mkdir -p /opt/registry/certs /opt/registry/auth /opt/registry/data
    sudo echo -e "
[req]
default_bits=2048
default_md=sha256
prompt=no
encrypt_key=no
distinguished_name=dn
req_extensions=req_ext

[dn]
C=PT
O=example.com
ST=Braga
L=Braga
CN=registry.example.com

[req_ext]
subjectAltName=DNS:utility.example.com" > /root/registry.cnf
    #openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt
    sudo openssl req -config /root/registry.cnf -x509 -days 365 -keyout /opt/registry/certs/domain.key -out /opt/registry/certs/domain.crt
    #cp -r /vagrant/certs/* /opt/registry/certs
    sudo echo "GODEBUG=x509ignoreCN=0" >> /etc/environment
    sudo cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust 
    sudo htpasswd -bBc /opt/registry/auth/htpasswd registryuser 5mskw14k.
    sudo htpasswd -bB /opt/registry/auth/htpasswd root 5mskw14k.
        
    sudo podman pull registry.access.redhat.com/ubi8/ubi
    sudo podman pull registry.access.redhat.com/ubi7
    sudo podman run --name myregistry -p 443:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -v /opt/registry/certs:/certs:z -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt" -e "REGISTRY_HTTP_TLS_KEY=/certs/domain.key" -e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true -d docker.io/library/registry:latest
    sudo podman generate systemd --restart-policy=always -n myregistry > /root/container-myregistry.service
    sudo mv /root/container-myregistry.service /usr/lib/systemd/system
    sudo chcon -u system_u -t systemd_unit_file_t /usr/lib/systemd/system/container-myregistry.service    
    sudo podman stop myregistry
    sudo systemctl enable container-myregistry.service --now

    del_DNS
    
    sudo podman tag `podman images -n | grep ubi8 | awk '{print $3}'` registry.example.com/ubi8/ubi
    sudo podman tag `podman images -n | grep ubi7| awk '{print $3}'` registry.example.com/ubi7:latest
    sudo podman push registry.example.com/ubi8/ubi --remove-signatures
    sudo podman push registry.example.com/ubi7:latest --remove-signatures
    sudo systemctl restart container-myregistry.service
  fi
}

function setup_Utility_Services {
  ### Specific Repo mount for NFS
  if [ ! -d /mnt/sr1 ]; then
    sudo mkdir -p /mnt/sr1
  fi

  if [ `lsblk /dev/sr1| grep sr1|wc -l` -eq 0 ]; then
    if [ `grep sr0 /etc/fstab|wc -l` -eq 0 ]; then
      sudo -u root bash -c "echo /dev/sr0 /mnt/sr1 iso9660 ro 1 2 >> /etc/fstab"
    fi
  else
    if [ `grep sr1 /etc/fstab|wc -l` -eq 0 ]; then
      sudo -u root bash -c "echo /dev/sr1 /mnt/sr1 iso9660 ro 1 2 >> /etc/fstab"
    fi
  fi
  sudo mount -a
  sudo rm -f /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
  if [ ! -f /etc/yum.repos.d/baseos.repo ]; then
    sudo echo -e "
[BaseOS]
name='BaseOS Repo'
baseurl=file:///mnt/sr1/BaseOS
gpgcheck=0
enabled=1
" > /etc/yum.repos.d/baseos.repo
  fi
  if [ ! -f /etc/yum.repos.d/appstream.repo ]; then
    sudo cp /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
    sudo sed -i 's/BaseOS/AppStream/g' /etc/yum.repos.d/appstream.repo
  fi 
##### Ansible setup
# setup_Ansible

##### Install Services
   sudo dnf -y install nfs-utils firewalld bind-utils bind tree httpd-tools
   sudo dnf -y module install container-tools

##### Setup firewall rules
   if [ "`systemctl is-enabled firewalld.service`" == "disabled" ]; then
     sudo systemctl enable firewalld.service --now
     sudo firewall-cmd --zone public --add-service nfs --permanent
     sudo firewall-cmd --zone public --add-service ntp --permanent
     sudo firewall-cmd --zone public --add-service dns --permanent
     sudo firewall-cmd --zone public --add-service http --permanent
     sudo firewall-cmd --zone public --add-service https --permanent
     sudo firewall-cmd --zone public --add-port 5000/tcp --permanent
     sudo firewall-cmd --reload
   fi

##### Setup NFS
   if [ `cat /etc/exports|wc -l` -eq 0 ] || [ ! -f /etc/exports ] ; then
     ### export RedHat CD mount point for lab infra
     sudo echo "/mnt/sr1 192.168.14.0/24(ro,sync,no_subtree_check)" > /etc/exports
     ### create NFS user share for lab infra
     if [ ! -d /rmtusers ]; then
	sudo mkdir -p /rmtusers
	sudo chmod 755 /rmtusers
        sudo echo "/rmtusers 192.168.14.0/24(rw,sync,no_subtree_check)" >> /etc/exports
        sudo exportfs -rav
     fi
     sudo sed -i 's/#tcp=y/tcp=y/g' /etc/nfs.conf
     sudo sed -i 's/#vers4.0=y/vers4.0=y/g' /etc/nfs.conf
     sudo sed -i 's/#vers4.0=y/vers4.0=y/g' /etc/nfs.conf
     sudo sed -i 's/#vers4.1=y/vers4.1=y/g' /etc/nfs.conf
     sudo sed -i 's/#vers4.2=y/vers4.2=y/g' /etc/nfs.conf
   fi

   if [ "`systemctl is-enabled nfs-server.service`" == "disabled" ]; then
     sudo systemctl enable nfs-server.service --now
     sudo exportfs -rav
   fi

##### Setup DNS

if [ ! -f /etc/named/example.com ]; then
   if [ ! -d /etc/named ]; then
       sudo mkdir -p /etc/named
   fi
   sudo echo -e "
zone \"example.com\" IN {
  type master;
  file \"/etc/named/example.com\";
  allow-update {localnet;};
  allow-query {localnet;};
};
" | grep -v "^$" > /etc/named.rfc1912.zones
   sudo echo -e "
zone \"14.168.192.in-addr.arpa\" IN {
  type master;
  file \"/etc/named/example.com.rr\";
  allow-update {localnet;};
  allow-query {localnet;};
};
" | grep -v "^$" > /etc/named.rfc1912.zones.rr

   sudo echo -e "
\$TTL 3H
@  IN SOA @ utility.example.com (
  1;  serial
  3H; refresh
  1H; retry
  1W; expire
  3H
)
				IN NS utility.example.com.
utility.example.com.		IN A 192.168.14.100
registry.example.com.		IN A 192.168.14.100
nfs.example.com.		IN CNAME utility.example.com.
time.example.com.		IN CNAME utility.example.com.

acontroller.example.com.	IN A 192.168.14.101
rhel83-std-1.example.com.	IN A 192.168.14.110
rhel83-std-2.example.com.	IN A 192.168.14.111
rhcsa1.example.com.		IN A 192.168.14.110
rhcsa2.example.com.		IN A 192.168.14.111
ansible1.example.com.		IN A 192.168.14.120
ansible2.example.com.		IN A 192.168.14.121
rhce1.example.com.		IN A 192.168.14.120
rhce2.example.com.		IN A 192.168.14.121
" | grep -v "^$" > /etc/named/example.com

   sudo echo -e "
\$ORIGIN 14.168.192.in-addr.arpa.
\$TTL 3H
@ IN SOA utility.example.com. hostmaster.example.com. (
  1;  serial
  3H; refresh
  1H; retry
  1W; expire
  3H
)
@ 	IN NS utility.example.com.
100	IN PTR utility.example.com.
100	IN PTR registry.example.com.

101	IN PTR acontroller.example.com.
110	IN PTR rhel83-std-1.example.com.
110	IN PTR rhcsa1.example.com.
111	IN PTR rhel83-std-2.example.com.
111	IN PTR rhcsa2.example.com.
120	IN PTR ansible1.example.com.
120	IN PTR rhce1.example.com.
121	IN PTR ansible2.example.com.
121	IN PTR rhce2.example.com.
" | grep -v "^$" > /etc/named/example.com.rr

sudo echo -e "
acl localnet {
  192.168.14.0/24;
  127.0.0.1/24;
  192.168.56.0/24;
  192.168.57.0/24;
  10.0.2.0/24;
};

acl listenIPs {
  192.168.14.100;
  127.0.0.1;
}; 
options {
  listen-on port 53 { listenIPs; };
  directory \"/var/named\";
  allow-query { localnet; };
  recursion yes;
  pid-file \"/run/named/named.pid\";
};
logging {
  channel default_debug {
    file \"data/named.run\";
    severity dynamic;
  };
};
include \"/etc/named.rfc1912.zones\";
include \"/etc/named.rfc1912.zones.rr\";
include \"/etc/named.root.key\";
" > /etc/named.conf
fi 

  if [ "`systemctl is-enabled named.service`" == "disabled" ]; then
    sudo systemctl enable named.service --now
  fi

##### Setup NTP server
  if [ `cat /etc/chrony.conf | grep 192.168.14.0 | wc -l` -eq 0 ]; then
    sudo echo allow 192.168.14.0/24 >> /etc/chrony.conf
    sudo systemctl restart chronyd.service
  fi

##### Delete the vmware dhcp generated nameserver
  del_DNS

##### Registry install
## Here
  setup_public_container_registry

}

function setup_Ansible {
##### Ansible setup
  if [ `sudo dnf list installed python3-pip.noarch|grep python3-pip|wc -l` -eq 0 ]; then
      sudo dnf -y install python36 python3-pip.noarch --allowerasing
  fi
  sudo su - ansible -c "pip3 install -U pip --user"
  sudo su - ansible -c "sudo alternatives --set python /usr/bin/python3"
  sudo su - ansible -c "pip3 install ansible --user"
}

function setup_Client_Repos {
  if [ ! -d /opt/repos ]; then
    sudo mkdir -p /opt/repos
  fi
  if [ `grep utility /etc/hosts|wc -l` -eq 0 ]; then
    sudo su - root -c "echo 192.168.14.100 utility.example.com utility >> /etc/hosts"
  fi
  if [ `grep utility /etc/fstab|wc -l` -eq 0 ]; then
    sudo su - root -c "echo utility.example.com:/mnt/sr1 /opt/repos nfs ro 0 0 >> /etc/fstab"
  fi
  del_DNS
  sudo mount -a
  
  sudo rm -f /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
  if [ ! -f /etc/yum.repos.d/baseos.repo ]; then
    sudo echo -e "
[BaseOS]
name='BaseOS Repo'
baseurl=file:///opt/repos/BaseOS
gpgcheck=0
enabled=1
" > /etc/yum.repos.d/baseos.repo
  fi
  if [ ! -f /etc/yum.repos.d/appstream.repo ]; then
    sudo cp /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
    sudo sed -i 's/BaseOS/AppStream/g' /etc/yum.repos.d/appstream.repo
  fi
  del_DNS
  sudo dnf -y install autofs
}

function setup_Client_Services {
  del_DNS
   sudo dnf -y install autofs python36 python3-pip
}

function setup_automount {
  sudo umount /opt/repos
  if [ ! -f /opt/auto.opt ]; then
    sudo su - root -c "echo /opt /etc/auto.opt >> /etc/auto.master"
    sudo su - root -c "echo repos utility.example.com:/mnt/sr1 > /etc/auto.opt"
    sudo umount /opt/repos
    sudo sed -i "/\/mnt\/sr1/d" /etc/fstab
  fi
  del_DNS
  if [ "`sudo systemctl is-enabled autofs`" == "disabled" ]; then
    sudo systemctl enable autofs --now
  fi
  sudo systemctl restart autofs
  cd /opt/repos
  df -h
}

function simple_AnsibleClient {
      setup_IF_DNS
      setup_Client_Repos
      setup_Client_Services
      setup_Ansible_User
      setup_Ansible
      setup_automount
}

cHostname=`sudo nmcli g h`

case $cHostname in 
   utility.example.com)
##### Setup for utility.example.com
##
      setup_IF_DNS
      setup_Utility_Services
      sudo systemctl restart container-myregistry.service
      setup_Ansible_User
      del_DNS
      ;;
   acontroller.example.com)
##### Setup for acontroller.example.com
      simple_AnsibleClient
      ;;
   ansible1.example.com)
##### Setup for ansible1.example.com
      simple_AnsibleClient
      ;;
   ansible2.example.com)
##### Setup for ansible2.example.com
      simple_AnsibleClient
      ;;
   rhel84-std-1)
##### Setup for rhel84-std-1
      sudo sed -i '/rhel84-std-1/d' /etc/hosts
      sudo rm -f /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
      ;;
   rhel84-std-2)
##### Setup for rhel84-std-1
      sudo sed -i '/rhel84-std-2/d' /etc/hosts
      sudo rm -f /etc/yum.repos.d/baseos.repo /etc/yum.repos.d/appstream.repo
      ;;
 esac

