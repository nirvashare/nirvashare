#!/bin/bash



terminate()
{
    echo ""
    echo "Installation terminated"
    exit 0
}


check_root(){

	if [ "$(id -u)" -ne 0 ]; then
	  echo "Error: This script must be run as root."
	 terminate; exit;
	fi
}


user_prompt()
{

	if [ "$NS_RANDOM_SECRET_KEY" = "true" ]
	then
		echo "Generating a random database password"
		NS_SECRET_KEY=$(openssl rand -hex 32)
	fi


	if [ -z "$NS_SECRET_KEY" ]
	then
	
	echo ""
	echo "This utility will install Onlyoffice with NirvaShare service."
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
	  echo
	  read -p "Enter new secret key: " NS_SECRET_KEY
	  echo
	  size=${#NS_SECRET_KEY}
	  
	 if [[ ! "$NS_SECRET_KEY" =~ ^[a-zA-Z0-9]+$ ]]; then
		  echo "❌ Invalid: only letters and numbers allowed, no spaces or special characters."
	  elif [ "${size}" -lt "32"  ] 
	  then 
	       echo "❌ Secret key length should be atleast 32 characters."	  
	   else 
	  	 break
	   fi	  
	  
	done
	fi

}

check_existing_intallation()
{
	if [ -e /var/nirvashare/install-onlyoffice.yml ]
	then
	    echo
	    echo "Onlyoffice is already installed in this system."
	    terminate

	fi
}


install_onlyoffice() {

	# docker-compose

	sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

	sudo chmod +x /usr/local/bin/docker-compose

	# NirvaShare installation


	sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-onlyoffice.yml" -o /var/nirvashare/install-onlyoffice

	export COMPOSE_IGNORE_ORPHANS=true
	cat /var/nirvashare/install-onlyoffice  | sed -e "s/__NS_SECRET__/$NS_SECRET_KEY/" >> /var/nirvashare/install-onlyoffice.yml
	docker compose -f /var/nirvashare/install-onlyoffice.yml up -d


}

installation_complete() {

	echo ""
	echo "✅  Installation Completed."
	echo ""	

}


check_root
user_prompt
check_existing_intallation
install_onlyoffice
installation_complete

