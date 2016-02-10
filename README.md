# rpi-low-latency-audio
This is a toolset to create headless embedded systems with a ligheight Arch Linux that boots within seconds and performs real-time tasks. It is currently tested with the Raspberry PI 2, but due to its generality it should run on other ARM SoCs too.

It's initial focus is on real-time audio processing.

* easy Wi-Fi adapter management that automatically creates a hotspot if no wireless network is available. The SoC will always be accessible, even without any network infrastructure or cable (only a WI-Fi USB dongle is needed)
* It can boot into a RAM disk so the SD-Card module can be disabled. This increases real-time reliability


This repo includes:
* Generic Toolchain for partition of SD-Card and incremental arch linux deployment
* Minifier to reduce the compelete OS size to about 200MB (for small ramfs images)
* Custom systemd services for initial boot automation
* WiFi hotspot and WiFi client management
* A QEMU-emulated chroot script to chroot into the embedded root file system on any non-ARM (x68/x64) linux  host system (e.g. to install additional packages through pacman)
* Configuration service that enables configuration through a FAT-partition from a Windows machine
* Some boot optimization techniques (not all possible). The aim is to get the system to boot within 5 seconds

You will never need to do any manual configuration/SSH connection to the embedded system. Comfortably prepare/maintain the OS on your linux machine or virtual machine. Changes can be deployed quickly through an icremental sync with the SD-Card or over SSH.

# Getting started
* Clone this repo on a linux host (required packages on host: ```bsdtar sshfs qemu binfmt-support qemu-user-static``` )
* Get root permissions ```su root```
* Run ```./fix-permissions.sh``` to setup attributes and create empty directories in ```./root``` (requires an automatic download of the latest arch linux release)
* Create SD card partition with ```./init-sd-card.sh```
* 

The above in a single command where ```sdX``` is the SD-card:
```DEV=sdX && ./fix-permissions.sh && ./umount-sd-card.sh $DEV && ./init-sd-card.sh $DEV && ./copy-to-sd-card.sh && ./umount-sd-card.sh $DEV```

# Additionally installed Packages
* irman
* dnsmasq (DHCP server)
* hostapd (WiFi hotspot)
* jack2

# system.d services
create_ap.service
hostapd.service
streamer.service



# Need Remove
xinit, anything x

# Scripts
/root/remount_root_rw.sh
/root/arm-dev/start-streamer.sh

# Dev files files (should be modulized in external repos TODO)
/root/arm-dev/udp2jack




# rpi-low-latency-audio

* Arch linux for RPI2
* root file system located in ```root/```
* 
You should clone as root, not with sudo:
```su root
git clone https://github.com/rtaudio/rpi-low-latency-audio.git
```

# Additionally installed Packages
* irman
* dnsmasq (DHCP server)
* hostapd (WiFi hotspot)
* jack2

# system.d services
create_ap.service
hostapd.service
streamer.service



# Need Remove
xinit, anything x

# Scripts
/root/remount_root_rw.sh
/root/arm-dev/start-streamer.sh

# Dev files files (should be modulized in external repos TODO)
/root/arm-dev/udp2jack

