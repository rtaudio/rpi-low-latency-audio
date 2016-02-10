set -e

ROOTFS=./root
CHROOT_ROOT=./root_chroot


update-binfmts --import
update-binfmts --enable

cat /proc/sys/fs/binfmt_misc/qemu-arm > /dev/null || (echo "qemu-arm binfmt not existing!"; exit 1)

cp -u /usr/bin/qemu-arm-static $ROOTFS/usr/bin

# resolv.conf
[[ -h $ROOTFS/etc/resolv.conf ]] \
	&& mv $ROOTFS/etc/resolv.conf $ROOTFS/etc/resolv.conf.bak \
	&& cp /etc/resolv.conf $ROOTFS/etc/

mkdir -p $CHROOT_ROOT
mount -o bind $ROOTFS $CHROOT_ROOT
mount -t proc proc $CHROOT_ROOT/proc
mount -t sysfs sys $CHROOT_ROOT/sys
mount -o bind /dev $CHROOT_ROOT/dev

set +e
chroot $CHROOT_ROOT

umount $CHROOT_ROOT/proc
umount $CHROOT_ROOT/sys
umount $CHROOT_ROOT/dev
umount $CHROOT_ROOT


rm $ROOTFS/etc/resolv.conf
mv $ROOTFS/etc/resolv.conf.bak $ROOTFS/etc/resolv.conf

