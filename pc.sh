#!/bin/bash

NIC=$1
REMOTEIP=$2

FREQ=5785

killall rx rx_rc_telemetry_buf rssirx rssi_qgc_forward gst-launch-1.0 tx_telemetry

echo "Setup interfaces..."
ifconfig $NIC down
iw $NIC set monitor fcsfail otherbss
ifconfig $NIC up
iw dev $NIC set freq $FREQ

echo "Init shared memory..."
sharedmem_init_rx
mkfifo /tmp/videofifo

echo "Starting video..."

rx -p 0 -d 1 -b 8 -r 4 -f 1024 $NIC > /tmp/videofifo &
RXPID=$!

sleep 2

rssirx $NIC &
rssi_qgc_forward $REMOTEIP 5154 &
rx_rc_telemetry_buf -o 1 -p 1 -r 99 $NIC | socat -b 128 GOPEN:/dev/stdin UDP4-SENDTO:$REMOTEIP:5011 &

socat -u UDP4-LISTEN:5565 SYSTEM":tx_telemetry -c 1 -p 30 -r 2 -x 99 -d 24 -y 0 $NIC" &

#sleep 20
cat /tmp/videofifo | gst-launch-1.0 fdsrc ! h264parse ! rtph264pay pt=96 config-interval=1 ! udpsink port=5600 host=$REMOTEIP

kill $(jobs -p)
