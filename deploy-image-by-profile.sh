#!/bin/bash

#imagename="debian7 debian8 debian10 centos7 centos8 ubuntu1604 bionic metasploitable kali arch"
which curl > /dev/null || ( echo "Please install curl" && exit )
imagename="$(curl -kqs https://download.goffinet.org/kvm/imagename)"
image=$4
# Generate an unique string
uuid=$(uuidgen -t)
name=$1
# Nested (default no)
nested=""
#nested="--cpu host-passthrough"
network=$2
# Profiles : xsmall, small, medium, big (and  desktop)
profile=$3
parameters=$#
# osinfo-query os
if [ $image = "bionic" ]; then
os="ubuntu18.04"
fi
if [ $image = "debian10" ]; then
os="debian9"
fi
if [ $image = "centos7" ]; then
os="centos7.0"
fi
if [ $image = "focal" ]; then
os="ubuntu18.04"
fi
if [ $image = "centos8" ]; then
os="centos7.0"
fi
if [ $image = "fedora32" ]; then
os="fedora28"
fi

usage_message () {
## Usage message
echo "Usage : $0 <name> <network_name> <profile> <image_name>"
echo "Profiles available : xsmall, small, medium, big, desktop"
echo "centos7 is the image name by default if ommited"
echo "Please download one of those images in /var/lib/libvirt/images :"
for x in $imagename ; do
echo "https://download.goffinet.org/kvm/${x}.qcow2"
done
}

profile_definition () {
# VCPUs
vcpu="1"
# The new guest disk name
disk="${name}-${uuid}.qcow2"
# Diskbus can be 'ide', 'scsi', 'usb', 'virtio' or 'xen'
diskbus="virtio"
size="8"
# Hypervisor can be 'qemu', 'kvm' or 'xen'
hypervisor="kvm"
# Graphics 'none' or 'vnc'
graphics="none"
# RAM in Mb
memory="256"
# Network interface and model 'virtio' or 'rtl8139' or 'e1000'
model="virtio"
case "$profile" in
    xsmall) ;;
    small) memory="512" ;;
    medium) memory="1024" ;;
    big) vcpu="2"
         memory="2048" ;;
    desktop) ;;
    *) usage_message ; exit ;;
esac
}

check_paramters () {
## Check parameters
if [ "$parameters" -eq 3 ] ; then image="centos7" ; fi
if [ "$parameters" -eq 4 ] ; then image=$image ; fi
if [ "$parameters" -gt 5  ] ; then usage_message ; exit ; fi
if [ "$parameters" -lt 3  ] ; then usage_message ; exit ; fi
#check a valid image name
if grep -qvw "$image" <<< "$imagename" ; then usage_message ; exit ; fi
# check the presence of the image
if [ ! -f /var/lib/libvirt/images/${image}.qcow2  ] ; then usage_message ; exit ; fi
# Check the usage of the requested domain
if grep -qw "$name" <<< $(virsh list --all --name)  ; then echo "Please provide an other guest name : exit" ; exit; fi
# Check the network
if [ ! -e /run/libvirt/network/${network}.xml ] ; then echo "$network network does not exist"
echo "Please create a new one or choose a valid present network : " ; virsh net-list ; exit; fi
}

copy_image () {
## Linked image copy to the default storage pool ##
#cp /var/lib/libvirt/images/$image /var/lib/libvirt/images/$disk
qemu-img create -f qcow2 -b /var/lib/libvirt/images/${image}.qcow2 /var/lib/libvirt/images/$disk
}

customize_new_disk () {
## Customize this new guest disk
if [ $image = "bionic" ]; then
sleep 1
virt-sysprep -a /var/lib/libvirt/images/$disk --operations customize --firstboot-command "sudo dbus-uuidgen > /etc/machine-id ; sudo hostnamectl set-hostname $name ; sudo reboot"
fi
if [ $image = "focal" ]; then
sleep 1
virt-sysprep -a /var/lib/libvirt/images/$disk --operations customize --firstboot-command "sudo dbus-uuidgen > /etc/machine-id ; sudo hostnamectl set-hostname $name ; sudo reboot"
fi
if [ $image = "debian10" ]; then
sleep 1
virt-sysprep -a /var/lib/libvirt/images/$disk --operations customize --firstboot-command "sudo dbus-uuidgen > /etc/machine-id ; sudo hostnamectl set-hostname $name ; sudo reboot"
fi
if [ $image = "centos7" ]; then
virt-sysprep -a /var/lib/libvirt/images/$disk --hostname $name --selinux-relabel  --quiet
fi
}

import_launch () {
## Import and lauch the new guest ##
virt-install \
--virt-type $hypervisor \
--name=$name \
--disk path=/var/lib/libvirt/images/$disk,size=$size,format=qcow2,bus=$diskbus \
--ram=$memory \
--vcpus=$vcpu \
--os-type=linux \
--os-variant=$os \
--network network=$network,model=$model \
--graphics $graphics \
--console pty,target_type=serial \
--import \
--noautoconsole $nested
}

start_time="$(date -u +%s)"
check_paramters
profile_definition
copy_image
customize_new_disk
import_launch
end_time="$(date -u +%s)"
echo "Time elapsed $(($end_time-$start_time)) second"
