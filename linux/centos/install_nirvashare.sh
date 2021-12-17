#!/bin/bash

echo ""
echo "Starting to install NirvaShare application."
echo "For CentOS."
echo ""


if [ "$NS_RANDOM_PASSWORD" = "true" ]
then
        echo "Generating a random database password"
        NS_DBPASSWORD=$(openssl rand -hex 6)
fi


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


#yum -y update
# docker
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum -y install yum-utils device-mapper-persistent-data lvm2
yum -y install docker-ce -y

mkdir -p /etc/systemd/system/docker.service.d
touch /etc/systemd/system/docker.service.d/docker.conf
mkdir -p /etc/docker


systemctl start docker

systemctl enable docker

echo
systemctl status docker
echo
journalctl -u docker --no-pager
echo
docker info


# docker-compose

sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# NirvaShare installation

mkdir -p /var/nirvashare
sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install_file

cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_DBPASSWORD/" >> /var/nirvashare/install-app.yml

docker-compose -f /var/nirvashare/install-app.yml up -d



