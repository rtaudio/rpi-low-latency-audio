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
