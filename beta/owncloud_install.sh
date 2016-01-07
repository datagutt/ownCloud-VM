#!/bin/bash

# Tech and Me, 2016 - www.techandme.se

/<>\ WARNING /<>\ THIS SCRIPT IS UNDER CONSTRUCTION

mysql_pass=owncloud
OCVERSION=owncloud-8.2.2.zip
SCRIPTS=/var/scripts
HTML=/var/www/html
OCPATH=$HTML/owncloud
ssl_conf="/etc/apache2/sites-available/owncloud_ssl_domain_self_signed.conf"
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

# Install MYSQL 5.6
apt-get install software-properties-common -y
add-apt-repository -y ppa:ondrej/mysql-5.6
apt-get install mysql-server-5.6 -y
debconf-set-selections <<< 'mysql-server-5.6 mysql-server-5.6/root_password password $mysql_pass'
debconf-set-selections <<< 'mysql-server-5.6 mysql-server-5.6/root_password_again password $mysql_pass'

# Install Apache
apt-get install apache2 -y
a2enmod rewrite \
        headers \
        env \
        dir \
        mime \
        ssl \
        setenvif

# Generate $ssl_conf
if [ -f $ssl_conf ];
        then
        echo "Virtual Host exists"
else
        touch "$ssl_conf"
        echo "$ssl_conf was successfully created"
        sleep 3
        cat << SSL_CREATE > "$ssl_conf"
<VirtualHost *:443>
    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on
### YOUR SERVER ADDRESS ###
#    ServerAdmin admin@example.com
#    ServerName example.com
#    ServerAlias subdomain.example.com 
### SETTINGS ###
    DocumentRoot $HTML/owncloud

    <Directory $HTML/owncloud>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    Satisfy Any 
    </Directory>

    Alias /owncloud "$HTML/owncloud/"

    <IfModule mod_dav.c>
    Dav off
    </IfModule>

    SetEnv HOME $HTML/owncloud
    SetEnv HTTP_HOME $HTML/owncloud
### LOCATION OF CERT FILES ###
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
SSL_CREATE
fi

# Enable new config
a2ensite owncloud_ssl_domain_self_signed.conf
service apache2 restart

# Install PHP 7
apt-get install python-software-properties -y && echo -ne '\n' | sudo add-apt-repository ppa:ondrej/php-7.0
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

# Set hostname and ServerName
sudo sh -c "echo 'ServerName owncloud' >> /etc/apache2/apache2.conf"
sudo hostnamectl set-hostname owncloud
sudo service apache2 restart

# Set locales
sudo locale-gen "sv_SE.UTF-8" && sudo dpkg-reconfigure locales

# Download $OCVERSION
wget https://download.owncloud.org/community/$OCVERSION -P $HTML
apt-get install unzip -y
unzip $HTML/$OCVERSION.zip

# Secure permissions
wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/testing/setup_secure_permissions_owncloud.sh -P $SCRIPTS
bash $SCRIPTS/setup_secure_permissions_owncloud.sh

# Install Libreoffice Writer
sudo apt-get install --no-install-recommends libreoffice-writer -y
echo -ne '\n' | sudo apt-add-repository ppa:libreoffice/libreoffice-4-4
# php $SCRIPTS/update-config.php $OCPATH/config/config.php preview_libreoffice_path' => '/usr/bin/libreoffice

# Install ownCloud
# Only works in OC 9
sudo -u www-data php $OCPATH/occ maintenance:install --database "owncloud_db" --database-name "owncloud" --database-user "root" --database-pass "owncloud" --admin-user "ocadmin" --admin-pass "owncloud"

# manual:
# sudo mysql_secure_installation  
