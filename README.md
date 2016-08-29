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

1. Run: `./container-setup.sh website.com` _Important: only add the domainname with the top level domain and without www. for example: foobar.nl_