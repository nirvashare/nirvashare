#!/bin/bash

#
# Change password script
#

BACKUP_TEMP_FOLDER=/var/nirvashare/bk-temp
BACKUP_FOLDER=/var/nirvashare/backup
CONFIG_FILE=/var/nirvashare/config.properties
DOCKER_FILE=/var/nirvashare/install-app.yml
DOCKER_FILE_FTPS=/var/nirvashare/install-ftps.yml



terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}




user_prompt()
{

	echo ""
	echo "NirvaShare Data Restore Utility."
	echo ""

	echo "This utility will allow you to restore entire database and the configurations from a backup file of NirvaShare."
	echo "Please note that existing data will be deleted and new data will be restored from the backup file."

       if [ "${NS_SILENT}" != 'true'  ]; then
   	  while true; do
	    read -p "Do you want to restore now? (y/n)? " yn
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

prompt_filename() 
{




	if [ -z "$BACKUP_FILE" ]
	then

	user_prompt

	while true; do
	
	  read -p  "Enter the backup file name with full path: " BACKUP_FILE
	  echo
	  
	  if [[ $BACKUP_FILE = "" ]]; 
	  then 
	    echo 
	  elif [[ $BACKUP_FILE != *.tar.gz ]]
	  then
  	    echo "Expected file extension should be tar.gz"
	  elif [ ! -f ${BACKUP_FILE} ] 
	  then 
	       echo "File not found - ${BACKUP_FILE}"
          else 
	     break
	   fi	  
	  
	done
	fi


}


check_status() 
{
    if [ "$?" -eq "1" ]; then
      terminate
    fi

}

restart_nirvashare()
{
    echo "Restarting Services"
    echo ""
    export COMPOSE_IGNORE_ORPHANS=true
    
    docker-compose -f $DOCKER_FILE restart

    
    if [ -e "$DOCKER_FILE_FTPS" ]; then
        docker-compose -f $DOCKER_FILE_FTPS restart
    fi
}

restore_backup() {

    if [ -e "$BACKUP_TEMP_FOLDER" ]; then
    	rm $BACKUP_TEMP_FOLDER/*
    	rmdir $BACKUP_TEMP_FOLDER
    fi
    mkdir $BACKUP_TEMP_FOLDER
    tar -xzf ${BACKUP_FILE}  -C ${BACKUP_TEMP_FOLDER}
    check_status
    
    echo "Restore of database started."    
    docker exec -t nirvashare_database pg_dumpall -c -U nirvashare > ${BACKUP_TEMP_FOLDER}/db-dump.sql
    check_status
    
    if [ -e "${BACKUP_TEMP_FOLDER}/config.properties" ]; then
	    cp ${BACKUP_TEMP_FOLDER}/config.properties ${CONFIG_FILE}
    fi
    


    echo "Restore Completed Successfully!"
    echo ""
    
    echo ""

}



check_installation() {
    if [ -f "$DOCKER_FILE" ]; then
        
        prompt_filename
        
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
restore_backup
restart_nirvashare
cleanup



