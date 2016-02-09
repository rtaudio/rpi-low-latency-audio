# rpi-low-latency-audio

* Arch linux for RPI2

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
