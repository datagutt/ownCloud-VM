#!/bin/bash

# Tech and Me, ©2016 - www.techandme.se
#
# This install from ownCloud repos with PHP 7
CONVER=v1.1.0.0
CONVER_FILE=contacts.tar.gz
CONVER_REPO=https://github.com/owncloud/contacts/releases/download
CALVER=v1.0
CALVER_FILE=calendar.tar.gz
CALVER_REPO=https://github.com/owncloud/calendar/releases/download
SHUF=$(shuf -i 13-15 -n 1)
MYSQL_PASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w $SHUF | head -n 1)
PW_FILE=/var/mysql_password.txt
SCRIPTS=/var/scripts
HTML=/var/www
OCPATH=$HTML/owncloud
SSL_CONF="/etc/apache2/sites-available/owncloud_ssl_domain_self_signed.conf"
IFCONFIG="/sbin/ifconfig"
IP="/sbin/ip"
IFACE=$($IP -o link show | awk '{print $2,$9}' | grep "UP" | cut -d ":" -f 1)
ADDRESS=$($IFCONFIG | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e `uname -r | cut -f1,2 -d"-"` | grep -e [0-9] | xargs sudo apt-get -y purge)
GITHUB_REPO=https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/production
UNIXUSER=ocadmin
UNIXPASS=owncloud

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/owncloud_install_production.sh"
        echo
        exit 1
fi

# Create ocadmin if not existing
getent passwd $UNIXUSER  > /dev/null
if [ $? -eq 0 ]
then
        echo "$UNIXUSER already exists!"
else
        useradd -d /home/$UNIXUSER -m $UNIXUSER
        echo -e "$UNIXUSER:$UNIXPASS" | chpasswd
        echo "$UNIXUSER created!"
fi

# Create $SCRIPTS dir
      	if [ -d $SCRIPTS ]; then
      		sleep 1
      		else
      	mkdir $SCRIPTS
fi

# Change DNS
echo "nameserver 8.26.56.26" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 8.20.247.20" >> /etc/resolvconf/resolv.conf.d/base

# Check network
sudo ifdown $IFACE && sudo ifup $IFACE
nslookup google.com
if [[ $? > 0 ]]
then
    echo "Network NOT OK. You must have a working Network connection to run this script."
    exit
else
    echo "Network OK."
fi

# Update system
apt-get update

# Set locales
sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure locales

# Show MySQL pass, and write it to a file in case the user fails to write it down
echo
echo -e "Your MySQL root password is: \e[32m$MYSQL_PASS\e[0m"
echo "Please save this somewhere safe. The password is also saved in this file: $PW_FILE."
echo "$MYSQL_PASS" > $PW_FILE
chmod 600 $PW_FILE
echo -e "\e[32m"
read -p "Press any key to continue..." -n1 -s
echo -e "\e[0m"

# Install MYSQL 5.6
apt-get install software-properties-common -y
echo "mysql-server-5.6 mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
echo "mysql-server-5.6 mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections
apt-get install mysql-server-5.6 -y

# mysql_secure_installation
aptitude -y install expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_PASS\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
aptitude -y purge expect

# Install Apache
apt-get install apache2 -y
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif

# Set hostname and ServerName
sudo sh -c "echo 'ServerName owncloud' >> /etc/apache2/apache2.conf"
sudo hostnamectl set-hostname owncloud
service apache2 restart

# Install PHP 7.0
apt-get install python-software-properties -y && echo -ne '\n' | sudo add-apt-repository ppa:ondrej/php
apt-get update
apt-get install -y \
        libapache2-mod-php7.0 \
        php7.0-common \
        php7.0-mysql \
        php7.0-intl \
        php7.0-mcrypt \
        php7.0-ldap \
        php7.0-imap \
        php7.0-cli \
        php7.0-gd \
        php7.0-pgsql \
        php7.0-json \
        php7.0-sqlite3 \
        php7.0-curl \
	php7.0-xml \
	php7.0-zip \
        php-smbclient 

# Download and install ownCloud
wget -nv https://download.owncloud.org/download/repositories/stable/Ubuntu_14.04/Release.key -O Release.key
apt-key add - < Release.key && rm Release.key
sh -c "echo 'deb http://download.owncloud.org/download/repositories/stable/Ubuntu_14.04/ /' >> /etc/apt/sources.list.d/owncloud.list"
apt-get update && apt-get install owncloud-files -y

