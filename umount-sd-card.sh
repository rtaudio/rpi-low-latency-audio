DEV=$1

if [ -z $DEV ]; then
	echo "no device given!"
	exit 1
fi

sync

umount mnt/boot &> /dev/null
umount mnt/root &> /dev/null
umount mnt/conf &> /dev/null

sync

echo "$DEV unmounted"
exit 0
