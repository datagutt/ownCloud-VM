#!/bin/bash

HTML=/var/www
OCPATH=$HTML/owncloud
IFCONFIG="/sbin/ifconfig"
IP="/sbin/ip"
IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
ADDRESS=$($IFCONFIG | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
SCRIPTS=/var/scripts

php $SCRIPTS/update-config.php $OCPATH/config/config.php 'trusted_domains[]' localhost ${ADDRESS[@]} $(hostname) $(hostname --fqdn) 2>&1 >/dev/null
php $SCRIPTS/update-config.php $OCPATH/config/config.php overwrite.cli.url https://$ADDRESS/owncloud 2>&1 >/dev/null

exit 0
