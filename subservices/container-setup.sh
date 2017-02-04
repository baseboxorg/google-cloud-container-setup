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
    -e|--editoremail)
    EDITOREMAIL="$2"
    shift # past argument
    ;;
    -U|--editoruser)
    EDITORUSER="$2"
    shift # past argument
    ;;
    -ep|--editorpass)
    EDITORPASS="$2"
    shift # past argument
    ;;
    -ap|--adminpass)
    ADMINPASS="$2"
    shift # past argument
    ;;
    -br|--branch)
    BRANCH="$2"
    shift # past argument
    ;;
esac
shift # past argument or value
done

###
# Validate if needed arguments are available
###
if [ -z ${WEBSITE} ];     then echo "-w or --website is unset | abort";    exit 1; fi
if [ -z ${ACCESSURL} ];   then echo "-W or --accessurl is unset | abort";  exit 1; fi
if [ -z ${TITLE} ];       then echo "-t or --title is unset | abort";      exit 1; fi
if [ -z ${EDITOREMAIL} ]; then echo "-e or --editoremail is unset | abort"; exit 1; fi
if [ -z ${EDITORUSER} ];  then echo "-U or --editoruser is unset | abort";  exit 1; fi
if [ -z ${EDITORPASS} ];  then echo "-ep or --editorpass is unset | abort"; exit 1; fi
if [ -z ${ADMINPASS} ];   then echo "-ap or --adminpass is unset | abort"; exit 1; fi
if [ -z ${BRANCH} ];      then echo "-br or --branch is unset | abort";    exit 1; fi

###
# Create or select all DB related info
###
DBINFO=$(cat ~/.my.cnf)
DBHOST=${DBINFO#*host = }
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
if ! echo ${ACCESSURL} | grep -q -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$"; then
    echo "ERROR - This domain name looks not to be valid. Is formatted subdomain.domain.toplevel? Like www.foobar.c
om? An IP is not valid."
    exit 1
fi

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

# Install deps
apt-get install jq -qq -y

# mkdir for logging
mkdir -p /var/log/wordpress-gcloud

# Go HOME
cd ~

# Download data from repo, remove if it is already there
rm -rf ~/container-setup >> /var/log/wordpress-gcloud/${ACCESSURL}.log
mkdir ~/container-setup >> /var/log/wordpress-gcloud/${ACCESSURL}.log
wget https://github.com/baseboxorg/google-cloud-container-setup/archive/${BRANCH}.zip -O ~/container-setup.zip >> /var/log/wordpress-gcloud/${ACCESSURL}.log
unzip ~/container-setup.zip -d ~/container-setup >> /var/log/wordpress-gcloud/${ACCESSURL}.log
rm ~/container-setup.zip >> /var/log/wordpress-gcloud/${ACCESSURL}.log
mv ~/container-setup/google-cloud-container-setup-${BRANCH}/* ~/container-setup >> /var/log/wordpress-gcloud/${ACCESSURL}.log

###
# Start the creation process SPA
###

# Build spa container
docker build -t spa-gcloud -f ~/container-setup/subservices/Dorel-Dockerfiles/spa/Dockerfile --build-arg wpapi=${WPACCESSURL} --build-arg branch=${BRANCH} . >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Exec spa container
container=$(docker run -d spa-gcloud) >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Get container IP
ip=$(docker inspect "$container" | jq -r '.[0].NetworkSettings.IPAddress') >> /var/log/wordpress-gcloud/${ACCESSURL}.log

# Add to acces url setup
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/${ACCESSURL}
touch /etc/nginx/sites-enabled/${ACCESSURL}
echo "server {" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    server_name ${ACCESSURL};" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    location / {" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header X-Forwarded-Host $host;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header X-Forwarded-Server $host;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header X-Forwarded-Proto $scheme;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo '        proxy_set_header Host $host;' >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "        proxy_pass http://$ip;" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "    }" >> /etc/nginx/sites-enabled/${ACCESSURL}
echo "}" >> /etc/nginx/sites-enabled/${ACCESSURL}

###
# Start the creation process WORDPRESS (note = https loadbalancing)
###

## mkdir for wp-content
mkdir -m 777 -p /var/wordpress-content/${WPACCESSURL}

## Create mySQL instance with new users
mysql -e "CREATE DATABASE IF NOT EXISTS ${DBNAME} ; GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'%' IDENTIFIED BY '${DBPASS}'" >> /var/log/wordpress-gcloud/${ACCESSURL}.log

## Build from the Dockerfile based on the env variables
docker build -f ~/container-setup/subservices/Dorel-Dockerfiles/wordpress-nginx/Dockerfile -t wordpress-gcloud --build-arg site_title="${TITLE}" --build-arg editor_email="${EDITOREMAIL}" --build-arg site_url="${ACCESSURL}" --build-arg editor_user="${EDITOREMAIL}" --build-arg editor_pass="${EDITORPASS}" --build-arg admin_pass="${ADMINPASS}" --build-arg dbname="${DBNAME}" --build-arg dbuser="${DBUSER}" --build-arg dbpass="${DBPASS}" --build-arg dbhost="${DBHOST}" --build-arg branch="${BRANCH}" .

## Build container, get the container ID and connect the dirs
containerWp=$(docker run -v ${WPACCESSURL}:/var/www/WordPress -d wordpress-gcloud) >> /var/log/wordpress-gcloud/${ACCESSURL}.log
docker exec ${containerWp} /bin/sh -c "mv -v /var/www/WordPressPre /var/www/WordPress" >> /var/log/wordpress-gcloud/${ACCESSURL}.log

## Set the load balancer settings
# mysql -e "INSERT INTO ${DBNAME}.wp_options (option_value, option_name) VALUES ('a:3:{s:9:\"fix_level\";s:6:\"simple\";s:9:\"proxy_fix\";s:22:\"HTTP_X_FORWARDED_PROTO\";s:12:\"fix_specific\";a:1:{s:9:\"woo_https\";i:1;}}', 'ssl_insecure_content_fixer');"

## Get the IP of the newly created container
ipWp=$(docker inspect "$containerWp" | jq -r '.[0].NetworkSettings.IPAddress') >> /var/log/wordpress-gcloud/${ACCESSURL}.log

## Create nginx setup
rm -f /etc/nginx/sites-enabled/${WPACCESSURL}
touch /etc/nginx/sites-enabled/${WPACCESSURL}
echo "server {" >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo "    server_name ${WPACCESSURL};" >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo "    location / {" >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header X-Forwarded-Host $host;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header X-Forwarded-Server $host;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header X-Forwarded-Proto $scheme;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo '        proxy_set_header Host $host;' >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo "        proxy_pass https://$ip;" >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo "    }" >> /etc/nginx/sites-enabled/${WPACCESSURL}
echo "}" >> /etc/nginx/sites-enabled/${WPACCESSURL}

# Reload nginx (note NOT restart, we don't want to disturb existing users)
service nginx reload

# Echo the IP AND ADD THIS TO THE CONFIG FILES
echo "{ \"SPA\": { \"dockerId\": \"${container}\", \"IP\": \"${ip}\" }, \"WP\": { \"dockerId\": \"${containerWp}\", \"IP\": \"${ipWp}\" }, \"FPM\": { \"dockerId\": \"${FPMCONTAINER}\", \"IP\": \"${FPMCONTAINERIP}\" }, \"LOG\": \"/var/log/wordpress-gcloud/${ACCESSURL}.log\"}" > '/root/.latestSetup.json'
