#!/bin/bash

#
# CentOS installation script
#

DB_PASS_FILE=/var/nirvashare/dbpass

terminate()
{
    echo ""
    echo "Installation terminated"
    exit 0
}


create_pass_file()
{

    if [ -f "$DB_PASS_FILE" ]; then
    	echo "Password file already exists"
    	terminate; exit;
    else 
    	# create the password file
        echo $NS_DBPASSWORD > ${DB_PASS_FILE}    
    fi
}


echo ""
echo "NirvaShare Software Installation."
echo ""


if [ "$NS_RANDOM_PASSWORD" = "true" ]
then
        echo "Generating a random database password"
        NS_DBPASSWORD=$(openssl rand -hex 6)
fi


if [ -z "$NS_DBPASSWORD" ]
then

echo "This utility will install NirvaShare software."
echo ""
while true; do
    read -p "Do you want to continue? (y/n)? " yn
    case $yn in
        [Yy] ) break;;
        [Nn] ) terminate; exit;;
        * ) echo "Please answer yes or no (y/n).";;
    esac
done

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
fi



if [ -e /var/nirvashare/install-app.yml ]
then
    echo
    echo "NirvaShare is already installed in this system."
    terminate

fi


#yum -y update


# Remove any old versions
echo "Cleaning up existing installation if any"
sudo yum remove docker docker-common docker-selinux docker-engine

# Install required packages
echo "Installing required packages"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# Configure docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker-ce
sudo yum install docker-ce -y

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Post Installation Steps
# Create Docker group
sudo groupadd docker

# Add user to the docker group
sudo usermod -aG docker $USER


# docker-compose

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Permssion +x execute binary
chmod +x /usr/local/bin/docker-compose

# Create link symbolic 
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Check Version docer-compose
echo "Installation Complete -- Logout and Log back"
docker-compose --version

# NirvaShare installation

echo "Installing NirvaShare services"
mkdir -p /var/nirvashare
create_pass_file

sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install-app.yml

#cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_DBPASSWORD/" >> /var/nirvashare/install-app.yml

docker-compose -f /var/nirvashare/install-app.yml up -d
echo ""
echo "Installation Completed."


