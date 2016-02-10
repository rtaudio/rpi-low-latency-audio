#!/bin/bash

# this script applies configuration from the boot partition
#cp -u /boot/rtconfig/hostapd.conf /etc/hostapd/hostapd.conf

CNF_DIR="/boot/rtaudio-config"

[[ -f $CNF_DIR/create_ap.conf ]] && cp $CNF_DIR/create_ap.conf /tmp/create_ap.conf
[[ -f $CNF_DIR/wifi-profile.conf ]] && cp $CNF_DIR/wifi-profile.conf /tmp/rtaudio-wifi
