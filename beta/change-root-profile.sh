#!/bin/bash

ROOT_PROFILE="/root/.bash_profile"

rm /root/.profile

cat <<-ROOT-PROFILE > "$ROOT_PROFILE"

# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

if [ -x /var/scripts/owncloud_install.sh ]; then
        /var/scripts/owncloud_install.sh
fi

if [ -x /var/scripts/history.sh ]; then
        /var/scripts/history.sh
fi

mesg n

ROOT-PROFILE
