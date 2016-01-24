#!/bin/bash
#
## Tech and Me ## - 2015, https://www.techandme.se/about-me
#
SCRIPTS=/var/scripts
PW_FILE=/var/mysql_password.txt # Keep in sync with owncloud_install_production.sh
IFACE="eth0"
IFCONFIG="/sbin/ifconfig"
ADDRESS=$($IFCONFIG $IFACE | awk -F'[: ]+' '/\<inet\>/ {print $4; exit}')
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | xargs sudo apt-get -y purge)
WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
PHPMYADMIN_CONF="/etc/apache2/conf-available/phpmyadmin.conf"

	# Check if root
	if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/owncloud-startup-script.sh"
        echo
        exit 1
fi

echo "Getting scripts from GitHub to be able to run the first setup..."

	# Update Config
        if [ -f $SCRIPTS/update-config.php ];
                then
                echo "update-config.php exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/update-config.php -P $SCRIPTS
fi
        
        # Activate SSL
        if [ -f $SCRIPTS/activate-ssl.sh ];
                then
                echo "activate-ssl.sh exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/lets-encrypt/activate-ssl.sh -P $SCRIPTS
fi
        # The update script
        if [ -f $SCRIPTS/owncloud_update.sh ];
                then
                echo "owncloud_update.sh exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/owncloud_update.sh -P $SCRIPTS
fi
        # Sets trusted domain in when owncloud-startup-script.sh is finished
        if [ -f $SCRIPTS/trusted.sh ];
                then
                echo "trusted.sh exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/trusted.sh -P $SCRIPTS
fi
                # Sets static IP to UNIX
        if [ -f $SCRIPTS/ip.sh ];
                then
                echo "ip.sh exists"
                else
      	wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/ip.sh -P $SCRIPTS
fi
                # Tests connection after static IP is set
        if [ -f $SCRIPTS/test_connection.sh ];
                then
                echo "test_connection.sh exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/test_connection.sh -P $SCRIPTS
fi
                # Sets secure permissions after upgrade
        if [ -f $SCRIPTS/setup_secure_permissions_owncloud.sh ];
                then
                echo "setup_secure_permissions_owncloud.sh exists"
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/setup_secure_permissions_owncloud.sh -P $SCRIPTS
fi
        # Get the Welcome Screen when http://$address
        if [ -f $SCRIPTS/index.php ];
                then
                rm $SCRIPTS/index.php
                else
        wget -q https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production/index.php -P $SCRIPTS
fi
        mv /var/scripts/index.php /var/www/html/index.php && rm -f /var/www/html/index.html
        chmod 750 /var/www/html/index.php && chown www-data:www-data /var/www/html/index.php
        
# Make $SCRIPTS excutable 
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

clear
echo "+--------------------------------------------------------------------+"
echo "| This script will configure your ownCloud and activate SSL.         |"
echo "| It will also do the following:                                     |"
echo "|                                                                    |"
echo "| - Activate a Virtual Host for your ownCloud install                |"
echo "| - Make phpMyadmin secure                                           |"
echo "| - Install Webmin                                                   |"
echo "| - Upgrade your system to latest version                            |"
echo "| - Set secure permissions to ownCloud                               |"
echo "| - Set new passwords to Ubuntu Server and ownCloud                  |"
echo "| - Set new keyboard layout                                          |"
echo "| - Change timezone                                                  |"
echo "| - Install SMB-client to be able to mount external storages         |"
echo "| - Set static IP to the system (you have to set the same IP in      |"
echo "|   your router) https://www.techandme.se/open-port-80-443/          |"
echo "|                                                                    |"
echo "|   The script will take about 10 minutes to finish,                 |"
echo "|   depending on your internet connection.                           |"
echo "|                                                                    |"
echo "| #################### Tech and Me - 2015-2016 ##################### |"
echo "+--------------------------------------------------------------------+"
echo -e "\e[32m"
read -p "Press any key to start the script..." -n1 -s
clear
echo -e "\e[0m"

# Activate self-signed SSL
a2enmod ssl
a2enmod headers
a2dissite default-ssl.conf
a2ensite owncloud_ssl_domain_self_signed.conf 
clear
echo "owncloud_ssl_domain_self_signed.conf is enabled, this is your pre-configured virtual host"
sleep 4
echo
service apache2 reload

# Secure phpMyadmin
if [ -f $PHPMYADMIN_CONF ];
        then
        rm $PHPMYADMIN_CONF
        touch "$PHPMYADMIN_CONF"
        cat << CONF_CREATE > "$PHPMYADMIN_CONF"
# phpMyAdmin default Apache configuration

Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
        Options FollowSymLinks
        DirectoryIndex index.php

        <IfModule mod_authz_core.c>
