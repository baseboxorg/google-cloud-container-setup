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
    -t|--swarmtoken)
    SWARMTOKEN="$2"
    shift # past argument
    ;;
    -i|--swarmip)
    SWARMIP="$2"
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
if [ -z ${SWARMTOKEN} ]; then echo "-t or --swarmtoken is unset | abort";   exit 1; fi
if [ -z ${SWARMIP} ];    then echo "-i or --swarmip is unset | abort"; exit 1; fi

# Update
apt-get update -qq -y

# Install security updates
apt-get unattended-upgrades -d -qq -y

# Install jq for parsing jquery
apt-get install jq -qq -y

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

# Make main dir to connect Wordpress wp-content directories to
# DISABLED, MIGHT BE REMOVED ON CLEANUP
# mkdir -m 777 -p /var/wordpress-content

# Add this machine to the swarm
docker swarm join --token ${SWARMTOKEN} ${SWARMIP}:2377