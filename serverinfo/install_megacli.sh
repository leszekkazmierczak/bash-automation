#!/bin/bash
apt update
apt install alien curl

cd /tmp
wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/8-07-14_MegaCLI.zip

unzip 8-07-14_MegaCLI.zip

cd Linux

alien MegaCli-8.07.14-1.noarch.rpm  
dpkg -i megacli_8.07.14-2_all.deb

update-alternatives --install '/usr/sbin/megacli' 'megacli' '/opt/MegaRAID/MegaCli/MegaCli64' 1
