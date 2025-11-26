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
	echo "NirvaShare Installation Utility."
	echo ""
	echo "This script will install NirvaShare along with its core services and dependencies."
	echo "Make sure you have root or sudo access before proceeding."

	user_prompt()
	{

		if [ "$NS_RANDOM_PASSWORD" = "true" ]
		then
			echo "Generating a random database password"
			NS_DBPASSWORD=$(openssl rand -hex 6)
		fi


		if [ -z "$NS_DBPASSWORD" ]
		then


		echo ""
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
		  read -s -p "Enter new database password: " NS_DBPASSWORD
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

	}


	check_existing_intallation()
	{
		if [ -e /var/nirvashare/install-app.yml ]
		then
		    echo
		    echo "NirvaShare is already installed in this system."
		    terminate

		fi
	}


	# Function to install Docker on Debian/Ubuntu
	install_docker_debian() {
	    echo "Updating package list..."
	    sudo apt update -y
	    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

	    echo "Adding Docker’s official GPG key..."
	    curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

	    echo "Adding Docker repository..."
	    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	    echo "Installing Docker..."
	    sudo apt update -y
	    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

	    echo "Enabling and starting Docker..."
	    sudo systemctl enable --now docker
	}

	# Function to install Docker on rhel
	install_docker_rhel() {
	    echo "Updating system..."
	    sudo yum update -y

	    echo "Installing required dependencies..."
	    sudo yum install -y yum-utils

	    echo "Adding Docker repository..."
	    sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

	    echo "Installing Docker..."
	    sudo yum install -y docker-ce docker-ce-cli containerd.io

	    echo "Enabling and starting Docker..."
	    sudo systemctl enable --now docker
	}

	install_docker_suse() {
	    echo "Updating system..."
	    sudo zypper install -y docker
	    sudo systemctl enable docker
	    sudo systemctl start docker
	}


	# Function to install Docker on CentOS/Rocky/AlmaLinux
	install_docker_centos() {
	    echo "Updating system..."
	    sudo yum update -y

	    echo "Installing required dependencies..."
	    sudo yum install -y yum-utils

	    echo "Adding Docker repository..."
	    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

	    echo "Installing Docker..."
	    sudo yum install -y docker-ce docker-ce-cli containerd.io

	    echo "Enabling and starting Docker..."
	    sudo systemctl enable --now docker
	}

	# Function to install Docker on Fedora
	install_docker_fedora() {
	    echo "Updating system..."
	    sudo dnf update -y

	    echo "Installing required dependencies..."
	    sudo dnf install -y dnf-plugins-core

	    echo "Adding Docker repository..."
	    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

	    echo "Installing Docker..."
	    sudo dnf install -y docker-ce docker-ce-cli containerd.io

	    echo "Enabling and starting Docker..."
	    sudo systemctl enable --now docker
	}

	# Function to install Docker on Arch Linux
	install_docker_arch() {
	    echo "Updating system..."
	    sudo pacman -Syu --noconfirm

	    echo "Installing Docker..."
	    sudo pacman -S --noconfirm docker

	    echo "Enabling and starting Docker..."
	    sudo systemctl enable --now docker
	}

	install_docker()
	{
		# Detect OS and install Docker
		echo "Detecting operating system..."
		if [ -f /etc/os-release ]; then
		    . /etc/os-release
		    case "$ID" in
			ubuntu|debian) install_docker_debian ;;
			centos|rocky|almalinux) install_docker_centos ;;
			rhel)
				if [[ "$VERSION_ID" == 7* ]]; then
				    echo "RHEL 7 detected"
				    install_docker_centos
				else
				    echo "RHEL $VERSION_ID detected"
				    install_docker_rhel
				fi
				;;
			fedora) install_docker_fedora ;;
			sles|opensuse-leap|opensuse-tumbleweed) install_docker_suse ;;		
			arch) install_docker_arch ;;
			*)
			    echo "Unsupported Linux distribution: $ID"
			    exit 1
			    ;;
		    esac
		else
		    echo "Cannot determine OS. Exiting."
		    exit 1
		fi

		 echo "Verifying Docker installation..."
	    if docker --version >/dev/null 2>&1; then
		echo "Docker installed successfully!"
	    else
		echo "Docker installation failed."
		terminate; exit;
	    fi


	}

	# docker-compose

	install_docker_compose()
	{
		# NirvaShare installation

		mkdir -p /var/nirvashare
		create_pass_file
		
		if [ "$NS_TEST" = "true" ]
		then
			sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app-test.yml" -o /var/nirvashare/install-app.yml		
		else 
			sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install-app.yml		
		fi

		export COMPOSE_IGNORE_ORPHANS=true
		
		if [ -f /etc/os-release ]; then
		    . /etc/os-release

		    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
			docker compose -f /var/nirvashare/install-app.yml up -d
		    else
			sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
			sudo chmod +x /usr/local/bin/docker-compose		
			
			/usr/local/bin/docker-compose -f /var/nirvashare/install-app.yml up -d
		    
		    fi

		else
		    echo "Cannot determine OS. Exiting."
		    exit 1
		fi




	}





	check_root(){

		if [ "$(id -u)" -ne 0 ]; then
		  echo "Error: This script must be run as root."
		 terminate; exit;
		fi
	}


installation_complete() {

	echo ""
	echo "Installation Completed."

}



check_root
user_prompt
check_existing_intallation
install_docker
install_docker_compose
installation_complete


