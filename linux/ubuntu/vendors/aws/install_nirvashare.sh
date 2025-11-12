#!/bin/bash

echo ""
echo "Starting to install NirvaShare application."
echo ""


echo "Generating a random database password"
NS_DBPASSWORD=$(openssl rand -hex 6)

DB_PASS_FILE=/var/nirvashare/dbpass

if [ -z "$NS_DBPASSWORD" ]
then
while true; do
  read -s -p "Enter database password: " NS_DBPASSWORD
  echo
  read -s -p "Confirm database password: " NS_DBPASSWORD2
  echo
  [ "$NS_DBPASSWORD" = "$NS_DBPASSWORD2" ] && break
  echo "Passwords not matching, please re-enter"
done

fi


sudo apt update
# docker
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

# docker-compose

#sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# NirvaShare installation

mkdir -p /var/nirvashare
#sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install_file
sudo curl -L "https://raw.githubusercontent.com/nirvashare/nirvashare/main/docker/common/install-app.yml" -o /var/nirvashare/install-app.yml

echo $NS_DBPASSWORD > ${DB_PASS_FILE}
#cat /var/nirvashare/install_file  | sed -e "s/__DB_PASS__/$NS_DBPASSWORD/" >> /var/nirvashare/install-app.yml


docker-compose -f /var/nirvashare/install-app.yml pull
docker-compose -f /var/nirvashare/install-app.yml up -d


set -e
echo "Waiting for NirvaShare application to start..."
count=0

until curl --output /dev/null --silent --head --fail "http://localhost:8080/actuator/health"; do
  >&2 echo "Adminconsole is unavailable - sleeping"
  count=$(( count + 1 ))
  if [ $count -eq 30 ];then
	break
  fi
  sleep 5
done
>&2 echo "AdminConsole is up"

echo "Changing admin password"

# Get IMDSv2 token (valid for 6 hours)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
              -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Query the instance ID using the token
INSTANCEID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
                  http://169.254.169.254/latest/meta-data/instance-id)

# Save instance ID to file
echo "$INSTANCEID" >/var/nirvashare/set_password


docker restart nirvashare_admin
echo "Restarted adminconsole"
echo "Waiting for Adminconsole application to start..."
count=0

until curl --output /dev/null --silent --head --fail "http://localhost:8080/actuator/health"; do
  >&2 echo "Adminconsole is unavailable - sleeping"
  count=$(( count + 1 ))
  if [ $count -eq 30 ];then
	break
  fi
  sleep 3
done
>&2 echo "AdminConsole is up"

rm /var/nirvashare/set_password


