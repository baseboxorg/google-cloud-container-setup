# Docker setup for multi-Wordpress on the Google Cloud and CDN locations setup

This setup will create lightning fast Wordpress installations on Google Cloud. This setup is not limited to only one solution.

## Setup the gateway server

0. Run as root: `sudo su`
1. Install unzip: `apt-get update && apt-get install unzip -qq -y`
2. Go to home folder: `cd ~`
3. Get this repo: `wget https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud/archive/master.zip`
4. Unzip: `unzip master.zip`
4. Remove master zip file: `rm master.zip`
4. Go into dir: `cd Docker-multi-wordpress-hhvm-google-cloud-master`
5. Make the bash files execable: `chmod +x ./*.sh`
6. Setup the gateway by running: `./gateway-setup.sh`

Or exec as one big command: `apt-get update && apt-get install unzip -qq -y && cd ~ && wget https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud/archive/master.zip && unzip master.zip && rm master.zip && cd Docker-multi-wordpress-hhvm-google-cloud-master && chmod +x ./*.sh && ./gateway-setup.sh`

## Create a new Wordpress Container
Create database, nginx proxy files, etcetera.

1. Run: `./container-setup.sh`<br>
_Add the following items, the script will not run without these_
- `--website` = website without www. For example: test.com
- `--accessurl` = url that will be used to access the website.
- `--dbhost` = hostname or ip of the database
- `--dbname` = name of the Wordpress database
- `--dbuser` = username for the Wordpress database
- `--dbpass` = password for the Wordpress database
- `--title` = the website title
- `--adminemail` = email of the admin
- `--adminuser` = admin username
- `--adminpass` = admin pass

Example:<br>
./container-setup.sh --website test.com --accessurl www.test.com --dbhost 1.2.3.4 --dbname test --dbuser test --dbpass test567 --title Example --adminemail test@test.com --adminuser admin --adminpass test123

## Delete a container
Removes database, nginx proxy files, etcetera.

1. Run: `./container-remove.sh -c CONTAINER_ID`

You can find the container id by running `docker ps`.

Please note that you should always add containers by using `container-setup.sh` and remove them by using `container-remove.sh`.
