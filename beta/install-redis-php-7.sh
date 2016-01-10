#!bin/bash

# Tech and Me - www.techandme.se - 2015-2016

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Install Redis Server
apt-get update
apt-get install redis-server -y -q

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
