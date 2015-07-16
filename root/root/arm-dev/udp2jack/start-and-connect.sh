# Usage: start-and-connect.sh CIRCULAR_BUFFER_SIZE (defaults to 1024*20)

echo "Starting UDP2JACK..."
killall udp2jack
sleep 2
./udp2jack $1 &
echo "Startend. Connect ports.."
sleep 1
jack_connect udp-receiver:out0 system:playback_1
jack_connect udp-receiver:out1 system:playback_2

#read
#read
read -p "ss any key" 

echo "Exiting..."
sleep 1
killall udp2jack
