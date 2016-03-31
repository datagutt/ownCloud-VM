#!/bin/bash

# Tech and Me - ©2016, https://www.techandme.se/

WWW_ROOT=/var/www
OCPATH=$WWW_ROOT/owncloud
OCDATA=/var/data
SCRIPTS=/var/scripts
PW_FILE=/var/mysql_password.txt # Keep in sync with owncloud_install_production.sh
IFCONFIG="/sbin/ifconfig"
IP="/sbin/ip"
IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
ADDRESS=$($IFCONFIG | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | xargs sudo apt-get -y purge)
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"
GITHUB_REPO="https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production"
LETS_ENC="https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/lets-encrypt"
UNIXUSER=ocadmin
UNIXPASS=owncloud

	# Check if root
	if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/owncloud-startup-script.sh"
        echo
        exit 1
fi

echo "Getting scripts from GitHub to be able to run the first setup..."

        # phpMyadmin
        if [ -f $SCRIPTS/phpmyadmin_install.sh ];
                then
                rm $SCRIPTS/phpmyadmin_install.sh
                wget -q $GITHUB_REPO/phpmyadmin_install.sh -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/phpmyadmin_install.sh -P $SCRIPTS
fi
	# Update Config
        if [ -f $SCRIPTS/update-config.php ];
                then
                rm $SCRIPTS/update-config.php
                wget -q $GITHUB_REPO/update-config.php -P $SCRIPTS
                else
       	wget -q $GITHUB_REPO/update-config.php -P $SCRIPTS
fi

        # Activate SSL
        if [ -f $SCRIPTS/activate-ssl.sh ];
                then
                rm $SCRIPTS/activate-ssl.sh
                wget -q $LETS_ENC/activate-ssl.sh -P $SCRIPTS
                else
        wget -q $LETS_ENC/activate-ssl.sh -P $SCRIPTS
fi
        # The update script
        if [ -f $SCRIPTS/owncloud_update.sh ];
                then
                rm $SCRIPTS/owncloud_update.sh
                wget -q $GITHUB_REPO/owncloud_update.sh -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/owncloud_update.sh -P $SCRIPTS
fi
        # Sets trusted domain in when owncloud-startup-script.sh is finished
        if [ -f $SCRIPTS/trusted.sh ];
                then
                rm $SCRIPTS/trusted.sh
                wget -q $GITHUB_REPO/trusted.sh -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/trusted.sh -P $SCRIPTS
fi
                # Sets static IP to UNIX
        if [ -f $SCRIPTS/ip.sh ];
                then
                rm $SCRIPTS/ip.sh
                wget -q $GITHUB_REPO/ip.sh -P $SCRIPTS
                else
      	wget -q $GITHUB_REPO/ip.sh -P $SCRIPTS
fi
                # Tests connection after static IP is set
        if [ -f $SCRIPTS/test_connection.sh ];
                then
                rm $SCRIPTS/test_connection.sh
                wget -q $GITHUB_REPO/test_connection.sh -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/test_connection.sh -P $SCRIPTS
fi
                # Sets secure permissions after upgrade
        if [ -f $SCRIPTS/setup_secure_permissions_owncloud.sh ];
                then
                rm $SCRIPTS/setup_secure_permissions_owncloud.sh
                wget -q $GITHUB_REPO/setup_secure_permissions_owncloud.sh
                else
        wget -q $GITHUB_REPO/setup_secure_permissions_owncloud.sh -P $SCRIPTS
fi
                # Get figlet Tech and Me
        if [ -f $SCRIPTS/techandme.sh ];
                then
                rm $SCRIPTS/techandme.sh
                wget -q $GITHUB_REPO/techandme.sh -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/techandme.sh -P $SCRIPTS
fi

        # Get the Welcome Screen when http://$address
        if [ -f $SCRIPTS/index.php ];
                then
                rm $SCRIPTS/index.php
                wget -q $GITHUB_REPO/index.php -P $SCRIPTS
                else
        wget -q $GITHUB_REPO/index.php -P $SCRIPTS
