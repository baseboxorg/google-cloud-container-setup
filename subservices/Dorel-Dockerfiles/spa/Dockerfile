###############
#
# Docker setup for Dorel SPA
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
# docker build -t spa-gcloud --build-arg branch=develop .
# docker run -d spa-gcloud
###############

# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Set the arguments
ARG branch
ENV BRANCH ${branch}

# Update the repository sources list
RUN apt-get update -qq -y

# Install nginx, git and wget
RUN apt-get install nginx git wget -qq -y

# Set nginx config
RUN rm /etc/nginx/sites-enabled/default && \
    wget 

# Setup Git
RUN mkdir /var/www/spa && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:dorel/polymer-spa-dorel-juvenile.git /var/www/spa && \
    git checkout ${BRANCH} && \
    git pull

# Expose port 80 and 443
EXPOSE 80 443

# start nginx
CMD nginx -g "daemon off;"