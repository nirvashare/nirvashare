#!/bin/bash

#
# Change password script
#

BACKUP_TEMP_FOLDER=/var/nirvashare/bk-temp
BACKUP_FOLDER=/var/nirvashare/backup
CONFIG_FILE=/var/nirvashare/config.properties
DOCKER_FILE=/var/nirvashare/install-app.yml
DB_PASS_FILE=/var/nirvashare/dbpass

terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}




user_prompt()
{

	echo ""
	echo "NirvaShare Data Backup Utility."
	echo ""

	echo "This utility will allow you to take backup of entire database and the configurations of NirvaShare."

       if [ "${NS_SILENT}" != 'true'  ]; then
   	  while true; do
	    read -p "Do you want to backup now? (y/n)? " yn
	    case $yn in
		[Yy] ) break;;
		[Nn] ) terminate; exit;;
		* ) echo "Please answer yes or no (y/n).";;
	    esac
	  done
	  
      else 
          echo "Silent mode enabled"
      fi
	echo ""
	echo ""
}

check_status() 
{
    if [ "$?" -eq "1" ]; then
      terminate
    fi

}

create_backup() {

    if [ -e "$BACKUP_TEMP_FOLDER" ]; then
    	rm $BACKUP_TEMP_FOLDER/*
    	rmdir $BACKUP_TEMP_FOLDER
    fi
    mkdir $BACKUP_TEMP_FOLDER
    echo "Backup of database started."    
    docker exec -t nirvashare_database pg_dumpall -c -U nirvashare > ${BACKUP_TEMP_FOLDER}/db-dump.sql
    check_status
    
    if [ -e "$CONFIG_FILE" ]; then
	    cp ${CONFIG_FILE} ${BACKUP_TEMP_FOLDER}/
    fi
    
    if [ -e "$DB_PASS_FILE" ]; then
	    cp ${DB_PASS_FILE} ${BACKUP_TEMP_FOLDER}/
    fi
    
    if [ ! -e "$BACKUP_FOLDER" ]; then
	    mkdir ${BACKUP_FOLDER}
    fi
    FILE_NAME=ns_backup_`date +%Y-%m-%d"_"%H%M%S`.tar.gz

    tar -czf  ${BACKUP_FOLDER}/${FILE_NAME}  -C ${BACKUP_TEMP_FOLDER} $(ls ${BACKUP_TEMP_FOLDER})
    check_status

    echo "Backup Created Successfully!"
    echo ""
    
    echo "Location - ${BACKUP_FOLDER}/${FILE_NAME}"
    echo ""
    export NS_BACKUP_FILE=${BACKUP_FOLDER}/${FILE_NAME}
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
    if [ -e "$BACKUP_TEMP_FOLDER" ]; then
    	rm $BACKUP_TEMP_FOLDER/*
	rmdir $BACKUP_TEMP_FOLDER
    fi	    
	    
}

check_installation
create_backup
cleanup