fi
        mv $SCRIPTS/index.php $WWW_ROOT/index.php && rm -f $WWW_ROOT/html/index.html
        chmod 750 $WWW_ROOT/index.php && chown www-data:www-data $WWW_ROOT/index.php

        # Change 000-default to $WEB_ROOT
        sed -i "s|DocumentRoot /var/www/html|DocumentRoot $WWW_ROOT|g" /etc/apache2/sites-available/000-default.conf

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow $UNIXUSER to run figlet script
chown $UNIXUSER:$UNIXUSER $SCRIPTS/techandme.sh

clear
echo "+--------------------------------------------------------------------+"
echo "| This script will configure your ownCloud and activate SSL.         |"
echo "| It will also do the following:                                     |"
echo "|                                                                    |"
echo "| - Activate a Virtual Host for your ownCloud install                |"
echo "| - Install phpMyadmin and make it secure                            |"
echo "| - Install Webmin                                                   |"
echo "| - Upgrade your system to latest version                            |"
echo "| - Set secure permissions to ownCloud                               |"
echo "| - Set new passwords to Ubuntu Server and ownCloud                  |"
echo "| - Set new keyboard layout                                          |"
echo "| - Change timezone                                                  |"
echo "| - Set static IP to the system (you have to set the same IP in      |"
echo "|   your router) https://www.techandme.se/open-port-80-443/          |"
echo "|                                                                    |"
echo "|   The script will take about 10 minutes to finish,                 |"
echo "|   depending on your internet connection.                           |"
echo "|                                                                    |"
echo "| ####################### Tech and Me - 2016 ####################### |"
echo "+--------------------------------------------------------------------+"
echo -e "\e[32m"
read -p "Press any key to start the script..." -n1 -s
clear
echo -e "\e[0m"

# Install phpMyadmin
bash $SCRIPTS/phpmyadmin_install.sh
rm $SCRIPTS/phpmyadmin_install.sh

# Install packages for Webmin
apt-get install --force-yes -y zip perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python

# Install Webmin
sed -i '$a deb http://download.webmin.com/download/repository sarge contrib' /etc/apt/sources.list
wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
apt-get update
apt-get install webmin -y
echo
echo "Webmin is installed, access it from your browser: https://$ADDRESS:10000"
sleep 4
clear

# Set keyboard layout
echo "Current keyboard layout is Swedish"
echo "You must change keyboard layout to your language"
echo -e "\e[32m"
read -p "Press any key to change keyboard layout... " -n1 -s
echo -e "\e[0m"
dpkg-reconfigure keyboard-configuration
echo
clear

# Change Timezone
echo "Current timezone is Europe/Stockholm"
echo "You must change timezone to your timezone"
echo -e "\e[32m"
read -p "Press any key to change timezone... " -n1 -s
echo -e "\e[0m"
dpkg-reconfigure tzdata
echo
sleep 3
clear

# Change IP
echo -e "\e[0m"
echo "The script will now configure your IP to be static."
echo -e "\e[36m"
echo -e "\e[1m"
echo "Your internal IP is: $ADDRESS"
echo -e "\e[0m"
echo -e "Write this down, you will need it to set static IP"
echo -e "in your router later. It's included in this guide:"
echo -e "https://www.techandme.se/open-port-80-443/ (step 1 - 5)"
echo -e "\e[32m"
read -p "Press any key to set static IP..." -n1 -s
clear
echo -e "\e[0m"
ifdown $IFACE
sleep 2
ifup $IFACE
sleep 2
bash $SCRIPTS/ip.sh
ifdown $IFACE
sleep 2
ifup $IFACE
sleep 2
echo
echo "Testing if network is OK..."
sleep 1
echo
bash $SCRIPTS/test_connection.sh
sleep 2
echo
echo -e "\e[0mIf the output is \e[32mConnected! \o/\e[0m everything is working."
echo -e "\e[0mIf the output is \e[31mNot Connected!\e[0m you should change\nyour settings manually in the next step."
echo -e "\e[32m"
read -p "Press any key to open /etc/network/interfaces..." -n1 -s
echo -e "\e[0m"
nano /etc/network/interfaces
clear
echo "Testing if network is OK..."
ifdown $IFACE
sleep 2
ifup $IFACE
sleep 2
echo
bash $SCRIPTS/test_connection.sh
sleep 2
clear

