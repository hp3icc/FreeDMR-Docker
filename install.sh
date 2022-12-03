#!/bin/bash
#
###############################################################################
# Copyright (C) 2020 Simon Adlem, G7RZU <g7rzu@gb7fr.org.uk>  
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software Foundation,
#   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
###############################################################################

echo FreeDMR Docker installer...

echo Installing required packages...
echo Install Docker Community Edition...
apt-get -y remove docker docker-engine docker.io &&
apt-get -y update &&
apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common &&
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - &&
ARCH=`/usr/bin/arch`
echo "System architecture is $ARCH" 
if [ "$ARCH" == "x86_64" ]
then
    ARCH="amd64"
fi
add-apt-repository \
   "deb [arch=$ARCH] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" &&
apt-get -y update &&
apt-get -y install docker-ce &&

echo Install Docker Compose...
apt-get -y install docker-compose &&

echo Set userland-proxy to false...
cat <<EOF > /etc/docker/daemon.json &&
{
     "userland-proxy": false,
     "experimental": true,
     "log-driver": "json-file",
     "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      }
}
EOF

echo Restart docker...
systemctl restart docker &&

echo Make config directory...
mkdir /etc/freedmr &&
mkdir -p /etc/freedmr/acme.sh && 
mkdir -p /etc/freedmr/certs &&
chmod -R 755 /etc/freedmr &&

echo make json directory...
mkdir -p /etc/freedmr/json &&
chown 54000:54000 /etc/freedmr/json &&

echo Install /etc/freedmr/freedmr.cfg ... 
cat << EOF > /etc/freedmr/freedmr.cfg
[GLOBAL]
PATH: ./
PING_TIME: 10
MAX_MISSED: 3
USE_ACL: True
REG_ACL: DENY:0-100000
SUB_ACL: DENY:0-100000
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
GEN_STAT_BRIDGES: True
ALLOW_NULL_PASSPHRASE: True
ANNOUNCEMENT_LANGUAGES:
SERVER_ID: 0
DATA_GATEWAY: False
VALIDATE_SERVER_IDS: False


[REPORTS]
REPORT: True
REPORT_INTERVAL: 60
REPORT_PORT: 4321
REPORT_CLIENTS: *

[LOGGER]
LOG_FILE: /dev/null
LOG_HANDLERS: console-timed
LOG_LEVEL: INFO
LOG_NAME: FreeDMR

[ALIASES]
TRY_DOWNLOAD: True
PATH: ./json/
PEER_FILE: peer_ids.json
SUBSCRIBER_FILE: subscriber_ids.json
TGID_FILE: talkgroup_ids.json
PEER_URL: http://freedmr-lh.gb7fr.org.uk/json/peer_ids.json
SUBSCRIBER_URL: http://freedmr-lh.gb7fr.org.uk/json/subscriber_ids.json
TGID_URL: http://freedmr-lh.gb7fr.org.uk/json/talkgroup_ids.json
LOCAL_SUBSCRIBER_FILE: local_subscriber_ids.json
STALE_DAYS: 1
SUB_MAP_FILE: sub_map.pkl
SERVER_ID_URL: http://freedmr-lh.gb7fr.org.uk/json/server_ids.tsv
SERVER_ID_FILE: server_ids.tsv
TOPO_FILE: topography.json


#Control server shared allstar instance via dial / AMI
[ALLSTAR]
ENABLED: false
USER:admin
PASS: password
SERVER: asl.example.com
PORT: 5038
NODE: 11111

[OBP-TEST]
MODE: OPENBRIDGE
ENABLED: False
IP:
PORT: 62044
NETWORK_ID: 1
PASSPHRASE: mypass
TARGET_IP: 
TARGET_PORT: 62044
USE_ACL: True
SUB_ACL: DENY:1
TGID_ACL: PERMIT:ALL
RELAX_CHECKS: True
ENHANCED_OBP: True
PROTO_VER: 2


[SYSTEM]
MODE: MASTER
ENABLED: True
REPEAT: True
MAX_PEERS: 1
EXPORT_AMBE: False
IP: 
#127.0.0.1
PORT: 54000
PASSPHRASE:
GROUP_HANGTIME: 5
USE_ACL: True
REG_ACL: DENY:1
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
DEFAULT_UA_TIMER: 10
SINGLE_MODE: True
VOICE_IDENT: False
TS1_STATIC:
TS2_STATIC:
DEFAULT_REFLECTOR: 0
ANNOUNCEMENT_LANGUAGE: es_ES
GENERATOR: 100
ALLOW_UNREG_ID: False
PROXY_CONTROL: True
OVERRIDE_IDENT_TG:

[ECHO]
MODE: PEER
ENABLED: True
LOOSE: False
EXPORT_AMBE: False
IP: 127.0.0.1
PORT: 54916
MASTER_IP: 127.0.0.1
MASTER_PORT: 54915
PASSPHRASE: passw0rd
CALLSIGN: ECHO
RADIO_ID: 1000001
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 00.0000
LONGITUDE: 000.0000
HEIGHT: 0
LOCATION: Earth
DESCRIPTION: ECHO
URL: www.freedmr.uk
SOFTWARE_ID: 20170620
PACKAGE_ID: MMDVM_FreeDMR
GROUP_HANGTIME: 5
OPTIONS:
USE_ACL: True
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
ANNOUNCEMENT_LANGUAGE: en_GB
EOF

