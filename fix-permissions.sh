#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "ArchLinuxARM-rpi-2-latest.tar.gz"
[[ -f ArchLinuxARM-rpi-2-latest.tar.gz ]] \
	|| wget http://archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz

[[ -d root_from_targz ]] || mkdir root_from_targz

bsdtar --version || apt-get install bsdtar
[[ -d root_from_targz/var ]] || bsdtar -xpf ArchLinuxARM-rpi-2-latest.tar.gz -C root_from_targz

# copy dir skeleton (except /usr & ./var/lib)
cd root_from_targz
find -type d \( -path ./usr -o -path ./var/lib \) -prune -o -links 2 -exec mkdir -p "../root/{}" \;
cd ..

#redundantely create basic directories
mkdir -p root/dev root/mnt root/proc root/run root/srv root/sys root/tmp



# copy permission (from http://askubuntu.com/questions/56792/how-to-copy-only-file-attributes-metadata-without-actual-content-of-the-file/150888#150888)


if false
then
	# this is not 100% compatible to all coreutils

	COREUTILS_VER=`cp --version | grep cp | grep coreutils | awk '{print $(NF)}'`
	echo "Coreutils version: $COREUTILS_VER"
	echo "This version number must be >= 8.17. Otherwise this script will mess up the ./root directory. " 
	read -p "Continue? (y/n) " -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		# copy attributes (e.g. permissions), not following symlinks
		echo "Fixing permissions..."
		cp --archive --attributes-only ./root_from_targz/. ./root/
	fi
else
	echo "Fixing permissions (there can be an error with ./root/etc/mtab)..."
	myecho=echo
	src_path="./root_from_targz/"
	dst_path="./root/"

	#files
	find "$src_path" |
	  while read src_file; do
	    dst_file="$dst_path${src_file#$src_path}"
	    if [[ -f "$dst_file" ]]; then
		    chmod --reference="$src_file" "$dst_file"
		    chown --reference="$src_file" "$dst_file"
	    fi
	  done

	#directories
	find "$src_path" -type d |
	  while read src_file; do
	    dst_file="$dst_path${src_file#$src_path}"
	    chmod --reference="$src_file" "$dst_file"
	    chown --reference="$src_file" "$dst_file"
	  done

	echo "done!";
fi

# lists new directories:
#rsync -avun --delete ./root/ ./root_from_targz/ |grep "delet"

