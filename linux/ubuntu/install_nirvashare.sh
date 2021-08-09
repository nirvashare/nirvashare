#!/bin/bash

echo "NS_DBPASSWORD = $NS_DBPASSWORD"


if [ -z "$NS_DBPASSWORD" ]
then
while true; do
  read -s -p "Enter database password: " NS_DBPASSWORD
  echo
  read -s -p "Confirm database password: " NS_DBPASSWORD2
  echo
  [ "$password" = "$password2" ] && break
  echo "Passwords not matching, please re-enter"
done

fi



exit 0

# stack script

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


echo "version: '3'
services:
  admin:
    image: nirvato/nirvashare-admin:latest
    container_name: nirvashare_admin
    networks:
      - nirvashare
    restart: always
    ports:
#      # Public HTTP Port:
      - 8080:8080
    environment:
      ns_db_jdbc_url: 'jdbc:postgresql://nirvashare_database:5432/postgres'
      ns_db_username: 'nirvashare'
      ns_db_password: '$NS_DBPASSWORD'
     
    depends_on:
      - db


  userapp:
    image: nirvato/nirvashare-userapp:latest
    container_name: nirvashare_userapp
    networks:
      - nirvashare
    restart: always
    ports:
#      # Public HTTP Port:
      - 8081:8080
    environment:
      ns_db_jdbc_url: 'jdbc:postgresql://nirvashare_database:5432/postgres'
      ns_db_username: 'nirvashare'
      ns_db_password: '$NS_DBPASSWORD'
      
    depends_on:
      - admin

  db:
   image: postgres:latest
   networks:
      - nirvashare
   container_name: nirvashare_database
   restart: always
#   ports:
#        - 5432:5432
   environment: 
     POSTGRES_PASSWORD: '$NS_DBPASSWORD'
     POSTGRES_USER: 'nirvashare'

networks:
  nirvashare: {}
"  > /var/nirvashare/install-app.yml


docker-compose -f /var/nirvashare/install-app.yml up -d


