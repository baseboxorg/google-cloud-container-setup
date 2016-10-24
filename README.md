# Wordpress and Magento 2 Docker Swarm setup for Google Cloud.

This setup will create Wordpress and Magento 2 installations on the Google Cloud infra using Docker Swarm

Learn more about Google's infra: https://peering.google.com/#/infrastructure

## Setup Google Cloud
This setup will guide you through the setup of the Google Cloud. You can also use Google's REST API or `gcloud` to achieve the same end-goal.

CREATE INSTANT TEMPLATE FIRST

MANAGER = INSTANCE GROUP OF ONE, REST IS NORMAL, DON'T FORGET TO SET ACCESS TO SQL API and DISABLE EXTERNAL IPS

You can use the following steps to create new Docker managers or workers.

### Create worker template
`gcloud compute --project "dorel-io" instance-templates create "dorel-io-docker-worker-template" --machine-type "n1-standard-2" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --tags "https-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-worker-template"`

_Note: external IP will be provided by default, for production you need to disable this_

### Create manager template
`gcloud compute --project "dorel-io" instance-templates create "dorel-io-docker-manager-template" --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-manager-template"`

_Note: external IP will be provided by default, for production you need to disable this_

### Create machine based on manager template
`gcloud compute --project "dorel-io" instance-groups managed create "dorel-io-docker-manager" --zone "europe-west1-c" --base-instance-name "dorel-io-docker-manager" --template "dorel-io-docker-manager-template" --size "1"`

### Create machine based on worker template
`gcloud compute --project "dorel-io" instance-groups managed create "dorel-io-docker-worker-001" --zone "europe-west1-c" --base-instance-name "dorel-io-docker-worker-001" --template "dorel-io-docker-worker-template" --size "1"`

_Note: Set the `--base-instance-name` in increasements like:  dorel-io-docker-worker-001, dorel-io-docker-worker-002 etc._

## Setup the swarm manager

Log into the manager machine.

0. Run as root: `sudo su`
1. Install unzip: `apt-get update && apt-get upgrade -qq -y && apt-get install unzip -qq -y`
2. Go to home folder: `cd ~`
3. Get this repo: `wget https://github.com/dorel/google-cloud-container-setup/archive/master.zip`
4. Unzip: `unzip master.zip`
4. Remove master zip file: `rm master.zip`
4. Go into dir: `cd google-cloud-container-setup`
5. Make the bash files execable: `chmod +x ./*.sh`
6. Setup the gateway by running: `./host-manager-setup.sh`
7. The setup will ask for the database host (the ip of the DB)
8. The setup will ask for the INTERNAL host of this machine.
9. The setup will ask for the database root password, you need to type this for security reasons

_note: make sure to save the Docker Swarm output. This output contains a token to setup your swarm_

Or exec as one big command: `apt-get update && apt-get upgrade -qq -y && apt-get install unzip -qq -y && cd ~ && wget https://github.com/dorel/google-cloud-container-setup/archive/master.zip && unzip master.zip && rm master.zip && cd google-cloud-container-setup && chmod +x ./*.sh && ./host-manager-setup.sh`

When the setup is done, you can create a container as mentioned below.

## Setup swarm nodes

_Note: you can run this command on every node you want to create, also when a node is full and you want to extend the platform_

Log into the worker machine

0. Run as root: `sudo su`
1. Install unzip: `apt-get update && apt-get upgrade -qq -y && apt-get install unzip -qq -y`
2. Go to home folder: `cd ~`
3. Get this repo: `wget https://github.com/dorel/google-cloud-container-setup/archive/master.zip`
4. Unzip: `unzip master.zip`
4. Remove master zip file: `rm master.zip`
4. Go into dir: `cd google-cloud-container-setup`
5. Make the bash files execable: `chmod +x ./*.sh`
6. Setup the gateway by running: `./host-worker-setup.sh`
7. The script will ask for the swarm join token. This will be something like: `SWMTKN-1-2tfvrs35ut89vwrbxxju84jmazhpro0jp0o3asgqwywo6qg4d-acqf993urf3cawjd18jbvus`, you have received it when setting up the swarm manager.
8. The script will ask for the swarm manager IP. This needs to be the INTERNAL ip.

## Create a new Wordpress Container
Create database, nginx proxy files, etcetera.

_Note, make sure the domainname you are about to setup, has DNS A-records set to the IP of the load balancer_

1. Run: `./container-setup.sh`<br>
_Add the following items, the script will not run without these_
- `--website` = website without www. For example: test.com
- `--accessurl` = url that will be used to access the website.
- `--title` = the website title
- `--adminemail` = email of the admin
- `--adminuser` = admin username
- `--adminpass` = admin pass

Example:<br>
`./container-setup.sh --website test.com --accessurl www.test.com --title Example --adminemail test@test.com --adminuser admin --adminpass test123`

_note I: this process might take a while when a completely new docker container is being created._
_note II: databases and logins and passes are created automatically_

## Configurate the loadbalancer to access your website
1. Login to the Google Cloud console and select your project https://console.cloud.google.com
2. Go into: Networking -> Load balancing
3. Select the loadbalancer and click 'edit'
4. Select 'Host and path rules'
5. Add a host path rule:
  5.1 Hosts: the hostname you added as `--accessurl` in the previous step.
  5.2 Paths: the path to access your website, often just `/` also, add an asterix after the path: `/*`
  5.3 Backend Service: Select the backend service

_Note: It might take some time before your CDN is up, give it about 30 sec..._

## Delete a container
Removes database, nginx proxy files, etcetera.

1. Run: `./container-remove.sh -c CONTAINER_ID`

You can find the container id by running `docker ps`.

Please note that you should always add containers by using `container-setup.sh` and remove them by using `container-remove.sh`.
