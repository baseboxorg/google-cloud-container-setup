#!/bin/bash
###############
#
# Bash script for creating new Docker containers and NGINX proxys
# Author: Bob van Luijt
# Readme: https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud
#
###############

###
# Load all arguments
###
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -w|--website)
    WEBSITE="$2"
    shift # past argument
    ;;
    -W|--accessurl)
    ACCESSURL="$2"
    shift # past argument
    ;;
    -t|--title)
    TITLE="$2"
    shift # past argument
    ;;
    -e|--adminemail)
    ADMINEMAIL="$2"
    shift # past argument
    ;;
    -U|--adminuser)
    ADMINUSER="$2"
    shift # past argument
    ;;
    -ap|--adminpass)
    ADMINPASS="$2"
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

###
# Validate if needed arguments are available
###
if [ -z ${WEBSITE} ];    then echo "-w or --website is unset | abort";    exit 1; fi
if [ -z ${ACCESSURL} ];  then echo "-W or --accessurl is unset | abort";  exit 1; fi
if [ -z ${TITLE} ];      then echo "-t or --title is unset | abort";      exit 1; fi
if [ -z ${ADMINEMAIL} ]; then echo "-e or --adminemail is unset | abort"; exit 1; fi
if [ -z ${ADMINUSER} ];  then echo "-U or --adminuser is unset | abort";  exit 1; fi
if [ -z ${ADMINPASS} ];  then echo "-ap or --adminpass is unset | abort"; exit 1; fi

###
# Create or select all DB related info
###
#DBINFO=$(mysql_config_editor print --login-path=local)
DBINFO=$(cat ~/.my.cnf)
DBHOST=${DBINFO#*host =}
#DBNAME=$(echo "www.wxs.nl" | tr . _)
DBNAME=$(echo ${ACCESSURL} | tr . _)
DBUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
DBPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Set ACCESSURL for Wordpress API
WPACCESSURL="wrps.api.${ACCESSURL}"




###
# 1. Validate if the domainname is valid (for letsencrypt)
# 2. Validate if it is likely that this setup already exists. This is done by checking the wp-content directory
# 3. Validate if the database with this name already exists
###

# 1. Validate url
[[ $ACCESSURL =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$ ]] || {
    echo "ERROR - This domain name looks not to be valid. Is formatted subdomain.domain.toplevel? Like www.foobar.com? An IP is not valid."
    exit 1
}


# 2. Validate Wordpress dir
if [ -d "/var/wordpress-content/${ACCESSURL}" ]; then
    echo "ERROR - It seems that this website already exists. You can reconnect it or remove it by using the corresponding bash scripts."
    exit 1
fi

# 3. Validate database
VALIDATESQL=`mysqlshow "${VALIDATESQL}" > /dev/null 2>&1 && echo "true" || echo "false"`
if [ "${VALIDATESQL}" == "true" ]; then
    echo "ERROR - It seems that this website already exists. You can reconnect it or remove it by using the corresponding bash scripts."
    exit 1
fi

###
# Start the creation process
###

# mkdir for logging
mkdir -p /var/log/wordpress-gcloud

# mkdir for wp-content
mkdir -m 777 -p /var/wordpress-content/${ACCESSURL}

# Create mySQL instance with new users
mysql --login-path=local -e "create database ${DBNAME}; GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'%' IDENTIFIED BY '${DBPASS}'" >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Build from the Dockerfile based on the env variables
docker build -t wordpress-gcloud --build-arg ssl_domain=${ACCESSURL} --build-arg dbhost=${DBHOST} --build-arg dbname=${DBNAME} --build-arg dbuser=${DBUSER} --build-arg dbpass=${DBPASS} --build-arg site_title=${TITLE} --build-arg admin_email=${ADMINEMAIL} --build-arg site_url=${ACCESSURL} --build-arg admin_user=${ADMINUSER} --build-arg admin_pass=${ADMINPASS} . >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Build container, get the container ID and connect the dirs
container=$(docker run -v /var/wordpress-content/${ACCESSURL}:/var/www/WordPress/wp-content -d wordpress-gcloud) >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Copy the container wp-content data onto the volume
docker exec $container /bin/sh -c "cp -a /var/www/WordPress/wp-content_tmp/. /var/www/WordPress/wp-content/ && rm -R /var/www/WordPress/wp-content_tmp"

# Get the IP of the newly created container
ip=$(docker inspect "$container" | jq -r '.[0].NetworkSettings.IPAddress') >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Create nginx setup
touch /etc/nginx/sites-enabled/${ACCESSURL}
echo "server {" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    server_name ${ACCESSURL};" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    location / {" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "        proxy_pass http://$ip;" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    }" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "}" >> /etc/nginx/sites-enabled/${ACCESSURL}

# Reload nginx (note NOT restart, we don't want to disturb existing users)
service nginx reload

# Echo the IP
echo "done with ip: $ip log saved to /var/log/wordpress-gcloud/${ACCESSURL}.log | success"
