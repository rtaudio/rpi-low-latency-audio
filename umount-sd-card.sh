DEV=$1

if [ -z $DEV ]; then
	echo "no device given!"
	exit 1
fi

sync

umount mnt/boot &> /dev/null
umount mnt/root &> /dev/null
umount mnt/conf &> /dev/null

umount /dev/${DEV}1 &> /dev/null
umount /dev/${DEV}2 &> /dev/null
umount /dev/${DEV}3 &> /dev/null

sync

echo "/dev/$DEV* unmounted"
exit 0
