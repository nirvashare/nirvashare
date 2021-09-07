#!/bin/bash

echo ""
echo "Starting to install NirvaShare application."
echo ""


if [ -z "$NS_DBPASSWORD" ]
then
while true; do
  read -s -p "Enter database password: " NS_DBPASSWORD
  echo
  read -s -p "Confirm database password: " NS_DBPASSWORD2
  echo
  [ "$NS_DBPASSWORD" = "$NS_DBPASSWORD2" ] && break
  echo "Passwords not matching, please re-enter"
done

fi


sudo apt update
# docker

sudo apt install -yq apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update

apt-cache policy docker-ce

sudo apt install -yq docker-ce

# docker-compose

sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# NirvaShare installation

mkdir -p /var/nirvashare
sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install_file

cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_DBPASSWORD/" >> /var/nirvashare/install-app.yml

docker-compose -f /var/nirvashare/install-app.yml up -d



