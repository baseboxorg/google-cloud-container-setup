################################
# Gateway setup by @bobvanluijt
################################

#!/bin/bash

# Run the script as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Update
apt-get update -qq -y

# Install MYSQL client
apt-get install mysql-client-core-5.7 -qq -y

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

# Install NGINX
apt-get install nginx -qq -y

# Install SSL
apt-get install letsencrypt -qq -y
