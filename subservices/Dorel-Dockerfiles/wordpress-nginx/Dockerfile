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
ARG admin_email
ENV admin_email ${admin_email}
ARG site_url
ENV site_url ${site_url}
ARG admin_user
ENV admin_user ${admin_user}
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
ARG fpmip
ENV fpmip ${fpmip}

# Update the repository sources list
RUN apt-get update -qq -y

# Install tools
RUN apt-get install mysql-client nginx wget curl -qq -y

# Install PHP 7.1
RUN echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu xenial main" > /etc/apt/sources.list.d/ondrej-php.list \
    && echo "deb http://ppa.launchpad.net/ondrej/php-qa/ubuntu xenial main" > /etc/apt/sources.list.d/ondrej-php-qa.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    && apt-get update \
    && apt-get -y --no-install-recommends install php7.1-cli php7.1-curl \
        php7.1-json php7.1-mcrypt php7.1-opcache php7.1-readline php7.1-xml php7.1-zip php-mbstring php7.1-mbstring \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
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
    mkdir -p /var/www/WordPress && \
    wp core download --path=/var/www/WordPress --allow-root

# Config Wordpress
RUN wp core config --path=/var/www/WordPress --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=${dbhost} --allow-root

# Install Wordpress (ADD USERNAME AND PASSWORD LATER)
RUN wp core install --allow-root --path=/var/www/WordPress --url=${site_url} --title=${site_title} --admin_user=${admin_user} --admin_password=${admin_pass} --admin_email=${admin_email}

# Install super cache, first set chmod 777 and set back later
RUN chmod 777 /var/www/WordPress/wp-config.php && \
    chmod 777 /var/www/WordPress/wp-content

# Set nginx config
RUN rm -f /etc/nginx/sites-enabled/default && \
    wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${branch}/subservices/Dorel-Dockerfiles/wordpress-nginx/default -O /etc/nginx/sites-enabled/default && \
    sed -i -e "s/FPM_SERVER_IP_ADDRESS/${fpmip}/g" /etc/nginx/sites-enabled/default

# remove unused things, also remove PHP and wp-cli
RUN apt-get purge wget -qq -y && \
    apt-get autoremove -qq -y

# Expose port 80
EXPOSE 80

# start nginx
CMD nginx -g "daemon off;"
