################################
# Gateway setup by @bobvanluijt
################################

#!/bin/bash

###
# Load all arguments
###
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -h|--dbhost)
    DBHOST="$2"
    shift # past argument
    ;;
    -p|--dbpass)
    DBPASS="$2"
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

###
# Validate if needed arguments are available
###
if [ -z ${DBHOST} ]; then echo "-h or --dbhost is unset | abort";    exit 1; fi
if [ -z ${DBPASS} ]; then echo "-p or --dbpass is unset | abort";  exit 1; fi

# Run the script as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# setup for gcloud (add debs)
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Update
apt-get update -qq -y

# Install security updates
apt-get unattended-upgrades -d -qq -y

# Install MYSQL client and set pass and host
apt-get install mysql-client-5.7 -qq -y
echo "What is the mysql root password: "
mysql_config_editor set --login-path=local --host=${DBHOST} --user=root --password

# Install jq for parsing jquery
apt-get install jq -qq -y

# Install gcloud
mdkir gcloud
wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-128.0.0-linux-x86_64.tar.gz
tar -xzf google-cloud-sdk-128.0.0-linux-x86_64.tar.gz -C gcloud
cd gcloud
CLOUDSDK_CORE_DISABLE_PROMPTS=1 ./install.sh

# Install Docker deps
apt-get install apt-transport-https ca-certificates -qq -y

# Add docker keys
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# Update with docker keys
apt-get update -qq -y

# Create file docker.list
touch /etc/apt/sources.list.d/docker.list

# Add Ubuntu Xenial repo
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" >> /etc/apt/sources.list.d/docker.list

# Update after adding Docker repo
apt-get update -qq -y

# Double check and remove if above already exsists
apt-get purge lxc-docker -qq -y

# Run Cache
apt-cache policy docker-engine

# Install ubuntu image
apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual -qq -y

# Install docker engine
apt-get install docker-engine -qq -y

# Start the Docker service
service docker start

# Install NGINX
apt-get install nginx -qq -y

# Install SSL
apt-get install letsencrypt -qq -y
