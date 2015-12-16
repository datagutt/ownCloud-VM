#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

SCRIPTS=/var/scripts

      	# Create dir
      	if [ -d $SCRIPTS ]; then
      		sleep 1
      		else
      	mkdir $SCRIPTS
fi
        # Activate SSL
        if [ -f $SCRIPTS/activate-ssl.sh ];
                then
                echo "activate-ssl.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/lets-encrypt/activate-ssl.sh -P $SCRIPTS
fi
        
        # The update script
        if [ -f $SCRIPTS/owncloud_update.sh ];
                then
                echo "owncloud_update.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/owncloud_update.sh -P $SCRIPTS
fi
        # Sets trusted domain in when owncloud-startup-script.sh is finished
        if [ -f $SCRIPTS/trusted.sh ];
                then
                echo "trusted.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/trusted.sh -P $SCRIPTS
fi
                # Sets static IP to UNIX
        if [ -f $SCRIPTS/ip.sh ];
                then
                echo "ip.sh exists"
                else
      	wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/ip.sh -P $SCRIPTS
fi
                # Tests connection after static IP is set
        if [ -f $SCRIPTS/test_connection.sh ];
                then
                echo "test_connection.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/test_connection.sh -P $SCRIPTS
fi
                # Sets secure permissions after upgrade
        if [ -f $SCRIPTS/setup_secure_permissions_owncloud.sh ];
                then
                echo "setup_secure_permissions_owncloud.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/setup_secure_permissions_owncloud.sh -P $SCRIPTS
fi
                # Welcome message after login (change in /home/ocadmin/.profile
        if [ -f $SCRIPTS/instruction.sh ];
                then
                echo "instruction.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/instruction.sh -P $SCRIPTS
fi
                # Clears command history on every login
        if [ -f $SCRIPTS/history.sh ];
                then
                echo "history.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/history.sh -P $SCRIPTS
fi
                # Change roots .bash_profile
        if [ -f $SCRIPTS/change-root-profile.sh ];
                then
                echo "change-root-profile.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/change-root-profile.sh -P $SCRIPTS
fi
                # Change ocadmin .bash_profile
        if [ -f $SCRIPTS/change-ocadmin-profile.sh ];
                then
                echo "change-ocadmin-profile.sh  exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/change-ocadmin-profile.sh -P $SCRIPTS
fi
                # Get startup-script for root
        if [ -f $SCRIPTS/owncloud-startup-script.sh ];
                then
                echo "owncloud-startup-script.sh exists"
                else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/owncloud-startup-script.sh -P $SCRIPTS
fi
        # Make $SCRIPTS excutable 
        chmod +x -R $SCRIPTS
        chown root:root -R $SCRIPTS

        # Allow ocadmin to run theese scripts
        chown ocadmin:ocadmin $SCRIPTS/instruction.sh
        chown ocadmin:ocadmin $SCRIPTS/history.sh

        # Get the Welcome Screen when http://$address
		if [ -f $SCRIPTS/index.php ];
                then
                rm $SCRIPTS/index.php
                else        
		wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/index.php -P $SCRIPTS
fi        
		mv /var/scripts/index.php /var/www/html/index.php && rm -f /var/www/html/index.html
        chmod 750 /var/www/html/index.php && chown www-data:www-data /var/www/html/index.php


        # Change .profile
        bash $SCRIPTS/change-root-profile.sh
        bash $SCRIPTS/change-ocadmin-profile.sh

exit 0
