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

# Get the container ID
container=$(docker run -d wordpress-hhvm-gcloud)

# Get the IP
ip=$(docker inspect "$container" | grep -oP "(?<=\"IPAddress\": \")[^\"]+")

# Echo the IP
echo "$ip"