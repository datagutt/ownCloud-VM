#!bin/bash

# Tech and Me - www.techandme.se - ©2016

SCRIPTS=/var/scripts
OCPATH=/var/www/owncloud

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
apt-get install php-pear php7.0-dev -q -y

# Install Git and clone repo
apt-get install git -y -q
git clone -b php7 https://github.com/phpredis/phpredis.git

# Build Redis PHP module
sudo mv phpredis/ /etc/ && cd /etc/phpredis
phpize
./configure
make && make install
if [[ $? > 0 ]]
then
    echo "PHP module installation failed"
    sleep 5
    exit 1
else
		echo -e "\e[32m"
    echo "PHP module installation OK!"
    echo -e "\e[0m"
fi
touch /etc/php/7.0/mods-available/redis.ini
echo 'extension=redis.so' > /etc/php/7.0/mods-available/redis.ini
phpenmod redis
service apache2 restart
cd ..
rm -rf phpredis

# Get latest Redis
wget -q http://download.redis.io/releases/redis-stable.tar.gz -P $SCRIPTS && tar -xzf $SCRIPTS/redis-stable.tar.gz -C $SCRIPTS
mv $SCRIPTS/redis-stable $SCRIPTS/redis

# Test Redis
cd $SCRIPTS/redis && make
# Check if taskset need to be run
grep -c ^processor /proc/cpuinfo > /tmp/cpu.txt
if grep -Fxq "1" /tmp/cpu.txt
then echo "Not running taskset"
make test
else echo "Running taskset limit to 1 proccessor"
taskset -c 1 make test
rm /tmp/cpu.txt
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
rm $SCRIPTS/redis-stable.tar.gz

# Prepare for adding redis configuration
sed -i "s|);||g" $OCPATH/config/config.php

# Add the needed config to ownClouds config.php
cat <<ADD_TO_CONFIG>> $OCPATH/config/config.php
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
apt-get purge -y \
	git \
	php7.0-dev \
	binutils \
	build-essential \
	cpp \
	cpp-4.8 \
	dpkg-dev \
	fakeroot \
	g++ \
	g++-4.8 \
	gcc \
	gcc-4.8 \
	libalgorithm-diff-perl \
	libalgorithm-diff-xs-perl \
	libalgorithm-merge-perl \
	libasan0 \
	libatomic1 \
	libc-dev-bin \
	libc6-dev \
	libcloog-isl4 \
	libdpkg-perl \
	libfakeroot \
	libfile-fcntllock-perl \
	libgcc-4.8-dev \
	libgmp10 libgomp1 \
	libisl10 \
	libitm1 \
	libmpc3 \
	libmpfr4 \
	libquadmath0 \
	libstdc++-4.8-dev \
	libtsan0 \
	linux-libc-dev \
	make \
	manpages-dev

apt-get update
apt-get autoremove -y
apt-get autoclean

exit 0
