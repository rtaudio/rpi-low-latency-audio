#!/bin/bash


#set -e


PERIOD_SIZE=48
RING_BUFFER_SIZE=8000


cd /root/arm-dev

echo "Starting Audio streamer." > /tmp/start-streamer.log

./udp2jack/start-jack.sh

echo "Starting UDP2JACK (BUFFERSIZE = $RING_BUFFER_SIZE)..."  > /tmp/start-streamer.log
sleep 1
./udp2jack/udp2jack $RING_BUFFER_SIZE > /tmp/udp2jack.log 2> /tmp/udp2jack.err &
echo "Startend. Connect ports.."  > /tmp/start-streamer.log
sleep 1
jack_connect udp-receiver:out0 system:playback_1
jack_connect udp-receiver:out1 system:playback_2

jack_bufsize $PERIOD_SIZE

# mount boot readonly!
mount -o remount -r /dev/mmcblk0p1


#exit 0
