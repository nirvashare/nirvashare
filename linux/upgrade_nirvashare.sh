#!/bin/bash


DOCKER_FILE="/var/nirvashare/install-app.yml"
DOCKER_FILE_FTPS="/var/nirvashare/install-ftps.yml"
DB_PASS_FILE=/var/nirvashare/dbpass

terminate()
{
    echo ""
    echo "Upgrade terminated"
    exit 1
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

update_docker_compose()
{
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
}

cleanup()
{
    rm /var/nirvashare/install_file &>/dev/null
}


update_configuration()
{
    echo "Updating configuration"

    line=$(grep -m1 "ns_db_password" $DOCKER_FILE)
    NS_DBPASSWORD=`echo "$line" | cut -d'"' -f 2`
    mv $DOCKER_FILE ${DOCKER_FILE}_1.del
    sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o ${DOCKER_FILE}

    create_pass_file
}

update_nirvashare()
{
    echo "Updating applications"
    echo ""
    export COMPOSE_IGNORE_ORPHANS=true
    
    docker-compose -f $DOCKER_FILE pull
    docker-compose -f $DOCKER_FILE up -d
    
    if [ -e "$DOCKER_FILE_FTPS" ]; then
        docker-compose -f $DOCKER_FILE_FTPS pull
        docker-compose -f $DOCKER_FILE_FTPS up -d
    fi
}


user_prompt()
{

	echo ""
	echo "NirvaShare Upgrade Utility."
	echo ""

	echo "This will upgrade NirvaShare applications to latest version."
	while true; do
	    read -p "Do you want to continue? (y/n)? " yn
	    case $yn in
		[Yy] ) break;;
		[Nn] ) terminate; exit;;
		* ) echo "Please answer yes or no (y/n).";;
	    esac
	done

	echo ""
	echo ""
}

update_config() {
    if [ -f "$DOCKER_FILE" ]; then
        #check if install file has search feature.
        if [ ! -e "$DB_PASS_FILE" ]; then
         update_configuration
        fi
    else 
        echo "$DOCKER_FILE does not exist."
        terminate;
    fi
}

remove_webdav() {
    WEBDAV_FILE=/var/nirvashare/install-webdav.yml
    if [ -f "$WEBDAV_FILE" ]; then
        echo "Removing Webdav service"

        #check if webdav install file and remove it.
       docker-compose -f $WEBDAV_FILE rm -f --stop
       rm $WEBDAV_FILE

    fi
}




user_prompt
update_docker_compose
update_config
remove_webdav
update_nirvashare
cleanup


echo ""
echo "Upgrade Completed Successfully!"
echo ""
echo "NOTE - Please wait for couple of minutes for the services to start automatically."
echo ""


