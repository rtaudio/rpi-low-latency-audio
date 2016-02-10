# rpi-low-latency-audio
This is a toolset to create headless embedded systems with a ligheight Arch Linux that boots within seconds and performs real-time tasks. It is currently tested with the Raspberry PI 2, but due to its generality it should run on other ARM SoCs too.

It's initial focus is on real-time audio processing.

* easy Wi-Fi adapter management that automatically creates a hotspot if no wireless network is available. The SoC will always be accessible, even without any network infrastructure or cable (only a WI-Fi USB dongle is needed)
* It can boot into a RAM disk so the SD-Card module can be disabled. This increases real-time reliability


# Create a bootable SD-Card
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
