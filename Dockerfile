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
ARG dbname
ENV dbname ${dbname}
ARG dbuser
ENV dbuser ${dbuser}
ARG dbpass
ENV dbpass ${dbpass}
ARG dbhost
ENV dbhost ${dbhost}

# Update the repository sources list
RUN apt-get update -qq -y

# Install unzip
RUN apt-get install unzip -qq -y

# Install NGINX and remove HTML dir
RUN apt-get install nginx -qq -y && \
    rm -r /var/www/html

# install PHP7
RUN apt-get install php7.0-fpm php7.0-mysql php7.0-mcrypt php-mbstring php-gettext -qq -y && \
    phpenmod mcrypt && \
    phpenmod mbstring

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Go into www dire
RUN cd /var/www
 
# Download Wordpress
RUN wget https://github.com/WordPress/WordPress/archive/4.6-branch.zip && \
    unzip -q 4.6-branch.zip && \
    mv WordPress-4.6-branch WordPress && \
    rm 4.6-branch.zip && \
    cd WordPress

# Download wpconfig
RUN wget https://raw.githubusercontent.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud/master/wp-config.php

# Update settings in wp-config file
RUN sed -i 's/\[DBNAME\]/${dbname}/g' wp-config.php && \
    sed -i 's/\[DBUSER\]/${dbuser}/g' wp-config.php && \
    sed -i 's/\[DBPASS\]/${dbpass}/g' wp-config.php && \
    sed -i 's/\[DBHOST\]/${dbhost}/g' wp-config.php

# Install Wordpress (ADD USERNAME AND PASSWORD LATER)
RUN wp core install --allow-root --url=130.211.39.100 --title=Example --admin_user=root --admin_password=qwerty --admin_email=bob@kubrickolo.gy

# Install super cache, first set chmod 777 and set back later
RUN chmod 777 wp-config.php && \
    chmod 777 /var/www/WordPress/wp-content && \
    wp plugin install wp-super-cache --activate --allow-root && \
    chmod 755 wp-config.php && \
    chmod 755 /var/www/WordPress/wp-content
   
# Set nginx config
RUN cd /etc/nginx/sites-enabled/ && \
    rm default && \
    wget https://raw.githubusercontent.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud/master/default
   
# Install letsencrypt
RUN apt-get install letsencrypt -qq -y

# setup the script
# RUN letsencrypt certonly --webroot -w /var/www/WordPress -d ${ssl_domain} -d www.${ssl_domain}

# Expose port 80 and 443
EXPOSE 80
EXPOSE 443

# start nginx
CMD ["nginx", "-g", "daemon off;"] # service php7.0-fpm start