echo Install rules.py ...
sudo cat > /etc/freedmr/rules.py  <<- "EOF"
BRIDGES = {
 '9990': [ 
	{'SYSTEM': 'ECHO', 		'TS': 2, 'TGID': 9990, 'ACTIVE':True, 'TIMEOUT': 0, 'TO_TYPE': 'NONE', 'ON': [], 'OFF': [], 'RESET': []}, 
	],



}

if __name__ == '__main__':
    from pprint import pprint
    pprint(BRIDGES)
EOF

echo Set perms on config directory...
chown -R 54000 /etc/freedmr &&

echo Get docker-compose.yml...
cd /etc/freedmr &&
curl https://gitlab.hacknix.net/hacknix/FreeDMR/-/raw/master/docker-configs/docker-compose.yml -o docker-compose.yml &&
##########
sudo sed -i "s/62031/54000-54100/g"  docker-compose.yml
#########################################################

apt install python3 python3-pip -y
mkdir /etc/freedmr/proxy2

wget /etc/freedmr/proxy2/hotspot_proxy_v2.py https://raw.githubusercontent.com/yuvelq/FDMR-Monitor/Self_Service/proxy/hotspot_proxy_v2.py -O

wget /etc/freedmr/proxy2/proxy.cfg https://raw.githubusercontent.com/yuvelq/FDMR-Monitor/Self_Service/proxy/proxy.cfg -O

wget /etc/freedmr/proxy2/proxy_db.py https://raw.githubusercontent.com/yuvelq/FDMR-Monitor/Self_Service/proxy/proxy_db.py -O
chmod +x *
sudo cat > /etc/freedmr/proxy2/requirements.txt <<- "EOF"
setproctitle
Twisted
dmr_utils3

EOF
pip3 install -r /etc/freedmr/proxy2/requirements.txt
sudo sed -i "s/MASTER = 127.0.0.1/MASTER = 172.16.238.10/g"  /etc/freedmr/proxy2/proxy.cfg 
sudo sed -i "s/USE_SELFSERVICE = True/USE_SELFSERVICE = False/g"  /etc/freedmr/proxy2/proxy.cfg 
     
sudo cat > /lib/systemd/system/proxy2.service <<- "EOF"
[Unit]
Description= Proxy Service 
After=multi-user.target

[Service]
User=root
Type=simple
Restart=always
RestartSec=3
StandardOutput=null
ExecStart=/usr/bin/python3 /etc/freedmr/proxy2/hotspot_proxy_v2.py -c /etc/freedmr/proxy2/proxy.cfg

[Install]
WantedBy=multi-user.target
EOF
#
cat > /bin/menu <<- "EOF"
#!/bin/bash
while : ; do
choix=$(whiptail --title "Raspbian Proyect HP3ICC EasyFreeDMR Docker Version" --menu "move up or down with the keyboard arrows and select your option by pressing enter:" 17 56 8 \
1 " Edit FreeDMR Server " \
2 " Edit Interlink  " \
3 " Start & Restart FreeDMR Server  " \
4 " Stop FreeDMR Server " \
5 " update " 3>&1 1>&2 2>&3)
exitstatus=$?
#on recupere ce choix
#exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your chosen option:" $choix
else
    echo "You chose cancel."; break;
fi
# case : action en fonction du choix
case $choix in
1)
nano /etc/freedmr/freedmr.cfg ;;
2)
nano /etc/freedmr/rules.py ;;
3)
start-fdmr ;;
4)
stop-fdmr ;;
5)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/hp3icc/Easy-FreeDMR-Docker/main/update.sh)";
esac
done
exit 0
EOF
###############################################
cat > /bin/start-fdmr <<- "EOF"
#!/bin/bash
cd /etc/freedmr
docker-compose down
docker-compose up -d

EOF
#
cat > /bin/stop-fdmr <<- "EOF"
#!/bin/bash
cd /etc/freedmr
docker-compose down

EOF
###############################################
cp /bin/menu /bin/MENU
chmod +x /bin/menu*
chmod +x /bin/MENU
chmod +x /bin/start-fdmr
chmod +x /bin/stop-fdmr

systemctl daemon-reload
systemctl start proxy2.service
systemctl enable proxy2.service

#########################################################

chmod 755 /etc/cron.daily/lastheard

echo Tune network stack...
cat << EOF > /etc/sysctl.conf &&
net.core.rmem_default=134217728
net.core.rmem_max=134217728
net.core.wmem_max=134217728                       
net.core.rmem_default=134217728
net.core.netdev_max_backlog=250000
net.netfilter.nf_conntrack_udp_timeout=15
net.netfilter.nf_conntrack_udp_timeout_stream=35
EOF

/usr/sbin/sysctl -p &&

echo Run FreeDMR container...
docker-compose up -d

echo Read notes in /etc/freedmr/docker-compose.yml to understand how to implement extra functionality.
echo FreeDMR setup complete!
history -c && history -w
menu
