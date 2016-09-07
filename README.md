# Docker setup for multi-Wordpress and HHVM on the Google Cloud setup

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

## Setup a new Wordpress container

1. Run: `./container-setup.sh website.com dbhost_ip dbname_to_create dbuser_to_create dbpass_to_create dbpass_root`<br>
_Important:<br>
- only add the domainname with the top level domain and without www. for example: foobar.nl_
- `dbhost_ip` = ip address of SQL server
- `db_name_to_create` = the unique database name that should be created
- `dbuser_to_create` = the unique database user that should be created
- `dbpass_to_create` = the unique database user password that should be created
- `dbpass_root` = the database password of the root user
