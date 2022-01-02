#!/usr/bin/env bash
# Bash script for Minecraft server env configuration.

#set -o errexit
#set -o pipefail
#set -o nounset


SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi

if [[ $# -eq 0 ]] ;
then
  read -p 'new user: ' USER
  read -p 'file dir: ' DIR
  read -p 'server port: ' S_PORT
  read -p 'Rcon port: ' R_PORT
  read -p 'Xmx : ' RAM_MAX
  read -p 'Xms : ' RAM_MIN
  read -p 'rcon path: ' PATH_RCON
else
  if [[ $# -eq 7 ]] ;
  then
    USER=$1
    DIR=$2
    S_PORT=$3
    R_PORT=$4
    RAM_MAX=$5
    RAM_MIN=$6
    PATH_RCON=$7
  else
    echo "incorrect parms: <new user> <file dir> <server_p> <rcon_p> <XMX> <xms> <rcon_path>"
    exit 1
  fi
fi

echo "Checking Java..."

if ! command -v java --version &> /dev/null
then
    echo "Java not installed. Please install the correct version of java for your server"
    exit 1
else
    JAVA_VER=$(java -version 2>&1 >/dev/null | egrep "\S+\s+version")
    echo "java ver: ${JAVA_VER}"
fi

check_installation () {
  dpkg -s $1 &> /dev/null

if [ $? -ne 0 ]

    then
        read -p "$1 not installed. do u want install? (yes/no): " REQ
        if [[ $REQ -eq "yes" ]] ;
        then
          $SUDO apt-get update
          $SUDO apt-get install $1
        fi
    else
        echo    "$1 installed"
fi
}


echo "Checking Git..."
check_installation "git"
echo "Checking build-essential..."
check_installation "build-essential"
echo "Checking gcc..."
check_installation "gcc"


echo "Creating new user..."
$SUDO useradd -r -m -U -d $DIR$USER -s /bin/bash $USER



$SUDO -H -u $USER bash -c "mkdir -p $DIR$USER/{backups,tools,server}"



echo "creating backup script..."

SCRPT_BACKUP="#!/bin/bash\n
\n
function rcon {\n
\t$PATH_RCON -H 127.0.0.1 -P $R_PORT -p $USER\n
}\n
\n
rcon \"save-off\" \n
rcon \"save-all\"\n
tar -cvpzf $DIR$USER/backups/server-\$(date +%F-%H-%M).tar.gz $DIR$USER/server\n
rcon \"save-on\"\n
\n
## Delete older backups\n
find $DIR$USER/backups/ -type f -mtime +7 -name '*.gz' -delete\n
"

echo -e $SCRPT_BACKUP>>tmp_file_back
TMP=$(cat tmp_file_back)
$SUDO -u $USER bash -c "cp tmp_file_back $DIR$USER/tools/backup.sh"
rm tmp_file_back
$SUDO -H -u $USER  bash -c "chmod +x $DIR$USER/tools/backup.sh"

echo "crontab backup configuration..."
$SUDO -H -u $USER  bash -c "(crontab -l 2>/dev/null; echo \"0 23 * * * $DIR$USER/tools/backup.sh\") | crontab -"



echo "Service configuration..."

SCRIPT_SERVICE="[Unit]\n
Description=Minecraft Server by $USER\n
After=network.target\n
\n
[Service]\n
User=$USER\n
Nice=1\n
KillMode=none\n
SuccessExitStatus=0 1\n
ProtectHome=true\n
ProtectSystem=full\n
PrivateDevices=true\n
NoNewPrivileges=true\n
WorkingDirectory=$DIR$USER/server\n
ExecStart=/usr/bin/java -Xmx$RAM_MAX -Xms$RAM_MIN -jar server.jar nogui\n
ExecStop=$PATH_RCON -H 127.0.0.1 -P $R_PORT -p $USER stop\n
\n
Restart=always\n
[Install]\n
WantedBy=multi-user.target\n
"

echo -e $SCRIPT_SERVICE>>tmp_file_service
TMP=$(cat tmp_file_service)

$SUDO cp tmp_file_service /etc/systemd/system/$USER.service
rm tmp_file_service
$SUDO systemctl daemon-reload
$SUDO systemctl start $USER
$SUDO systemctl enable $USER


echo "Setting up EULA file..."
EULA="eula=true"
$SUDO -H -u $USER bash -c "echo $EULA >> $DIR$USER/server/eula.txt"

echo "Setting up server.properties file..."

PROPERTIES="rcon.port=$R_PORT\n
rcon.password=$USER\n
enable-rcon=true\n
"
echo -e $PROPERTIES>tmp_prop
TMP=$(cat tmp_prop)
$SUDO -u $USER bash -c "cp tmp_prop $DIR$USER/server/server.properties"
rm tmp_prop
