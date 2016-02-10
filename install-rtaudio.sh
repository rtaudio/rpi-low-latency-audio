set -e

ROOTFS=../root
ROOTFS=../mnt/ssh_root
[[ -d $ROOTFS/var ]] || (echo "In $ROOTFS is not a rootfs!"; exit 1;)

RTAHOME="$ROOTFS/home/rtaudio"
mkdir -p $RTAHOME

# install the on-first-boot service:



cp on-first-boot.sh $RTAHOME
chmod +x $RTAHOME/on-first-boot.sh

cp rtaudio-first-boot.service $ROOTFS/usr/lib/systemd/system/rtaudio-first-boot.service
ln /etc/systemd/system/multi-user.target.wants /home/rtaudio/on-first-boot.sh
