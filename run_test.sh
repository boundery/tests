#!/bin/bash

#Sanity checks
if [ -z "$1" ]; then
    echo "Usage: $0 zipname" >&2
    exit 99
fi

if ps ax | grep -q '[B]oundery Client'; then
    echo "Client already running!" >&2
    exit 90
fi
if ps ax | grep -q '[t]est_client.py'; then
    echo "Tester already running!" >&2
    exit 91
fi

#XXX Verify that OS image exists on server.

#Prep
if mount | grep -q ^/dev/sdb1; then
    echo "/dev/sdb1 already mounted!" >&2
    exit 92
fi
sudo mount -o umask=000 /dev/sdb1 /mnt

set -m #Enable job control

#Enable no-prompt priv escalation
sudo tee /etc/polkit-1/localauthority/50-local.d/99-no-password.pkla > /dev/null <<EOF
[Allow group sudo to skip password]
Identity=unix-group:sudo
Action=*
ResultAny=yes
EOF
sudo systemctl restart polkit.service

#Setup test environment and run tests.
kill -9 `pidof chromedriver` `pidof Xvfb` 2>/dev/null
Xvfb &> .xvfb.log &
sleep 1
DISPLAY=:0 x11vnc -forever -shared &> .x11vnc.log &

#Get rid of client state from previous runs
rm -rf .local/share/boundery

DISPLAY=:0 python3 /vagrant/test_client.py &
while ! ss -tln | grep -q ':9999'; do
    sleep 1
done

ZIPFILE_NAME="$1" BROWSER=/vagrant/fake_browser.sh boundery-linux-client/Boundery\ Client &

fg %3 #tester
jobs
kill -9 %4 #client
kill -9 %2 #x11vnc
kill -9 %1 #Xvfb
