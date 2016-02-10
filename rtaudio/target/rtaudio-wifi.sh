#!/bin/bash


echo "rtaudio: wifi start ..."  > /dev/tty0


if ! /usr/bin/netctl start rtaudio-wifi &> /dev/tty0
then
  CNF="`cat /tmp/create_ap.conf`"
    if [[ ! -z "$CNF" ]]; then
      echo "create_ap $CNF" > /dev/tty0;
      /usr/bin/create_ap $CNF &> /dev/tty0 &
    fi
fi

#-n -g 10.0.0.1 wlan0 AccessPointSSID





