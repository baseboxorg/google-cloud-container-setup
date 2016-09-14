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
    -h|--dbhost)
    DBHOST="$2"
    shift # past argument
    ;;
    -n|--dbname)
    DBNAME="$2"
    shift # past argument
    ;;
    -u|--dbuser)
    DBUSER="$2"
    shift # past argument
    ;;
    -p|--dbpass)
    DBPASS="$2"
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
if [ -z ${DBHOST} ];     then echo "-h or --dbhost is unset | abort";     exit 1; fi
if [ -z ${DBNAME} ];     then echo "-n or --dbname is unset | abort";     exit 1; fi
if [ -z ${DBUSER} ];     then echo "-u or --dbuser is unset | abort";     exit 1; fi
if [ -z ${DBPASS} ];     then echo "-p or --dbpass is unset | abort";     exit 1; fi
if [ -z ${TITLE} ];      then echo "-t or --title is unset | abort";      exit 1; fi
if [ -z ${ADMINEMAIL} ]; then echo "-e or --adminemail is unset | abort"; exit 1; fi
if [ -z ${ADMINUSER} ];  then echo "-U or --adminuser is unset | abort";  exit 1; fi
if [ -z ${ADMINPASS} ];  then echo "-ap or --adminpass is unset | abort"; exit 1; fi

###
# Start the creation process
###

# mkdir for logging
mkdir -p /var/log/wordpress-gcloud

# Create mySQL instance with new users
mysql --login-path=local -e "create database ${DBNAME}; GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'%' IDENTIFIED BY '${DBPASS}'" >> /var/log/wordpress-gcloud/${WEBSITE}.log

# Build from the Dockerfile based on the env variables
docker build -t wordpress-gcloud --build-arg ssl_domain=${ACCESSURL} --build-arg dbhost=${DBHOST} --build-arg dbname=${DBNAME} --build-arg dbuser=${DBUSER} --build-arg dbpass=${DBPASS} --build-arg site_title=${TITLE} --build-arg admin_email=${ADMINEMAIL} --build-arg site_url=${ACCESSURL} --build-arg admin_user=${ADMINUSER} --build-arg admin_pass=${ADMINPASS} . >> /var/log/wordpress-gcloud/${WEBSITE}.log

# Get the container ID
container=$(docker run -d wordpress-gcloud) >> /var/log/wordpress-gcloud/${WEBSITE}.log

# Get the IP of the newly created container
ip=$(docker inspect "$container" | jq -r '.[0].NetworkSettings.IPAddress') >> /var/log/wordpress-gcloud/${WEBSITE}.log

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
