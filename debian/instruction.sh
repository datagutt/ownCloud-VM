#!/bin/bash
#
clear

# save for later:
#export FILENAME=/var/important_passwords.txt
#export PASSWORD=$(grep -v 'MYSQL' $FILENAME;)

cat << INST1
+-----------------------------------------------------------------------+
| Thank you for downloading this ownCloud VM made by Tech and Me!       |
|                                                                       |
INST1
echo -e "|"  "\e[32mTo run the startup script, just type the root password:\e[0m                |"
echo -e "|"  "\e[36mowncloud\e[32m or the password that was set during install.\e[0m                    |"
cat << INST2
|                                                                       |
| If you never done this before you can follow the complete             |
| install instructions: https://goo.gl/3FYtz6                           |
|                                                                       |
| You can also set the ownCloud update process as a cronjob.            |
| This is made thru the built in script in this VM that                 |
| updates ownCloud, set secure permissions, and then                    |
| logs the successful update in /var/log/cronjobs_success.log           |
| Here is a guide on how to set it up:                                  |
| https://www.techandme.se/set-automatic-owncloud-updates/              |
|                                                                       |
|  ####################### Tech and Me - 2016 ########################  |
+-----------------------------------------------------------------------+
INST2

exit 0

