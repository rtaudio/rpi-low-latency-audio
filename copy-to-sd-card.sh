#rm -r mnt/root/*

if [[ -z "`mount | grep mnt/boot`" ]]; then
	echo "SD not mounted correctly!"
	echo "Run ./mount-sd-card.sh."
	exit 1
fi

echo "rsync boot..."
rsync -r -u -t ./root/boot/ ./mnt/boot/

if [[ -d ./conf ]]; then
	echo "rsync conf (update only)..."
	rsync -r -u -t  ./conf/ ./mnt/conf/
else
	echo "No ./conf, skipping!"
fi

#echo "Copying root (no-clobber!)..."
#cp -n -r --no-dereference --preserve=all root/* mnt/root/

echo "rsync root..."
rsync -a --progress ./root/ ./mnt/root/

echo "rsync done, sync ..."
sync

echo "SD card ready to boot!"
echo "Unmount it with ./umount-sd-card.sh"
exit 0


