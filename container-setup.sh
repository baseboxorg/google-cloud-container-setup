################################
# Container setup by @bobvanluijt
################################

# Check if url is set
regex='[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [[ $1 != $regex ]]
then 
    echo "No url is setup"
    exit
fi

# Build from the Dockerfile based on the env variables
docker build -t wordpress-hhvm-gcloud .

###
# Setup DB and add arguments to container creation
# echo "create database wordpress" |  mysql --host=[IP] --user=[USR] --password=[PASS]
# ALSO ADD USER ONLY FOR THIS DATABASE AND PASS IT BELOW TO THE CONTAINER
# FIX PASS ISSUE
###

# Get the container ID
container=$(docker run -d wordpress-hhvm-gcloud --build-arg ssl_domain=$1 --build-arg dbhost=$2 --build-arg dbname=$3 --build-arg dbuser=$4 --build-arg dbpass=$5)

# Get the IP
ip=$(docker inspect "$container" | grep -oP "(?<=\"IPAddress\": \")[^\"]+")

# Echo the IP
echo "$ip"
