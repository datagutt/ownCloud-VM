#!bin/bash

# Tech and Me - www.techandme.se - 2015-2016

SCRIPTS=/var/scripts

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Check if dir exists
if [ -d $SCRIPTS ];
then sleep 1
else mkdir $SCRIPTS
fi

# Get packages to be able to install Redis
apt-get update && sudo apt-get install build-essential -q -y
apt-get install tcl8.5 -q -y
apt-get install php-pear php5-dev -q -y

# Get latest Redis
wget -q http://download.redis.io/releases/redis-stable.tar.gz && tar -xzf redis-stable.tar.gz -P $SCRIPTS
mv $SCRIPTS/redis-stable $SCRIPTS/redis

# Test Redis
cd $SCRIPTS/redis && make && make test
if [[ $? > 0 ]]
then
    echo "Test failed."
    sleep 5
    exit 1
else
		echo -e "\e[32m"
    echo "Redis test OK!"
    echo -e "\e[0m"
fi

# Install Redis
make install
cd utils && yes "" | sudo ./install_server.sh 
if [[ $? > 0 ]]
then
    echo "Installation failed."
    sleep 5
    exit 1
else
                echo -e "\e[32m"
    echo "Redis installation OK!"
    echo -e "\e[0m"
fi

# Remove installation package
rm -rf $SCRIPTS/redis
rm -rf $SCRIPTS/redis-stable.tar.gz

# Install Git and clone repo
apt-get install git -y -q
git clone -b php7 https://github.com/phpredis/phpredis.git

# Build Redis PHP module
apt-get install php7.0-dev -y -q
mv phpredis/ /etc/ && cd /etc/phpredis
phpize
./configure
make && make install
echo 'extension=redis.so' >> /etc/php/7.0/apache2/php.ini
phpenmod redis
service apache2 restart
cd ..
rm -rf phpredis

# Prepare for adding redis configuration
sed -i "s|);||g" /var/www/html/owncloud/config/config.php

# Add the needed config to ownClouds config.php
cat <<ADD_TO_CONFIG>> /var/www/html/owncloud/config/config.php
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'filelocking.enabled' => 'true',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' =>
  array (
  'host' => 'localhost',
  'port' => 6379,
  'timeout' => 0,
  'dbindex' => 0,
  ),
);
ADD_TO_CONFIG

# Cleanup
apt-get purge git -y

exit 0
