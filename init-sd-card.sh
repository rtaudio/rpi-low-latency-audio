#!/bin/bash

DEV=$1
if [ -z $DEV ]; then
	echo ""
	echo "Please provide the SD-card device (sdX) as first argument! Your system has:"
	echo ""
	lsblk -f
	echo ""
	echo "error, exit"
	exit 1
fi


#stop on error
set -e

if [ "`ls -l /dev/disk/by-id/usb* | grep /$DEV`" == "" ]; then
  echo "/dev/$DEV seems not to be a USB drive. Cancel for safety, sorry!"
  exit 1
fi

echo "You will lose all data on:"
lsblk -f | grep $DEV
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ $REPLY == y ]]
then

./umount-sd-card.sh $DEV
	

# fits on 2GB SD-card:
read -p "Small root partition (for 2GB SD-cards)? (y/n) " -n 1 -r
echo ""
if [[ $REPLY == y ]]
then
	FC="o\nn\np\n1\n\n+300M\nt\nc\nn\np\n2\n\n+1500M\nn\np\n3\n\n+50M\nt\n3\nc\nw"
else
	FC="o\nn\np\n1\n\n+300M\nt\nc\nn\np\n2\n\n+2500M\nn\np\n3\n\n+50M\nt\n3\nc\nw"
fi

echo -e "FDISK cmd: \n$FC"

echo -e $FC | fdisk /dev/$DEV 1> /dev/null


if [ "$?" == "1" ]; then
  echo "fdisk error!"
  exit 1
fi

echo "creating file systems..."
mkfs.vfat /dev/${DEV}1 1> /dev/null # boot
mkfs.ext4 /dev/${DEV}2 1> /dev/null # root
mkfs.vfat /dev/${DEV}3 1> /dev/null # conf

sync
lsblk -f | grep $DEV

echo "OK! /dev/$DEV partitions are ready to be filled!"
./mount-sd-card.sh $DEV
exit 0

fi # safety check
