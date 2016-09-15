################################
# Docker setup for Wordpress in multiple container setup by @bobvanluijt
################################

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

# Update the repository sources list
RUN apt-get update -qq -y

# Install security updates
RUN apt-get unattended-upgrades -qq -y

# Install apt-utils
RUN apt-get install apt-utils unzip wget nginx mysql-client -qq -y

# remove HTML dir
RUN rm -r /var/www/html

# install PHP7
RUN apt-get install php7.0-fpm php7.0-mysql php7.0-mcrypt php-mbstring php-gettext -qq -y && \
    phpenmod mcrypt && \
    phpenmod mbstring

# Install wp-cli
RUN wget -q -nv https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P ~ && \
    chmod +x ~/wp-cli.phar && \
    mv ~/wp-cli.phar /usr/local/bin/wp
 
# Download Wordpress
RUN wget -q -nv -P /var/www https://github.com/WordPress/WordPress/archive/4.6-branch.zip && \
    unzip -q /var/www/4.6-branch.zip -d /var/www && \
    mv /var/www/WordPress-4.6-branch /var/www/WordPress && \
    rm /var/www/4.6-branch.zip

# Config Wordpress
RUN wp core config --path=/var/www/WordPress --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=${dbhost} --allow-root

# Install Wordpress (ADD USERNAME AND PASSWORD LATER)
RUN wp core install --allow-root --path=/var/www/WordPress --url=${site_url} --title=${site_title} --admin_user=${admin_user} --admin_password=${admin_pass} --admin_email=${admin_email}

# Install super cache, first set chmod 777 and set back later
RUN chmod 777 /var/www/WordPress/wp-config.php && \
    chmod 777 /var/www/WordPress/wp-content && \
    wp plugin install wp-super-cache --path=/var/www/WordPress --activate --allow-root && \
    chmod 755 /var/www/WordPress/wp-config.php && \
    chmod 755 /var/www/WordPress/wp-content
   
# Set nginx config
RUN rm /etc/nginx/sites-enabled/default
ADD default /etc/nginx/sites-enabled/default
   
# Install letsencrypt
RUN apt-get install letsencrypt -qq -y

# setup the script
# RUN letsencrypt certonly --webroot -w /var/www/WordPress -d ${ssl_domain} -d www.${ssl_domain}

# remove unused things
RUN apt-get purge wget -qq -y && \
    apt-get autoremove -qq -y

# Expose port 80 and 443
EXPOSE 80
EXPOSE 443

# start PHP FPM
ENTRYPOINT ["/usr/sbin/php-fpm7.0", "-c"]

# start nginx
CMD ["nginx", "-g", "daemon off;"]
