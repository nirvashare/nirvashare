#!/bin/bash

#
# Ubuntu installation script
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

mkdir -p /var/nirvashare
create_pass_file

sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install_file

cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_DBPASSWORD/" >> /var/nirvashare/install-app.yml

docker-compose -f /var/nirvashare/install-app.yml up -d

echo ""
echo "Installation Completed."

