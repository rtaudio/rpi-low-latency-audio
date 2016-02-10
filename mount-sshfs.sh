#this requires sshfs
set -e

if [ -z $1 ]; then
	echo "no host given!!"
	exit 1
fi

HOST=$1
USER=root
REMOTE_FOLDER=/

sshfs --version || apt-get install sshfs

#echo realpath $0
#LOCAL_BASE_DIR="`dirname \`realpath $0\``/mnt"
LOCAL_BASE_DIR="./mnt"

#[[ -d "$LOCAL_BASE_DIR/ssh_root" ]] || mkdir -p "$LOCAL_BASE_DIR/ssh_root"

umount "$LOCAL_BASE_DIR/ssh_root" || fusermount -u "$LOCAL_BASE_DIR/ssh_root" || true

echo "mounting $USER@$HOST:/"
sshfs $USER@$HOST:/ "$LOCAL_BASE_DIR/ssh_root"

ls "$LOCAL_BASE_DIR/ssh_root"
