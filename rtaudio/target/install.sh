#!/bin/bash
#

ISD=$1
echo "Installing in chroot from $ISD..."
cd $ISD


[[ -f /usr/bin/make ]] || pacman -S make  --noconfirm
[[ -f /usr/bin/hostapd ]] || pacman -S hostapd  --noconfirm
[[ -f /usr/bin/dnsmasq ]] || pacman -S dnsmasq  --noconfirm
[[ -f /usr/bin/wpa_supplicant ]] || pacman -S wpa_supplicant  --noconfirm


sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
#cat /etc/ssh/sshd_config | grep PermitRootLogin


cp rtaudio-first-boot.service /usr/lib/systemd/system/rtaudio-first-boot.service
systemctl enable rtaudio-first-boot.service 2>/dev/null

cp rtaudio-config.service /usr/lib/systemd/system/rtaudio-config.service
systemctl enable rtaudio-config.service 2>/dev/null

cp rtaudio-wifi.service /usr/lib/systemd/system/rtaudio-wifi.service
systemctl enable rtaudio-wifi.service 2>/dev/null
systemctl disable create_ap.service  2>/dev/null


# create a symlink to temporary wifi profile file (/tmp/rtaudio-wifi will be created on boot)
echo "#tmp" > /tmp/rtaudio-wifi
rm -f /etc/netctl/rtaudio-wifi
ln -s /tmp/rtaudio-wifi /etc/netctl/rtaudio-wifi
rm /tmp/rtaudio-wifi

# create a hook to fallback to hotspot
cp -a ./wifi/netctl-hook /etc/netctl/hooks/



echo "First boot service added, you have to (re)boot the system now"

