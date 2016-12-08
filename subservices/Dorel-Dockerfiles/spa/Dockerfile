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
RUN apt-get install nginx wget unzip -qq -y

# Set nginx config
RUN rm /etc/nginx/sites-enabled/default && \
    wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${BRANCH}/subservices/Dorel-Dockerfiles/spa/default -O /etc/nginx/sites-enabled/default

# Setup Git
RUN mkdir /var/www/spa && \
    wget https://github.com/dorel/polymer-spa-dorel-juvenile/archive/${BRANCH}.zip -O /var/www/spa.zip && \
    unzip /var/www/spa.zip -d /var/www/spa && \
    rm /var/www/spa.zip && \
    mv /var/www/spa/polymer-spa-dorel-juvenile-develop/build/bundled/* /var/www/spa && \
    rm -r /var/www/spa/polymer-spa-dorel-juvenile-develop

# Remove unused packages
RUN apt-get purge wget unzip -qq -y

# Expose port 80 (NOTE: Not using 443, this is done by load balancer)
EXPOSE 80

# start nginx
CMD nginx -g "daemon off;"