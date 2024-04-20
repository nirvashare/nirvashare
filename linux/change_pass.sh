#!/bin/bash

#
# Change password script
#


DOCKER_FILE="/var/nirvashare/install-app.yml"
DB_PASS_FILE=/var/nirvashare/dbpass

NS_SQL_FILE=pass_reset.sql

terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}

update_pass_file()
{

    	# create the password file
        echo $NS_DBPASSWORD > ${DB_PASS_FILE}    
}

create_pass_sql()
{

	# create the password file
        echo "ALTER USER nirvashare WITH PASSWORD '$NS_DBPASSWORD';" > ${NS_SQL_FILE}    

}


user_prompt()
{

	echo ""
	echo "NirvaShare Change Password Utility."
	echo ""

	echo "This utility will allow you to change the database password and restart the services of NirvaShare."
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


prompt_password() 
{


if [ "$NS_RANDOM_PASSWORD" = "true" ]
then
        echo "Generating a random database password"
        NS_DBPASSWORD=$(openssl rand -hex 6)
fi


if [ -z "$NS_DBPASSWORD" ]
then

user_prompt

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


}

check_installation() {
    if [ -f "$DOCKER_FILE" ]; then
        #check if install file has search feature.
        echo 
        
    else 
        echo "$DOCKER_FILE does not exist."
        terminate;
    fi
}


change_pass()
{

    cat ${NS_SQL_FILE} | docker exec -i nirvashare_database psql -U nirvashare
    echo "Updated database password."


}

update_pass_file()
{
    echo $NS_DBPASSWORD > ${DB_PASS_FILE} 
    echo "Updated configuration."
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

cleanup()
{
   
    rm ${NS_SQL_FILE}    
}

check_installation
prompt_password
create_pass_sql
change_pass
update_pass_file
restart_nirvashare
cleanup


echo ""
echo "Password Updated Successfully!"
echo ""
echo "NOTE - Please wait for couple of minutes for the services to come up."
echo ""
