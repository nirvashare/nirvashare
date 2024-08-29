#!/bin/bash

DB_PASS_FILE=/var/nirvashare/dbpass

terminate()
{
    echo ""
    echo "Installation terminated"
    exit 0
}



echo ""
echo "NirvaShare Software Installation."
echo ""




echo "This utility will install NirvaShare WebDav service."
echo ""
while true; do
    read -p "Do you want to continue? (y/n)? " yn
    case $yn in
        [Yy] ) break;;
        [Nn] ) terminate; exit;;
        * ) echo "Please answer yes or no (y/n).";;
    esac
done


if [ -ne /var/nirvashare/install-app.yml ]
then
    echo
    echo "Please install other required NirvaShare services."
    terminate

fi

if [ -e /var/nirvashare/install-webdav.yml ]
then
    echo
    echo "WebDav service is already installed in this system."
    terminate

fi



# docker-compose


sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# NirvaShare installation


sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-webdav.yml" -o /var/nirvashare/install-webdav.yml

export COMPOSE_IGNORE_ORPHANS=true
docker-compose -f /var/nirvashare/install-webdav.yml up -d

echo ""
echo "Installation Completed."

