###############
#
# Docker setup for Dorel Wordpress and PHP7.1
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
###############

# Set the base image to Ubuntu
FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Set the arguments
ARG site_title
ENV site_title ${site_title}
ARG editor_email
ENV editor_email ${editor_email}
ARG site_url
ENV site_url ${site_url}
ARG editor_user
ENV editor_user ${editor_user}
ARG editor_pass
ENV editor_pass ${editor_pass}
ARG admin_pass
ENV admin_pass ${admin_pass}
ARG dbname
ENV dbname ${dbname}
ARG dbuser
ENV dbuser ${dbuser}
ARG dbpass
ENV dbpass ${dbpass}
ARG dbhost
ENV dbhost ${dbhost}
ARG branch
ENV branch ${branch}
ARG wordpresslocation
ENV wordpresslocation /var/www/WordPressPre

# Update the repository sources list
RUN apt-get update -qq -y

# Install tools
RUN apt-get install mysql-client nginx wget curl unzip -qq -y

# Install PHP 7.1
RUN echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu xenial main" > /etc/apt/sources.list.d/ondrej-php.list \
    && echo "deb http://ppa.launchpad.net/ondrej/php-qa/ubuntu xenial main" > /etc/apt/sources.list.d/ondrej-php-qa.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    && apt-get update \
    && apt-get -y --no-install-recommends install php7.1-cli php7.1-mysql php7.1-curl php7.1-fpm \
        php7.1-json php7.1-mcrypt php7.1-opcache php7.1-readline php7.1-xml php7.1-zip php-mbstring php7.1-mbstring \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* ~/.composer

# Install wp-cli
RUN wget -q -nv https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P ~ && \
    phpenmod mcrypt && \
    phpenmod mbstring && \
    chmod +x ~/wp-cli.phar && \
    mv ~/wp-cli.phar /usr/local/bin/wp
 
# Download Wordpress
RUN rm -r /var/www/html
RUN mkdir -p /var/www && \
    mkdir -p /var/www/WordPressPre && \
    wp core download --path=${wordpresslocation} --allow-root

# Config Wordpress
RUN wp core config --path=${wordpresslocation} --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=${dbhost} --allow-root

# Install Wordpress NEED TO CHANGE PASS SETTINGS
RUN wp core install --allow-root --path=${wordpresslocation} --url="https://wrps.api.${site_url}" --title="${site_title}" --admin_user=admin --admin_password=${admin_pass} --admin_email=io@dorel.eu

# Set chmod 777 and set back later
RUN chmod 777 /var/www/WordPressPre/wp-config.php && \
    chmod 777 /var/www/WordPressPre/wp-content && \
    mkdir -p /var/www/WordPressPre/wp-content/plugins

# Delete standard plugins
RUN wp plugin delete --allow-root --path=${wordpresslocation} akismet && \
    wp plugin delete --allow-root --path=${wordpresslocation} hello

# Download ACF data
RUN wget "http://connect.advancedcustomfields.com/index.php?p=pro&a=download&k=b3JkZXJfaWQ9NTA1NjV8dHlwZT1kZXZlbG9wZXJ8ZGF0ZT0yMDE1LTAyLTIzIDA2OjUyOjM4" -O /var/www/WordPressPre/wp-content/plugins/acf-pro.zip && \
    mkdir -p /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli && \
    wget https://github.com/dorel/advanced-custom-fields-wpcli/archive/3.0.0.zip -O /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli/3.0.0.zip && \
    unzip /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli/3.0.0.zip -d /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli && \
    mv /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli/advanced-custom-fields-wpcli-3.0.0/* /var/www/WordPressPre/wp-content/plugins/advanced-custom-fields-wpcli/

# Install needed plugins
RUN wp plugin install --allow-root --path=${wordpresslocation} wordpress-importer --activate && \
    wp plugin install --allow-root --path=${wordpresslocation} rest-api --activate && \
    wp plugin install --allow-root --path=${wordpresslocation} wp-api-menus --activate && \
    wp plugin install --allow-root --path=${wordpresslocation} /var/www/WordPressPre/wp-content/plugins/acf-pro.zip --activate && \
    wp plugin install --allow-root --path=${wordpresslocation} acf-to-rest-api --activate && \
   #wp plugin install --allow-root --path=${wordpresslocation} ssl-insecure-content-fixer --activate && \
    wp plugin activate --allow-root --path=${wordpresslocation} advanced-custom-fields-wpcli

# Install theme
RUN wget https://github.com/dorel/wordpress-theme-dorel-juvenile/archive/${branch}.zip -O ~/theme.zip && \
    unzip ~/theme.zip -d ~ && \
    rm ~/theme.zip && \
    mkdir -p /var/www/WordPressPre/wp-content/themes/dorel.io && \
    mv ~/wordpress-theme-dorel-juvenile-${branch}/* /var/www/WordPressPre/wp-content/themes/dorel.io/ && \
    wp theme activate --allow-root --path=${wordpresslocation} "dorel.io" && \
    wp theme delete --allow-root --path=${wordpresslocation} twentysixteen && \
    wp theme delete --allow-root --path=${wordpresslocation} twentyfifteen && \
    wp theme delete --allow-root --path=${wordpresslocation} twentyseventeen

# Import acf files
RUN wp acf import --allow-root --path=${wordpresslocation} --json_file=${wordpresslocation}/wp-content/themes/dorel.io/acf-exports/home-page-builder.json && \
    wp acf import --allow-root --path=${wordpresslocation} --json_file=${wordpresslocation}/wp-content/themes/dorel.io/acf-exports/info-page-builder.json && \
    wp acf import --allow-root --path=${wordpresslocation} --json_file=${wordpresslocation}/wp-content/themes/dorel.io/acf-exports/marketing-page-builder.json

# Add editor
RUN wp user --allow-root --path=${wordpresslocation} create ${editor_user} ${editor_email} --user_pass="${editor_pass}" --role=editor

# Set nginx config
RUN rm -f /etc/nginx/sites-enabled/default && \
    wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${branch}/subservices/Dorel-Dockerfiles/wordpress-nginx/default -O /etc/nginx/sites-enabled/default

# remove unused things, also remove PHP and wp-cli
RUN apt-get purge wget unzip -qq -y && \
    apt-get autoremove -qq -y && \
    rm -r ${wordpresslocation}/wp-content/themes/dorel.io/acf-exports && \
    rm -r ${wordpresslocation}/wp-content/themes/dorel.io/wp-exports && \
    rm -r ${wordpresslocation}/wp-content/themes/dorel.io/bash

# Expose port 80
EXPOSE 80

# start nginx and php fpm
CMD service php7.1-fpm start && nginx -g "daemon off;"
