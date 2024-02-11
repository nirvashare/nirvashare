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




echo "This utility will install NirvaShare FTPS service."
echo ""
while true; do
    read -p "Do you want to continue? (y/n)? " yn
    case $yn in
        [Yy] ) break;;
        [Nn] ) terminate; exit;;
        * ) echo "Please answer yes or no (y/n).";;
    esac
done


if [ ! -e /var/nirvashare/install-app.yml ]
then

	while true; do
	  read -s -p "Enter database password: " NS_DBPASSWORD
	  echo
	  read -s -p "Confirm database password: " NS_DBPASSWORD2
	  echo
	  size=${#NS_DBPASSWORD}
	  
	  if [ "${size}" -lt "6"  ] 
	  then 
	       echo "Password length should be atleast 6 characters."
	  elif   [ "$NS_DBPASSWORD" != "$NS_DBPASSWORD2"   ] 
	  then 
	       echo "Passwords not matching, please re-enter"
	   else 
	   break

	   fi	  
	  
	done
	
	mkdir -p /var/nirvashare
	create_pass_file


fi



if [ -e /var/nirvashare/install-app.yml ]
then
    echo
    echo "NirvaShare is already installed in this system."
    terminate

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


sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# NirvaShare installation


sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-ftps.yml" -o /var/nirvashare/install-ftps.yml


docker-compose -f /var/nirvashare/install-ftps.yml up -d

echo ""
echo "Installation Completed."

