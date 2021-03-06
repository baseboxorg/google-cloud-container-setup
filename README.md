# Wordpress and Magento 2 Docker setup for Google Cloud.

This set of bash scripts creates the Dorel IO infrastructure which includes but is not limited to:
- Docker
- SQL
- Storage buckets
- Compute machines
- Let's Encrypt
- Wordpress
- Magento

Learn more about Google's infra: https://peering.google.com/#/infrastructure

## Core principle

Within a Google project a sub-project is created which can be identified by the `dorel-io--projectname-*` prefix.
All information about this setup is stored in the config storage bucket.

_Note: You will have two types of projects: I. The Google Cloud project and (II) the sub-project id. You can create multiple sub-projects inside a Google Project._

_Note: This script is a tool to chain commands, not a cloud application, you need to always validate its output_

## Getting started

1. Go to the Google Cloud console.
2. Open the terminal window.
3. Create a new machine to run the cloud tool: `$ gcloud compute --project "dorel-io-dev" instances create "gcloud-terminal" --zone "europe-west1-c" --machine-type "f1-micro" --subnet "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/cloud-platform" --tags "https-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161115" --boot-disk-size "10" --boot-disk-type "pd-standard" --boot-disk-device-name "gcloud-terminal"`
4. SSH into the new machine and go to the home dir `$ cd ~`
5. Run `$ sudo su`
6. Download the core bash file `$ wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/develop/dorelcloudtool.sh`
7. Set permissions `$ chmod +x ./dorelcloudtool.sh`
8. Run `$ ./dorelcloudtool.sh`
9. First `gcloud` will run, make sure to login with your Google Cloud credentials
10. When running for the first time on a new machine, make sure to run the Route 53 Authentication command!

_Note I: to use the tool from another branche change 'master' into -for example- 'develop' in the download url_

_Note II: All debug info will be stored in: `/var/log/dorel/debug.log`_

## Starting the software

1. Fill in the Google Cloud project id.
2. Select the Github branch that you want to work from (this is the installation bash, docker and config files repo).
3. Select what you want to do.

After a process is done, the software will terminate.


## Creating a new Docker project (Option 5)

When creating a new sub project (including general SQL and bucket setup) you need to run this command.

1. Select the instances you would like to generate the templates for.
2. Save the name of the project. This is always in the `xxx-yyy` format.
3. Enter the SQL root password. _Note: this is the only config setting which -for security reasons- is not saved in the config file_.
