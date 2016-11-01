#!/bin/bash
###############
#
# Bash script for creating main proxy server and holder of the docker containers.
# Author: Bob van Luijt
# Readme: https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud
#
###############

# Run the script as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Collect the arguments
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -i|--sqlip)
    DBHOST="$2"
    shift # past argument
    ;;
    -p|--sqlpass)
    SQLPASS="$2"
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
    # if unknown option
    ;;
esac
shift # past argument or value
done

###
# Validate if needed arguments are available
###
if [ -z ${DBHOST} ];   then echo "-i or --sqlip is unset | abort";    exit 1; fi
if [ -z ${SQLPASS} ];  then echo "-p or --sqlpass is unset | abort";  exit 1; fi

# Update and install dialog
apt-get update -qq -y
apt-get install dialog -qq -y

# Install security updates
apt-get unattended-upgrades -d -qq -y

# get the internal ip host
INTERNALHOST=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

# setup for gcloud (add debs)
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Install MYSQL client and set pass and host
apt-get install mysql-client-5.7 -qq -y
mysql_config_editor set --login-path=local --host=${DBHOST} --user=root --password="${SQLPASS}"

# Install gcloud
apt-get install google-cloud-sdk
gcloud init

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

# Install NGINX (disabled for now, might be removed during checkup)
# apt-get install nginx -qq -y

# Install SSL (disabled for now, might be removed during checkup)
# apt-get install letsencrypt -qq -y

# Make main dir to connect Wordpress wp-content directories to
mkdir -m 777 -p /var/wordpress-content

# Create Docker manager
docker swarm init --advertise-addr ${INTERNALHOST}

# Write token to config file (will be used later in the setup)
docker swarm join-token worker -q > ~/config-dockerswarm