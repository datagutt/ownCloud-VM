#!bin/bash

Tech and me 2015 - www.en0ch.se

clear

cat << EOMSTART
+---------------------------------------------------------------+
|       Important! Please read this!                            |
|                                                               |
|       This script will install SSL from Let's Encrypt.        |
|       It's free of charge, and very easy to use.              |
|                                                               |
|       Before we begin the installation you need to have       |
|       a domain that the SSL certs will be vaild for.          |
|       If you don't have a domian yet, get one before          |
|       you run this script!                                    |
|                                                               |
|       This script is located in /var/scripts and you          |
|       can run this script after you got a domain.             |
|                                                               |
|       Please don't run this script if you don't have		|
|       a domian yet. You can get one for a fair price here:	|
|       https://www.citysites.eu/                               |
|                                                               |
+---------------------------------------------------------------+

EOMSTART

function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

if [[ "no" == $(ask_yes_or_no "Are you sure you want to continue?") || \
      "no" == $(ask_yes_or_no "Do you know how to configure a Virtual Host in Apache?") || \
      "no" == $(ask_yes_or_no "Do you have a domian that you will use?") ]]
then
    echo
    echo "OK, but if you want to run this script later, just type: bash /var/scripts/activate-ssl.sh"
    echo -e "\e[32m"
    read -p "Press any key to continue... " -n1 -s
    echo -e "\e[0m"
    exit 0
fi

# Install git
git --version 2>&1 >/dev/null
GIT_IS_AVAILABLE=$?
# ...
if [ $GIT_IS_AVAILABLE -eq 0 ]; then
apt-get install git -y
fi

# Ask for domain name
echo
echo "Please enter the domain name you will use for ownCloud:"
echo "Like this: example.com, or owncloud.example.com (1/2)"
echo
read domain


function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

if [[ "no" == $(ask_yes_or_no "Is this correct? $domain") ]]
then
    echo
    echo "OK, try again: (2/2, last try)"
    echo "Please enter the domain name you will use for ownCloud:"
    echo -e
    read domain
    echo
fi

# Generate owncloud_ssl_domain.conf

FILE="/etc/apache2/sites-available/owncloud_ssl_domain.conf"
if [ -f $FILE ];
then
        echo "Virtual Host exists"
else
ssl_conf="/etc/apache2/sites-available/owncloud_ssl_domain.conf"
set -x
touch $ssl_conf
cat << SSL_CREATE > "$ssl_conf"
<VirtualHost *:443>

    Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"
    SSLEngine on

### YOUR SERVER ADDRESS ###

    ServerAdmin admin@$domain
    ServerName $domain

### SETTINGS ###

    DocumentRoot /var/www/html/owncloud
    <Directory /var/www/html/owncloud>

    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    </Directory>


### LOCATION OF CERT FILES ###

    SSLCertificateChainFile $letsencryptpath/live/$domain/chain.pem
    SSLCertificateFile $letsencryptpath/live/$domain/cert.pem
    SSLCertificateKeyFile $letsencryptpath/live/$domain/privkey.pem

</VirtualHost>
SSL_CREATE
fi

# Check if $letsencryptpath exist, and if, then delete.
DIRECTORY=$letsencryptpath
if [ -d "$DIRECTORY" ]; then
  rm -R $DIRECTORY
fi

# Generate certs
cd /opt
git clone https://github.com/letsencrypt/letsencrypt
cd $letsencryptpath
./letsencrypt-auto -d $domain

# Use for testing
#./letsencrypt-auto --apache --server https://acme-staging.api.letsencrypt.org/directory -d EXAMPLE.COM

# Check if $letsencrypt/live exists
DIRECTORY2=$letsencryptpath/live
if [ -d "$DIRECTORY2" ]; then

# Activate new config
	bash /var/scripts/test-new-config.sh
else
	echo -e "\e[96m"
	echo -e "It seems like no certs were generated, we do three more tries."
	echo -e "\e[32m"
	read -p "Press any key to continue... " -n1 -s
	echo -e "\e[0m"
	rm -R $DIRECTORY
	cd /opt
	git clone https://github.com/letsencrypt/letsencrypt
	cd $letsencryptpath
	./letsencrypt-auto --agree-tos --webroot -w /var/www/html/owncloud -d $domain
fi

# Check if $letsencryptpath/live exists
if [ -d "$DIRECTORY2" ]; then

# Activate new config
	bash /var/scripts/test-new-config.sh
else
        echo -e "\e[96m"
        echo -e "It seems like no certs were generated, we do two more tries."
        echo -e "\e[32m"
        read -p "Press any key to continue... " -n1 -s
        echo -e "\e[0m"
# Stop Apache to aviod port conflicts
	a2dissite 000-default.conf
	sudo service apache2 stop
	rm -R $DIRECTORY
        cd /opt
        git clone https://github.com/letsencrypt/letsencrypt
        cd $letsencryptpath
        ./letsencrypt-auto certonly --standalone -d $domain
fi
# Activate Apache again (Disabled during standalone)
	service apache2 start
        a2ensite 000-default.conf
        service apache2 reload

# Check if $letsencryptpath/live exists
if [ -d "$DIRECTORY2" ]; then

# Activate new config
        bash /var/scripts/test-new-config.sh
else
        echo -e "\e[96m"
        echo -e "It seems like no certs were generated, we do one more try."
        echo -e "\e[32m"
        read -p "Press any key to continue... " -n1 -s
        echo -e "\e[0m"
        rm -R $DIRECTORY
        cd /opt
        git clone https://github.com/letsencrypt/letsencrypt
        cd $letsencryptpath
        ./letsencrypt-auto --agree-tos --apache -d $domain
fi

# Check if $letsencryptpath/live exists
if [ -d "$DIRECTORY2" ]; then
# Activate new config
        bash /var/scripts/test-new-config.sh
else
	echo -e "\e[96m"
	echo -e "Nope, not this time either. Please try again some other time."
        echo -e "The script is located in /var/scripts/ and the name is: activate-ssl.conf"
	echo -e "There are different configs you can try in Let's Encrypts user guide."
	echo -e "Visit https://letsencrypt.readthedocs.org/en/latest/index.html for more detailed info"
	echo -e "\e[32m"
        read -p "Press any key to continue... " -n1 -s
        echo -e "\e[0m"

# Cleanup
rm -R $DIRECTORY
rm /etc/apache2/sites-available/owncloud_ssl_domain.conf
fi

exit 0
