###############
#
# Docker setup for Dorel Wordpress and PHP7 FPM
# Author: Bob van Luijt
# Readme: https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud
#
###############

# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Set the arguments
ARG site_title
ENV site_title ${site_title}
ARG admin_email
ENV admin_email ${admin_email}
ARG site_url
ENV site_url ${site_url}
ARG admin_user
ENV admin_user ${admin_user}
ARG admin_pass
ENV admin_pass ${admin_pass}
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
ARG branch
ENV dbhost ${branch}

# Update the repository sources list
RUN apt-get update -qq -y

# Install apt-utils
RUN apt-get install php7.0-fpm php7.0-mysql php7.0-mcrypt php-mbstring php-gettext mysql-client nginx wget -qq -y

# Install wp-cli
RUN wget -q -nv https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P ~ && \
    phpenmod mcrypt && \
    phpenmod mbstring && \
    chmod +x ~/wp-cli.phar && \
    mv ~/wp-cli.phar /usr/local/bin/wp
 
# Download Wordpress
RUN rm -r /var/www/html
RUN mkdir -p /var/www && \
    mkdir -p /var/www/WordPress && \
    wp core download --path=/var/www/WordPress --allow-root

# Config Wordpress
RUN wp core config --path=/var/www/WordPress --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=${dbhost} --allow-root

# Install Wordpress (ADD USERNAME AND PASSWORD LATER)
RUN wp core install --allow-root --path=/var/www/WordPress --url=${site_url} --title=${site_title} --admin_user=${admin_user} --admin_password=${admin_pass} --admin_email=${admin_email}

# Install super cache, first set chmod 777 and set back later
RUN chmod 777 /var/www/WordPress/wp-config.php && \
    chmod 777 /var/www/WordPress/wp-content

# IMPORTANT: The wp-content dir is renamed so it can be remounted in the docker run with an external directory
RUN mv /var/www/WordPress/wp-content /var/www/WordPress/wp-content_tmp

# Set nginx config
RUN rm /etc/nginx/sites-enabled/default && \
    https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${branch}/subservices/Dorel-Dockerfiles/wordpress-nginx/default -O /etc/nginx/sites-enabled/default

# SET WORDPRESS SECURITY (SEE GITHUB ISSUE)

# remove unused things, also remove PHP and wp-cli
RUN apt-get purge wget -qq -y && \
    apt-get autoremove -qq -y

# Expose port 80
EXPOSE 80

# start nginx
CMD nginx -g "daemon off;"