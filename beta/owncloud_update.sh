#!/bin/bash
#
## Tech and Me ## - 2015-2016, https://www.techandme.se/
#
# Tested on Ubuntu Server 14.04.
#
SCRIPTS=/var/scripts
HTML=/var/www/html
OCPATH=$HTML/owncloud
BACKUP="$OCPATH/data/ $OCPATH/config/"


# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# System Upgrade
sudo apt-get update
sudo aptitude full-upgrade -y

rsync -Aax $OCPATH/data $HTML
rsync -Aax $OCPATH/config $HTML
wget https://download.owncloud.org/community/owncloud-latest.tar.bz2 -P $HTML

if [ -f $HTML/owncloud-latest.tar.bz2 ];
then
        echo "$HTML/owncloud-latest.tar.bz2 exists"
else
        echo "Abortitng,something went wrong with the download"
   exit 1
fi

if [ -d $OCPATH/config/ ]; then
        echo "config/ exists" 
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   exit 1
fi

if [ -d $OCPATH/data/ ]; then
        echo "data/ exists" && sleep 5
        rm -rf $OCPATH
        tar -xjvf $HTML/owncloud-latest.tar.bz2 -C $HTML 
        rm $HTML/owncloud-latest.tar.bz2
        cp -R $HTML/data $OCPATH/ && rm -rf $HTML/data
        cp -R $HTML/config $OCPATH/ && rm -rf $HTML/config
        bash /var/scripts/setup_secure_permissions_owncloud.sh
        sudo -u www-data php $OCPATH/occ upgrade
else
        echo "Something went wrong with backing up your old ownCloud instance, please check in $HTML if data/ and config/ folders exist."
   exit 1
fi

# Enable Apps
sudo -u www-data php $OCPATH/occ app:enable calendar
sudo -u www-data php $OCPATH/occ app:enable contacts
sudo -u www-data php $OCPATH/occ app:enable documents
sudo -u www-data php $OCPATH/occ app:enable external

# Second run (to make sure everything is updated, somtimes apps needs a second run)
sudo -u www-data php $OCPATH/occ upgrade
# Enable Apps
sudo -u www-data php $OCPATH/occ app:enable calendar
sudo -u www-data php $OCPATH/occ app:enable contacts
sudo -u www-data php $OCPATH/occ app:enable documents
sudo -u www-data php $OCPATH/occ app:enable external

# Disable maintenance mode
sudo -u www-data php $OCPATH/occ maintenance:mode --off

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if grep -Fxq "$VALUE" $OCPATH/.htaccess
then
        echo "Value correct"
else
        sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 513M/g' $OCPATH/.htaccess
        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 513M/g' $OCPATH/.htaccess
        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' $OCPATH/.htaccess
fi

# Set secure permissions
FILE="/var/scripts/setup_secure_permissions_owncloud.sh"
if [ -f $FILE ];
then
        echo "Script exists"
else
        mkdir -p /var/scripts
        wget https://raw.githubusercontent.com/owncloud/vm/master/ATTIC/enoch85-testing/ubuntu/setup_secure_permissions_owncloud.sh -P /var/scripts/
fi
sudo bash /var/scripts/setup_secure_permissions_owncloud.sh

# Repair
sudo -u www-data php $OCPATH/occ maintenance:repair

# Cleanup un-used packages
sudo apt-get autoremove -y
sudo apt-get autoclean

# Update GRUB, just in case
sudo update-grub

# Write to log
touch /var/log/cronjobs_success.log
echo "OWNCLOUD UPDATE success-`date +"%Y%m%d"`" >> /var/log/cronjobs_success.log
echo
echo ownCloud version:
sudo -u www-data php $OCPATH/occ status
echo
echo

## Un-hash this if you want the system to reboot
# sudo reboot

exit 0
