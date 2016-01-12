# ownCloud-VM
**Scripts to setup and configure the ownCloud VM**

### DOWNLOAD THE VM

You can find all the VMs [here](https://www.techandme.se/pre-configured-owncloud-installaton/). Feel free to contribute!

### HOW TO SETUP THE BETA VM

- Create a clean Ubuntu Server 14.04 VM with VMware Workstation or VirtualBox
- Edit rc.local likes this:

```
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

# Get a fresh RC.LOCAL
    if [ -f /var/rc.local ];
    then
        echo "rc.local exists"
    else
        wget https://raw.githubusercontent.com/enoch85/ownCloud-VM/master/beta/rc.local -P /var/
        cat /var/rc.local > /etc/rc.local
        rm -rf /var/rc.local
        reboot
    fi

exit 0
```
- Reboot

### TEST A LIVE VERSION

You can test the VM [here](https://owncloudphp7.techandme.se/).
- User: testuser
- Pass: testingphp7

Please note that if you get an internal server error, it's becuase the user gets deleted every hour. Just press F5 and reload the page in that case.
