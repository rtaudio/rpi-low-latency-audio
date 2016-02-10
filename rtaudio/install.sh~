#!/bin/bash
set -e


SSH_HOST=$1

if [[ -z $SSH_HOST ]]; then
	ROOTFS=./root
else
	ROOTFS=./mnt/ssh_root
	./mount-sshfs.sh $SSH_HOST
fi


[[ -d $ROOTFS/var ]] || (echo "In $ROOTFS is not a rootfs!"; exit 1;)


RTAHOME="$ROOTFS/home/rtaudio"
mkdir -p $RTAHOME

cp -a -r ./rtaudio/target/* $RTAHOME
chmod +x $RTAHOME/*.sh
cp --preserve=timestamps -r -u -n $RTAHOME/rtaudio-config $ROOTFS/boot/
rm -r $RTAHOME/rtaudio-config

if [[ -z $SSH_HOST ]]; then
	./chroot.sh "/home/rtaudio/install.sh /home/rtaudio"
	echo "chroot exit"

else
	ssh root@$SSH_HOST "/home/rtaudio/install.sh /home/rtaudio && sync && (sleep 1 && reboot) &"
	echo "ssh exit"	
fi

