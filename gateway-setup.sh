#!/bin/bash

sudo su

apt-get update -qq -y && \

apt-get install apt-transport-https ca-certificates -qq -y && \

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \

touch /etc/apt/sources.list.d/docker.list && \

echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" >> /etc/apt/sources.list.d/docker.list && \

apt-get update -qq -y && \

apt-get purge lxc-docker -qq -y && \

apt-cache policy docker-engine && \

apt-get update -qq -y && \

apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual -qq -y && \

apt-get install docker-engine -qq -y && \

service docker start && \

apt-get install nginx -qq -y