# Apache 2.4
        <RequireAny>
        Require ip $WANIP
        Require ip 127.0.0.1
        Require ip ::1
        </RequireAny>
        </IfModule>
        <IfModule !mod_authz_core.c>
# Apache 2.2
        Order Deny,Allow
        Deny from All
        Allow from $WANIP
        Allow from ::1
        Allow from localhost
</IfModule>

        <IfModule mod_php5.c>
                AddType application/x-httpd-php .php

                php_flag magic_quotes_gpc Off
                php_flag track_vars On
                php_flag register_globals Off
                php_admin_flag allow_url_fopen Off
                php_value include_path .
                php_admin_value upload_tmp_dir /var/lib/phpmyadmin/tmp
                php_admin_value open_basedir /usr/share/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/:/usr/share/php/php-gettext/:/usr/share/javascript/
        </IfModule>

</Directory>
# Authorize for setup
<Directory /usr/share/phpmyadmin/setup>
    <IfModule mod_authn_file.c>
    AuthType Basic
    AuthName "phpMyAdmin Setup"
    AuthUserFile /etc/phpmyadmin/htpasswd.setup
    </IfModule>
    Require valid-user
</Directory>

# Disallow web access to directories that don't need it
<Directory /usr/share/phpmyadmin/libraries>
    Order Deny,Allow
    Deny from All
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib>
    Order Deny,Allow
    Deny from All
</Directory>
CONF_CREATE
echo
echo "$PHPMYADMIN_CONF was successfully secured."
echo
sleep 3
fi

# Install packages for Webmin
apt-get install --force-yes -y zip perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python

# Install Webmin
sed -i '$a deb http://download.webmin.com/download/repository sarge contrib' /etc/apt/sources.list
wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
apt-get update
apt-get install --force-yes -y webmin
echo
echo "Webmin is installed, access it from your browser: https://$ADDRESS:10000"
sleep 3

# Install php5-libsmbclient
#apt-get install php5-libsmbclient -y
#apt-get install cifs-utils -y
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
echo "Current Timezone is Swedish"
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
ifdown eth0
sleep 2
ifup eth0
sleep 2
bash $SCRIPTS/ip.sh
ifdown eth0
sleep 2
ifup eth0
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
ifdown eth0
sleep 2
ifup eth0
sleep 2
echo
bash $SCRIPTS/test_connection.sh
sleep 2
clear

# Change Trusted Domain and CLI
bash $SCRIPTS/trusted.sh

# Change password
echo -e "\e[0m"
echo "For better security, change the Linux password for [ocadmin]"
echo "The current password is [owncloud]"
echo -e "\e[32m"
read -p "Press any key to change password for Linux... " -n1 -s
echo -e "\e[0m"
sudo passwd ocadmin
if [[ $? > 0 ]]
then
    sudo passwd ocadmin
else
    sleep 2
fi
echo
clear &&
echo -e "\e[0m"
echo "For better security, change the ownCloud password for [ocadmin]"
echo "The current password is [owncloud]"
echo -e "\e[32m"
read -p "Press any key to change password for ownCloud... " -n1 -s
echo -e "\e[0m"
sudo -u www-data php /var/www/owncloud/occ user:resetpassword ocadmin
if [[ $? > 0 ]]
then
    sudo -u www-data php /var/www/owncloud/occ user:resetpassword ocadmin
else
    sleep 2
fi
clear

# Let's Encrypt
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
if [[ "yes" == $(ask_yes_or_no "Last but not least, do you want to install a real SSL cert (from Let's Encrypt) on this machine?") ]]
then
	sudo bash $SCRIPTS/activate-ssl.sh
else
echo
    echo "OK, but if you want to run it later, just type: bash $SCRIPTS/activate-ssl.sh"
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
echo -e "|         \e[0mPublish your server online! \e[36mhttp://goo.gl/H7IsHm\e[32m           |"
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
sudo -u www-data php /var/www/owncloud/occ maintenance:repair
rm $SCRIPTS/owncloud-startup-script.sh
rm $SCRIPTS/ip.sh
rm $SCRIPTS/trusted.sh
rm $SCRIPTS/test_connection.sh
rm $SCRIPTS/change-ocadmin-profile.sh
rm $SCRIPTS/change-root-profile.sh
rm $SCRIPTS/redis_latest_php5.sh
rm $SCRIPTS/update-config.php
rm /var/www/owncloud/data/owncloud.log
cat /dev/null > ~/.bash_history
cat /dev/null > /var/spool/mail/root
cat /dev/null > /var/spool/mail/ocadmin
cat /dev/null > /var/log/apache2/access.log
cat /dev/null > /var/log/apache2/error.log
cat /dev/null > /var/log/cronjobs_success.log
sed -i 's|sudo -i||g' /home/ocadmin/.bash_profile
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
