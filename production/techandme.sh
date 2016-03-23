#!/bin/bash
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
ADDRESS=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
clear
figlet -f small Tech and Me
echo "           https://www.techandme.se"
echo
echo
echo
echo "WAN IP: $WANIP"
echo "LAN IP: $ADDRESS"
echo
exit 0
