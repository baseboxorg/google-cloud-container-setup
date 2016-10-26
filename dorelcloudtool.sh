#!/bin/bash
###############
#
# Bash script for managing the Google Cloud
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
###############

# progress function
function ProgressBar {
  # Process data
  let _progress=(${1}*100/${2}*100)/100
  let _done=(${_progress}*4)/10
  let _left=40-$_done
  # Build progressbar string lengths
  _fill=$(printf "%${_done}s")
  _empty=$(printf "%${_left}s")
  # Print the progress
  printf "\rProgress : [${_fill// /#}${_empty// /-}] ${_progress}%%\n"
}


# Setup the shell
set -e
clear
echo "Setting up Dorel Juvenile Google Cloud setup by @bobvanluijt..."
mkdir -p ~/.cloudshell
touch ~/.cloudshell/no-apt-get-warning
sudo apt-get -qq -y update
sudo apt-get -qq -y install dialog

# Setup input fields
HEIGHT=25
WIDTH=80
CHOICE_HEIGHT=5
BACKTITLE="Dorel.io SETUP"
TITLE="Dorel.io SETUP"

# Ask project ID
MENU="Select you project ID:"
OPTIONS=(1 "Dorel.io Develop (dorel-io-dev)"
         2 "Dorel.io Production (dorel-io)"
         3 "Dorel.io NEW PROJECT"
         4 "I don't know what I'm doing...")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            PROJECTID=$(echo dorel-io-dev)
            ;;
        2)
            PROJECTID=$(echo dorel-io)
            ;;
        3)
            exec 3>&1;
            PROJECTID=$(dialog --inputbox "Project name with hyphens and small caps (example: this-is-a-test)." 0 0 2>&1 1>&3);
            exitcode=$?;
            exec 3>&-;
            ;;
        4)
            exit 1
            ;;
esac

# Ask: What do you want to do?
MENU="What do you want to do?"
OPTIONS=(1 "Create new worker (only run this when init is done)"
         2 "Initiate setup (only run this when setting up Google Cloud)"
         3 "I don't know what I'm doing...")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            TASK=$(echo create_worker)
            ;;
        2)
            TASK=$(echo init_google_cloud)
            ;;
        3)
            exit 1
            ;;
esac

###
# Run CREATE WORKER task
###
if [[ "$TASK" == "create_worker" ]]
then
	echo INIT CLOUD
fi

###
# Run INIT task
###
if [[ "$TASK" == "init_google_cloud" ]]
then
  
  # Create instance template for worker
  echo $(((100/6)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create template for swarm worker" 10 70 0
  gcloud compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io-docker-worker-template" --machine-type "n1-standard-2" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --tags "https-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-worker-template"
  
  # Create instance template for swarm manager
  echo $(((100/6)*2)) | dialog --gauge "Create template for swarm manager" 10 70 0
  gcloud compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io-docker-manager-template" --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-manager-template"
  
  # Create Swarm Manager
  echo $(((100/6)*3)) | dialog --gauge "Create the Swarm Manager Ubuntu Box" 10 70 0
  gcloud compute --project "${PROJECTID}" instance-groups managed create "dorel-io-docker-swarm-manager" --zone "europe-west1-c" --base-instance-name "dorel-io-docker-swarm-manager" --template "dorel-io-docker-manager-template" --size "1" --description "Dorel IO's Swarm manager"
  
  # Create SQL
  echo $(((100/6)*4)) | dialog --gauge "Create cloud SQL with replica (might take some time)" 10 70 0
  gcloud beta sql --project "${PROJECTID}" instances create "dorel-io-database-001" --tier "db-n1-highmem-4" --activation-policy "ALWAYS" --backup-start-time "01:23" --database-version "MYSQL_5_7" --enable-bin-log --failover-replica-name "dorel-io-database-failover" --gce-zone "europe-west1-c" --maintenance-release-channel "PRODUCTION" --maintenance-window-day "SUN" --maintenance-window-hour "01" --region "europe-west1" --replica-type "FAILOVER" --replication ASYNCHRONOUS --require-ssl --storage-auto-increase --storage-size "50GB" --storage-type "SSD"

  # Create datastore bucket
  echo $(((100/6)*5)) | dialog --gauge "Create storage bucket" 10 70 0
  gsutil mb -p "${PROJECTID}" -c "REGIONAL" -l "europe-west1" "gs://${PROJECTID}-website-content-bucket"

  # Set password
  exec 3>&1;
  SQLPASSWORD1=$(dialog --password "Mysql root password." 0 0 2>&1 1>&3);
  exitcode=$?;
  exec 3>&-;
  echo $(((100/6)*6)) | dialog --gauge "Set mysql root password" 10 70 0
  gcloud sql --project "dorel-io-tester003" instances set-root-password "dorel-io-database-001" --password "
qwerty"

fi