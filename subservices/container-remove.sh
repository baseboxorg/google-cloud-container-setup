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
    -c|--container)
    CONTAINER="$2"
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
if [ -z ${CONTAINER} ];    then echo "-c or --container is unset | abort";    exit 1; fi

###
# Start removal
###

# Get all env variables used during setup
CONFIG=$(docker inspect "${CONTAINER}" | jq '.[0].Config.Env')

SITE_URL=$(grep -o 'site_url=[^"]*' <<< "$CONFIG" | cut -d= -f2)
DBUSER=$(grep -o 'dbuser=[^"]*' <<< "$CONFIG" | cut -d= -f2)
DBPASS=$(grep -o 'dbpass=[^"]*' <<< "$CONFIG" | cut -d= -f2)

# remove docker container
docker stop ${CONTAINER}

# remove MYSQL
mysql --login-path=local -e "drop database ${DBNAME}; drop user '${DBUSER}'@'%'"

# Remove nginx config
rm /etc/nginx/sites-enabled/${SITE_URL}
service nginx reload
