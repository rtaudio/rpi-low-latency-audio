killall jackd
# -p64
JACK_CMD_LINE="-R -P40 -t2000 --silent -dalsa -dhw:1,0 -p512 -n2 -r48000 -o2 -s -S"
echo "jackd $JACK_CMD_LINE"
jackd $JACK_CMD_LINE > /tmp/jackd.log 2> /tmp/jackd.err &

#exit 0
