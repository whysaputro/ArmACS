#!/bin/bash

echo "Uninstalling GenieACS..."

for s in cwmp nbi fs ui; do
    systemctl stop genieacs-$s 2>/dev/null
    systemctl disable genieacs-$s 2>/dev/null
    rm -f /etc/systemd/system/genieacs-$s.service
done

systemctl daemon-reload

rm -rf /opt/genieacs
rm -rf /var/log/genieacs
rm -f /etc/logrotate.d/genieacs
userdel -r genieacs 2>/dev/null

apt-get purge -y mongodb-org nodejs npm
apt-get autoremove -y
apt-get clean

echo "GenieACS and dependencies removed."