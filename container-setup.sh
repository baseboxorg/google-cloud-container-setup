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

# Create mySQL instance with new users
# mysql --host=$2 --user=root --password=$6 -e "create database $3; GRANT ALL PRIVILEGES ON $3.* TO $4@localhost IDENTIFIED BY '$5'"
mysql --host=$2 --user=root --password=$6 -e "create database $3; GRANT ALL PRIVILEGES ON $3.* TO '$4'@'%' IDENTIFIED BY '$5'"

# Build from the Dockerfile based on the env variables
docker build -t wordpress-gcloud --build-arg ssl_domain=$1 --build-arg dbhost=$2 --build-arg dbname=$3 --build-arg dbuser=$4 --build-arg dbpass=$5 --build-arg site_title=$6 --build-arg admin_email=$7 --build-arg site_url=$8 --build-arg admin_user=$9 --build-arg admin_pass=$10 .

# Get the container ID
container=$(docker run -d wordpress-gcloud)

# Get the IP
ip=$(docker inspect "$container" | grep -oP "(?<=\"IPAddress\": \")[^\"]+")

# Echo the IP
echo "$ip"