# Change Trusted Domain and CLI
bash $SCRIPTS/trusted.sh

if [ "$UNIXUSER" = "ocadmin" ]
then
# Change password
echo -e "\e[0m"
echo "For better security, change the Linux password for [$UNIXUSER]"
echo "The current password is [$UNIXPASS]"
echo -e "\e[32m"
read -p "Press any key to change password for Linux... " -n1 -s
echo -e "\e[0m"
sudo passwd $UNIXUSER
if [[ $? > 0 ]]
then
    sudo passwd $UNIXUSER
else
    sleep 2
fi
echo
clear &&
echo -e "\e[0m"
echo "For better security, change the ownCloud password for [$UNIXUSER]"
echo "The current password is [$UNIXPASS]"
echo -e "\e[32m"
read -p "Press any key to change password for ownCloud... " -n1 -s
echo -e "\e[0m"
sudo -u www-data php $OCPATH/occ user:resetpassword $UNIXUSER
if [[ $? > 0 ]]
then
    sudo -u www-data php $OCPATH/occ user:resetpassword $UNIXUSER
else
    sleep 2
fi
clear
else
echo "Not changing password as you already changed <user> and <pass> in the script"
fi

# Let's Encrypt
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "yes" == $(ask_yes_or_no "Do you want to install a real SSL cert (from Let's Encrypt) on this machine?
The script are still Beta, feel free to contribute!") ]]
then
	bash $SCRIPTS/activate-ssl.sh
else
echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
fi

# Upgrade system
clear
echo System will now upgrade...
sleep 2
echo
echo
bash $SCRIPTS/owncloud_update.sh

# Cleanup 1
apt-get autoremove -y
apt-get autoclean
echo "$CLEARBOOT"
clear

# Success!
echo -e "\e[32m"
echo    "+--------------------------------------------------------------------+"
echo    "| You have sucessfully installed ownCloud! System will now reboot... |"
echo    "|                                                                    |"
echo -e "|         \e[0mLogin to ownCloud in your browser:\e[36m" $ADDRESS"\e[32m           |"
echo    "|                                                                    |"
echo -e "|         \e[0mPublish your server online! \e[36mhttps://goo.gl/iUGE2U\e[32m          |"
echo    "|                                                                    |"
echo -e "|      \e[0mYour MySQL password is stored in: \e[36m$PW_FILE\e[32m     |"
echo    "|                                                                    |"
echo -e "|    \e[91m#################### Tech and Me - 2016 ####################\e[32m    |"
echo    "+--------------------------------------------------------------------+"
echo
read -p "Press any key to reboot..." -n1 -s
echo -e "\e[0m"
echo

# Cleanup 2
sudo -u www-data php $OCPATH/occ maintenance:repair
rm $SCRIPTS/owncloud-startup-script.sh
rm $SCRIPTS/ip.sh
rm $SCRIPTS/trusted.sh
rm $SCRIPTS/test_connection.sh
rm $SCRIPTS/update-config.php
rm $SCRIPTS/instruction.sh
rm $OCPATH/data/owncloud.log
sed -i "s|instruction.sh|techandme.sh|g" /home/$UNIXUSER/.bash_profile
cat /dev/null > ~/.bash_history
cat /dev/null > /var/spool/mail/root
cat /dev/null > /var/spool/mail/$UNIXUSER
cat /dev/null > /var/log/apache2/access.log
cat /dev/null > /var/log/apache2/error.log
cat /dev/null > /var/log/cronjobs_success.log
sed -i "s|sudo -i||g" /home/$UNIXUSER/.bash_profile
sed -i "s|mod_php5|mod_php7|g" $OCPATH/.htaccess
cat /dev/null > /etc/rc.local
cat << RCLOCAL > "/etc/rc.local"
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

exit 0

RCLOCAL

## Reboot
reboot

exit 0
