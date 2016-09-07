# Docker setup for multi-Wordpress and HHVM on the Google Cloud setup

## Setup the gateway server

0. Run as root: `sudo su`
1. Go to home folder: `cd ~`
2. Clone this repo: `git clone https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud.git`
3. Go into dir: `cd Docker-multi-wordpress-hhvm-google-cloud`
4. Make the bash files execable: `chmod +x ./*.sh`
5. Setup the gateway by running: `./gateway-setup.sh`

Or exec as one big command: `git clone https://github.com/bobvanluijt/Docker-multi-wordpress-hhvm-google-cloud.git && cd Docker-multi-wordpress-hhvm-google-cloud && chmod +x ./*.sh && ./gateway-setup.sh`

## Setup a new Wordpress container

1. Run: `./container-setup.sh website.com dbhost_ip dbname_to_create dbuser_to_create dbpass_to_create dbpass_root`<br>
_Important:<br>
- only add the domainname with the top level domain and without www. for example: foobar.nl_
- `dbhost_ip` = ip address of SQL server
- `db_name_to_create` = the unique database name that should be created
- `dbuser_to_create` = the unique database user that should be created
- `dbpass_to_create` = the unique database user password that should be created
- `dbpass_root` = the database password of the root user
