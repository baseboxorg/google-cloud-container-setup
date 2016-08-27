# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Update the repository sources list
RUN apt-get update -qq -y

# Install NGINX
RUN apt-get install nginx -qq -y

# install hhvm
RUN apt-get install hhvm -qq -y

# install git
RUN apt-get install git -qq -y

# Go into www dire
RUN cd /var/www

# Clone wordpress with version 4.6
RUN git clone https://github.com/WordPress/WordPress.git && \
	cd WordPress && \
    git fetch && \
    git checkout 4.6-branch && \
    git fetch && \
    git pull

# Remove git
RUN apt-get remove git -qq -y

# Expose port 80
EXPOSE 80

# start nginx
CMD ["nginx", "-g", "daemon off;"]
