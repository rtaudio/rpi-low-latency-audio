# rpi-low-latency-audio

* Arch linux for RPI2
* root file system located in ```root/```
* Enabled SSH root access (PW root)

# Create a bootable SD-Card
* Clone this repo on a linux host
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
