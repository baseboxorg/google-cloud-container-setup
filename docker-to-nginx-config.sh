#!/bin/bash

# Build from the Dockerfile
docker build -t wordpress-hhvm-gcloud .

# Get the container ID
container=$(docker run -d wordpress-hhvm-gcloud)

# Get the IP
ip=$(docker inspect "$container" | grep -oP "(?<=\"IPAddress\": \")[^\"]+")

# Echo the IP
echo "$ip"
