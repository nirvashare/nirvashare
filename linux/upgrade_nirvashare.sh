#!/bin/bash


DOCKER_FILE="/var/nirvashare/install-app.yml"

terminate()
{
    echo ""
    echo "Upgrade terminated"
    exit 1
}

cleanup()
{
    rm /var/nirvashare/install_file &>/dev/null
}


update_configuration()
{
    echo "Updating configuration"
    sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install_file
    line=$(grep -m1 "ns_db_password" $DOCKER_FILE)
    NS_PASSWORD=`echo "$line" | cut -d'"' -f 2`
    mv $DOCKER_FILE ${DOCKER_FILE}.del
    cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_PASSWORD/" > $DOCKER_FILE
}

update_nirvashare()
{
    echo "Updating applications"
    echo ""
    docker-compose -f $DOCKER_FILE pull
    docker-compose -f $DOCKER_FILE up -d
}



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

if [ -f "$DOCKER_FILE" ]; then
    #check if install file has search feature.
    if ! grep -q nirvashare_search "$DOCKER_FILE"; then
        update_configuration
    fi
else 
    echo "$DOCKER_FILE does not exist."
    terminate;
fi



update_nirvashare
cleanup


echo ""
echo "Upgrade Completed Successfully!"
echo ""
echo "NOTE - Please wait for couple of minutes for the services to start automatically. Warning on Orphan containers can be ignored. "
echo ""


