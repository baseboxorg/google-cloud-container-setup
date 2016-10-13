###############
#
# Docker setup for Wordpress in multiple container setup
# Author: Bob van Luijt
# Readme: https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud
#
###############

# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Update the repository sources list
RUN apt-get update -qq -y

# Install apt-utils
RUN apt-get install apt-utils wget -qq -y

# install PHP7
RUN apt-get install -qq -y php7.0-fpm php7.0-mysql php7.0-mcrypt php-mbstring php-gettext && \
    phpenmod mcrypt && \
    phpenmod mbstring

# Expose port 80 and 443
EXPOSE 9000

# start nginx and php7.0-fpm
CMD service php7.0-fpm start