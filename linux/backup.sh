#!/bin/bash

#
# Change password script
#

BACKUP_TEMP_FOLDER=/var/nirvashare/bk-temp
BACKUP_FOLDER=/var/nirvashare/backup
CONFIG_FILE=/var/nirvashare/config.properties
DOCKER_FILE=/var/nirvashare/install-app.yml


terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}




user_prompt()
{

	echo ""
	echo "NirvaShare Backup Utility."
	echo ""

	echo "This utility will allow you to take backup of entire database and the configurations of NirvaShare."
	while true; do
	    read -p "Do you want to backup now? (y/n)? " yn
	    case $yn in
		[Yy] ) break;;
		[Nn] ) terminate; exit;;
		* ) echo "Please answer yes or no (y/n).";;
	    esac
	done

	echo ""
	echo ""
}


create_backup() {

    if [ -e "$BACKUP_TEMP_FOLDER" ]; then
    	rm -rf $BACKUP_TEMP_FOLDER
    fi
    mkdir $BACKUP_TEMP_FOLDER
    docker exec -t nirvashare_database pg_dumpall -c -U nirvashare > ${BACKUP_TEMP_FOLDER}/db-dump.sql
    
    if [ -e "$CONFIG_FILE" ]; then
	    cp ${CONFIG_FILE} ${BACKUP_TEMP_FOLDER}/
    fi
    
    if [ ! -e "$BACKUP_FOLDER" ]; then
	    mkdir ${BACKUP_FOLDER}
    fi
    FILE_NAME=ns_backup_`date +%Y-%m-%d"_"%H_%M_%S`.tar.gz

    tar -czf  ${BACKUP_FOLDER}/${FILE_NAME}  -C ${BACKUP_TEMP_FOLDER} $(ls ${BACKUP_TEMP_FOLDER})


    echo "Backup Created Successfully!"
    echo ""
    
    echo "Location - ${BACKUP_FOLDER}/${FILE_NAME}"
    
}



check_installation() {
    if [ -f "$DOCKER_FILE" ]; then
        
        user_prompt
        
    else 
        echo "$DOCKER_FILE does not exist."
        terminate;
    fi
}






cleanup()
{
   echo 
 #   rm ${NS_SQL_FILE}    
}

check_installation
create_backup
cleanup



