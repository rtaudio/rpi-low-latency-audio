set -e

DEV=$1

if [ -z $DEV ]; then
	echo "no device given!"
	exit 1
fi

mkdir -p mnt/boot
mkdir -p mnt/root
mkdir -p mnt/conf

mount /dev/${DEV}1 mnt/boot
mount /dev/${DEV}2 mnt/root
mount /dev/${DEV}3 mnt/conf

echo "mounted $DEV in ./mnt/*"
