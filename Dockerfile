################################
# Docker setup for Wordpress in multiple container setup by @bobvanluijt
################################

# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Set the arguments
ARG ssl_domain
ENV ssl_domain ${ssl_domain}

# Update the repository sources list
RUN apt-get update -qq -y

# Install apt-utils
# RUN apt-get install apt-utils -qq -y

# Install NGINX
RUN apt-get install nginx -qq -y

# install PHP7
RUN apt-get install php7.0-fpm php7.0-mysql php7.0-mcrypt php-mbstring php-gettext -qq -y && \
    phpenmod mcrypt && \
    phpenmod mbstring

# install git
RUN apt-get install git-core -qq -y

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Go into www dire
RUN cd /var/www

# Clone wordpress with version 4.6
RUN git clone https://github.com/WordPress/WordPress.git && \
    cd WordPress && \
    git fetch && \
    git checkout 4.6-branch && \
    git fetch && \
    git pull
   
# Install super cache, first set chmod 777 and set back later
RUN chmod 777 wp-config.php && \
    chmod 777 /var/www/WordPress/wp-content && \
    wp plugin install wp-super-cache --activate && \
    chmod 755 wp-config.php && \
    chmod 755 /var/www/WordPress/wp-content
   
# Install letsencrypt
RUN apt-get install letsencrypt -qq -y

# setup the script
# RUN letsencrypt certonly --webroot -w /var/www/WordPress -d ${ssl_domain} -d www.${ssl_domain}

# Remove git
RUN apt-get remove git-core -qq -y

# Expose port 80 and 443
EXPOSE 80
EXPOSE 443

# start nginx
CMD ["nginx", "-g", "daemon off;"] # service php7.0-fpm start
