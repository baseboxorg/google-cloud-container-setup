###############
#
# Docker setup for php-fpm to run PHP7
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
###############

FROM phpdockerio/php71-cli

# File Author / Maintainer
MAINTAINER Bob van Luijt

# Install FPM
RUN apt-get update \
    && apt-get -y --no-install-recommends install php7.1-fpm php7.1-cli php7.1-mysql php7.1-curl php7.1-json php7.1-mcrypt php7.1-opcache php7.1-readline php7.1-xml php7.1-zip php-mbstring php7.1-mbstring \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
# Configure FPM to run properly on docker
RUN sed -i "/listen = .*/c\listen = [::]:9000" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "/;access.log = .*/c\access.log = /proc/self/fd/2" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "/;clear_env = .*/c\clear_env = no" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "/;catch_workers_output = .*/c\catch_workers_output = yes" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "/pid = .*/c\;pid = /run/php/php7.1-fpm.pid" /etc/php/7.1/fpm/php-fpm.conf \
    && sed -i "/;daemonize = .*/c\daemonize = no" /etc/php/7.1/fpm/php-fpm.conf \
    && sed -i "/error_log = .*/c\error_log = /proc/self/fd/2" /etc/php/7.1/fpm/php-fpm.conf \
    && usermod -u 1000 www-data
# The following runs FPM and removes all its extraneous log output on top of what your app outputs to stdout
CMD /usr/sbin/php-fpm7.1 -F -O 2>&1 | sed -u 's,.*: \"\(.*\)$,\1,'| sed -u 's,"$,,' 1>&1
# Open up fcgi port
EXPOSE 9000
