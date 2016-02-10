#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

git status ./root

echo "Above your see your changes (if any). This script will undo them."

read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
	# copy attributes (e.g. permissions), not following symlinks
	echo "Deleting ./root..."
	rm -r ./root
	echo "git checkout ./root..."
	git checkout ./root	
	echo "done!"
	echo "Fixing permissions:"
	./fix-permissions.sh
fi



#rsync -avun --delete ./root/ ./root_from_targz/ |grep "delet"
