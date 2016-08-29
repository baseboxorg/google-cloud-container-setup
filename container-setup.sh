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

# Get the container ID
container=$(docker run -d wordpress-hhvm-gcloud --build-arg ssl_domain=$1)

# Get the IP
ip=$(docker inspect "$container" | grep -oP "(?<=\"IPAddress\": \")[^\"]+")

# Echo the IP
echo "$ip"