# Secure permissions
wget -q $GITHUB_REPO/setup_secure_permissions_owncloud.sh -P $SCRIPTS
bash $SCRIPTS/setup_secure_permissions_owncloud.sh

# Install ownCloud
cd $OCPATH
sudo -u www-data php occ maintenance:install --database "mysql" --database-name "owncloud_db" --database-user "root" --database-pass "$MYSQL_PASS" --admin-user "ocadmin" --admin-pass "owncloud"
echo
echo ownCloud version:
sudo -u www-data php $OCPATH/occ status
echo
sleep 3

# Prepare cron.php to be run every 15 minutes
crontab -u www-data -l | { cat; echo "*/15  *  *  *  * php -f $OCPATH/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

# Change values in php.ini (increase max file size)
# max_execution_time
sed -i "s|max_execution_time = 30|max_execution_time = 3500|g" /etc/php/7.0/apache2/php.ini
# max_input_time
sed -i "s|max_input_time = 60|max_input_time = 3600|g" /etc/php/7.0/apache2/php.ini
# memory_limit
sed -i "s|memory_limit = 128M|memory_limit = 512M|g" /etc/php/7.0/apache2/php.ini
# post_max
sed -i "s|post_max_size = 8M|post_max_size = 1100M|g" /etc/php/7.0/apache2/php.ini
# upload_max
sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 1000M|g" /etc/php/7.0/apache2/php.ini

# Install Figlet
apt-get install figlet -y

# Generate $SSL_CONF
if [ -f $SSL_CONF ];
        then
        echo "Virtual Host exists"
else
        touch "$SSL_CONF"
        cat << SSL_CREATE > "$SSL_CONF"
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on

### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com

### SETTINGS ###
    DocumentRoot $OCPATH

    <Directory $OCPATH>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any
    </Directory>

    Alias /owncloud "$OCPATH/"

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    SetEnv HOME $OCPATH
    SetEnv HTTP_HOME $OCPATH

### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
SSL_CREATE
echo "$SSL_CONF was successfully created"
sleep 3
fi

# Enable new config
a2ensite owncloud_ssl_domain_self_signed.conf
a2dissite default-ssl
service apache2 restart

# Get script for Redis
        if [ -f $SCRIPTS/install-redis-php-7.sh ];
                then
                echo "install-redis-php-7.sh exists"
                else
        wget -q $GITHUB_REPO/install-redis-php-7.sh -P $SCRIPTS
fi

# Install Redis
bash $SCRIPTS/install-redis-php-7.sh
rm $SCRIPTS/install-redis-php-7.sh

## Set config values
# Experimental apps
sudo -u www-data php $OCPATH/occ config:system:set appstore.experimental.enabled --value="true"
# Default mail server (make this user configurable?)
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpmode --value="smtp"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpauth --value="1"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpport --value="465"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtphost --value="smtp.gmail.com"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpauthtype --value="LOGIN"
sudo -u www-data php $OCPATH/occ config:system:set mail_from_address --value="www.en0ch.se"
sudo -u www-data php $OCPATH/occ config:system:set mail_domain --value="gmail.com"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpsecure --value="ssl"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtpname --value="www.en0ch.se@gmail.com"
sudo -u www-data php $OCPATH/occ config:system:set mail_smtppassword --value="techandme_se"

# Install Libreoffice Writer to be able to read MS documents.
echo -ne '\n' | sudo apt-add-repository ppa:libreoffice/libreoffice-4-4
apt-get update
sudo apt-get install --no-install-recommends libreoffice-writer -y

# Install Unzip
apt-get install unzip -y

# Download and install Documents
if [ -d $OCPATH/apps/documents ]; then
sleep 1
else
wget -q https://github.com/owncloud/documents/archive/master.zip -P $OCPATH/apps
cd $OCPATH/apps
unzip -q master.zip
rm master.zip
mv documents-master/ documents/
fi

# Enable documents
if [ -d $OCPATH/apps/documents ]; then
sudo -u www-data php $OCPATH/occ app:enable documents
sudo -u www-data php $OCPATH/occ config:system:set preview_libreoffice_path --value="/usr/bin/libreoffice"
fi

# Download and install Contacts
if [ -d $OCPATH/apps/contacts ]; then
sleep 1
else
wget -q $CONVER_REPO/$CONVER/$CONVER_FILE -P $OCPATH/apps
tar -zxf $OCPATH/apps/$CONVER_FILE -C $OCPATH/apps
cd $OCPATH/apps
rm $CONVER_FILE
fi

# Enable Contacts
if [ -d $OCPATH/apps/contacts ]; then
sudo -u www-data php $OCPATH/occ app:enable contacts
fi

# Download and install Calendar
if [ -d $OCPATH/apps/calendar ]; then
sleep 1
else
wget -q $CALVER_REPO/$CALVER/$CALVER_FILE -P $OCPATH/apps
tar -zxf $OCPATH/apps/$CALVER_FILE -C $OCPATH/apps
cd $OCPATH/apps
rm $CALVER_FILE
fi

# Enable Calendar
if [ -d $OCPATH/apps/calendar ]; then
sudo -u www-data php $OCPATH/occ app:enable calendar
fi

# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SCRIPTS/setup_secure_permissions_owncloud.sh

# Change roots .bash_profile
        if [ -f $SCRIPTS/change-root-profile.sh ];
                then
                echo "change-root-profile.sh exists"
                else
        wget -q $GITHUB_REPO/change-root-profile.sh -P $SCRIPTS
fi
# Change ocadmin .bash_profile
        if [ -f $SCRIPTS/change-ocadmin-profile.sh ];
                then
                echo "change-ocadmin-profile.sh  exists"
                else
        wget -q $GITHUB_REPO/change-ocadmin-profile.sh -P $SCRIPTS
fi
# Get startup-script for root
        if [ -f $SCRIPTS/owncloud-startup-script.sh ];
                then
                echo "owncloud-startup-script.sh exists"
                else
        wget -q $GITHUB_REPO/owncloud-startup-script.sh -P $SCRIPTS
fi

# Welcome message after login (change in /home/ocadmin/.profile
        if [ -f $SCRIPTS/instruction.sh ];
                then
                echo "instruction.sh exists"
                else
        wget -q $GITHUB_REPO/instruction.sh -P $SCRIPTS
fi
# Clears command history on every login
        if [ -f $SCRIPTS/history.sh ];
                then
                echo "history.sh exists"
                else
        wget -q $GITHUB_REPO/history.sh -P $SCRIPTS
fi

# Change root profile
        	bash $SCRIPTS/change-root-profile.sh
if [[ $? > 0 ]]
then
	echo "change-root-profile.sh were not executed correctly."
	sleep 10
else
	echo "change-root-profile.sh script executed OK."
	rm $SCRIPTS/change-root-profile.sh
	sleep 2
fi
# Change ocadmin profile
        	bash $SCRIPTS/change-ocadmin-profile.sh
if [[ $? > 0 ]]
then
	echo "change-ocadmin-profile.sh were not executed correctly."
	sleep 10
else
	echo "change-ocadmin-profile.sh executed OK."
	rm $SCRIPTS/change-ocadmin-profile.sh
	sleep 2
fi

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow ocadmin to run theese scripts
chown ocadmin:ocadmin $SCRIPTS/instruction.sh
chown ocadmin:ocadmin $SCRIPTS/history.sh

# Upgrade
aptitude full-upgrade -y

#Cleanup
echo "$CLEARBOOT"

# Get the latest owncloud-startup-script.sh
echo "Writes to rc.local..."

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

# Download owncloud-startup-script.sh
		echo "Downloading owncloud-startup-script.sh...."
		rm $SCRIPTS/owncloud-startup-script.sh
		wget -q $GITHUB_REPO/owncloud-startup-script.sh -P $SCRIPTS

# Check if script exists, otherwise reboot (possible loop)
	if [ -f $SCRIPTS/owncloud-startup-script.sh ];
        then
                echo "Download successful!" 
                sleep 3
        else
		echo "Download failed, rebooting in 15 seconds until success. Please check you network connection"
		sleep 15
		reboot
	fi
	
# Restore colors
echo -e "\e[0"

# Make $SCRIPTS excutable
chmod +x -R $SCRIPTS
chown root:root -R $SCRIPTS

# Allow ocadmin to run theese scripts
chown ocadmin:ocadmin $SCRIPTS/instruction.sh
chown ocadmin:ocadmin $SCRIPTS/history.sh

exit 0

RCLOCAL

# Reboot
reboot

exit 0
