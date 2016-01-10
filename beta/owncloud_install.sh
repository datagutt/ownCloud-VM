#!/bin/bash

# Tech and Me, 2016 - www.techandme.se

mysql_pass=owncloud
OCVERSION=owncloud-8.2.2.zip
SCRIPTS=/var/scripts
HTML=/var/www/html
OCPATH=$HTML/owncloud
ssl_conf="/etc/apache2/sites-available/owncloud_ssl_domain_self_signed.conf"
IFACE="eth0"
IFCONFIG="/sbin/ifconfig"
ADDRESS=$($IFCONFIG $IFACE | awk -F'[: ]+' '/\<inet\>/ {print $4; exit}')

# Check if root
        if [ "$(whoami)" != "root" ]; then
        echo
        echo -e "\e[31mSorry, you are not root.\n\e[0mYou must type: \e[36msudo \e[0mbash $SCRIPTS/owncloud_install.sh"
        echo
        exit 1
fi

# Change DNS
echo "nameserver 8.26.56.26" > /etc/resolvconf/resolv.conf.d/base
echo "nameserver 8.20.247.20" >> /etc/resolvconf/resolv.conf.d/base

# Check network
sudo ifdown eth0 && sudo ifup eth0
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

# Install MYSQL 5.6
apt-get install software-properties-common -y
add-apt-repository -y ppa:ondrej/mysql-5.6
echo "mysql-server-5.6 mysql-server/root_password password $mysql_pass" | debconf-set-selections
echo "mysql-server-5.6 mysql-server/root_password_again password $mysql_pass" | debconf-set-selections
apt-get install mysql-server-5.6 -y

# mysql_secure_installation
aptitude -y install expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$mysql_pass\r\"
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

# Install PHP 7
apt-get install python-software-properties -y && echo -ne '\n' | sudo add-apt-repository ppa:ondrej/php-7.0
apt-get update
apt-get install -y \
        php7.0 \
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
        libsm6 \
        libsmbclient

# Download $OCVERSION
wget https://download.owncloud.org/community/$OCVERSION -P $HTML
apt-get install unzip -y
unzip -q $HTML/$OCVERSION -d $HTML 
rm $HTML/$OCVERSION

# Create data folder, occ complains otherwise
mkdir $OCPATH/data

# Secure permissions
wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/beta/setup_secure_permissions_owncloud.sh -P $SCRIPTS
bash $SCRIPTS/setup_secure_permissions_owncloud.sh

# Install ownCloud
cd $OCPATH
sudo -u www-data php occ maintenance:install --database "mysql" --database-name "owncloud_db" --database-user "root" --database-pass "$mysql_pass" --admin-user "ocadmin" --admin-pass "owncloud"
echo
echo ownCloud version:
sudo -u www-data php $OCPATH/occ status
echo
sleep 3

# Set trusted domain
wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/beta/update-config.php -P $SCRIPTS
chmod a+x $SCRIPTS/update-config.php
php $SCRIPTS/update-config.php $OCPATH/config/config.php 'trusted_domains[]' localhost ${ADDRESS[@]} $(hostname) $(hostname --fqdn)
php $SCRIPTS/update-config.php $OCPATH/config/config.php overwrite.cli.url https://$ADDRESS/owncloud

# Prepare cron.php to be run every 15 minutes
# The user still has to activate it in the settings GUI
sudo crontab -u www-data -l | { cat; echo "*/15  *  *  *  * php -f /var/www/owncloud/cron.php > /dev/null 2>&1"; } | crontab -u www-data -

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

# Generate $ssl_conf
if [ -f $ssl_conf ];
        then
        echo "Virtual Host exists"
else
        touch "$ssl_conf"
        cat << SSL_CREATE > "$ssl_conf"
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
echo "$ssl_conf was successfully created"
sleep 3
fi

# Enable new config
a2ensite owncloud_ssl_domain_self_signed.conf
a2dissite default-ssl
service apache2 restart

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
sudo -u www-data php $OCPATH/occ config:system:set mail_smtppassword --value="hejasverige"

# Install Libreoffice Writer to be able to read MS documents.
echo -ne '\n' | sudo apt-add-repository ppa:libreoffice/libreoffice-4-4
apt-get update
sudo apt-get install --no-install-recommends libreoffice-writer -y

# Download and install Documents
if [ -d $OCPATH/apps/documents ]; then
sleep 1
else
wget https://github.com/owncloud/documents/archive/master.zip -P $OCPATH/apps
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
wget https://github.com/owncloud/contacts/archive/master.zip -P $OCPATH/apps
unzip -q $OCPATH/apps/master.zip -d $OCPATH/apps
cd $OCPATH/apps
rm master.zip
mv contacts-master/ contacts/
fi

# Enable Contacts
if [ -d $OCPATH/apps/contacts ]; then
sudo -u www-data php $OCPATH/occ app:enable contacts
fi

# Download and install Calendar
if [ -d $OCPATH/apps/calendar ]; then
sleep 1
else
wget https://github.com/owncloud/calendar/archive/master.zip -P $OCPATH/apps
unzip -q $OCPATH/apps/master.zip -d $OCPATH/apps
cd $OCPATH/apps
rm master.zip
mv calendar-master/ calendar/
fi

# Enable Calendar
if [ -d $OCPATH/apps/calendar ]; then
sudo -u www-data php $OCPATH/occ app:enable calendar
fi


# Set secure permissions final (./data/.htaccess has wrong permissions otherwise)
bash $SCRIPTS/setup_secure_permissions_owncloud.sh

# Start startup-script
bash $SCRIPTS/owncloud-startup-script.sh
exit 1
