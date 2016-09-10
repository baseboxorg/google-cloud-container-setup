# Docker setup for multi-Wordpress on the Google Cloud and CDN locations setup

This setup will create lightning fast Wordpress installations on Google Cloud. This setup is not limited to only one solution.

## Setup Google Cloud
This setup will guide you through the setup of the Google Cloud. You can also use Google's REST API or `gcloud` to achieve the same end-goal.

1. Login to the Google Cloud console and select your project https://console.cloud.google.com
2. Go into: Compute Engine -> Instance groups
3. Create a group with the following settings:
  3.1 Single Zone<br>
  3.2 Instance template, create a new template (or select this one if you already defined this)<br>
    3.2.1 Select a machine that is optimised on CPU.<br>
    3.2.2 Boot Disk is Ubuntu 16.04 LTS<br>
    3.2.3 Only allow HTTPS access<br>
    3.2.4 Select SSD Bootdisk<br>
  3.2 Autoscaling = off<br>
  3.3 Number of instances = 1<br>
  3.4 No Health Check<br>
  3.5 Under advanced: check "Do not retry machine creation.".
4. Go to SQL in the menu
5. Create a second generation instance
  5.1 Select Mysql 5.7<br>
  5.2 Select the _exact same_ region as your VM<br>
  5.3 Select SSD<br>
  5.4 Enable auto storage increasement<br>
  5.5 Create failover replica<br>
  5.6 Click "Add Network and add the IP of the newly created VM 
6. Go to Networking in the menu.
7. Go to Load balancing and create a new HTTP(S) Load Balancer
8. Create a backend service
  8.1 Select the instance group from above<br>
  8.2 Set the ports to 80 and 443<br>
  8.3 Set Maximum CPU utilization to 100<br>
  8.4 Create a health check that checks every 3600 seconds <br>
  8.5 Enable the cloud CDN
9. In Frontend Configuration, create an IP and assign it for both http and https.
10. Add a certificate if you use https.

SSH into the VM that is created and setup the gateway server as mentioned below.

## Setup the proxy server

0. Run as root: `sudo su`
1. Install unzip: `apt-get update && apt-get install unzip -qq -y`
2. Go to home folder: `cd ~`
3. Get this repo: `wget https://github.com/bobvanluijt/Docker-multi-wordpress-google-cloud/archive/master.zip`
4. Unzip: `unzip master.zip`
4. Remove master zip file: `rm master.zip`
4. Go into dir: `cd Docker-multi-wordpress-google-cloud-master`
5. Make the bash files execable: `chmod +x ./*.sh`
6. Setup the gateway by running: `./proxy-setup.sh`
7. The setup will ask for the database host (the ip of the DB)
8. The setup will ask for the database root password, you need to type this for security reasons

Or exec as one big command: `apt-get update && apt-get install unzip -qq -y && cd ~ && wget https://github.com/bobvanluijt/Docker-multi-wordpress-google-cloud/archive/master.zip && unzip master.zip && rm master.zip && cd Docker-multi-wordpress-google-cloud-master && chmod +x ./*.sh && ./proxy-setup.sh`

When the setup is done, you can create a container as mentioned below.

## Create a new Wordpress Container
Create database, nginx proxy files, etcetera.

_Note, make sure the domainname you are about to setup, has DNS A-records set to the IP of the load balancer_

1. Run: `./container-setup.sh`<br>
_Add the following items, the script will not run without these_
- `--website` = website without www. For example: test.com
- `--accessurl` = url that will be used to access the website.
- `--dbhost` = hostname or ip of the database
- `--dbname` = unique name of the Wordpress database (this database should not exist)
- `--dbuser` = unique username for the Wordpress database
- `--dbpass` = unique password for the Wordpress database
- `--title` = the website title
- `--adminemail` = email of the admin
- `--adminuser` = admin username
- `--adminpass` = admin pass

Example:<br>
./container-setup.sh --website test.com --accessurl www.test.com --dbhost 1.2.3.4 --dbname test --dbuser test --dbpass test567 --title Example --adminemail test@test.com --adminuser admin --adminpass test123

_note: this process might take a while when a completely new docker container is being created. Advice, grab a 🍷, 🍸, 🍾, and/or 🍺_

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
