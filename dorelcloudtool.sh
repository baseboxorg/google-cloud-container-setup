#!/bin/bash
###############
#
# Bash script for managing the Google Cloud
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
###############

# function to create Passwords
function GeneratePassword {
    # Get first time
    exec 3>&1;
    PASSWORD1=$(dialog --passwordbox "Mysql root password\n(make sure to store this password!)." 0 0 2>&1 1>&3);
    exitcode=$?;
    exec 3>&-;

    # Get second time to validate
    exec 3>&1;
    PASSWORD2=$(dialog --passwordbox "Mysql root password again." 0 0 2>&1 1>&3);
    exitcode=$?;
    exec 3>&-;

    echo "${PASSWORD1} and ${PASSWORD2}"
    if [ "${PASSWORD1}" != "${PASSWORD2}" ]; then
        GeneratePassword
    fi
}

# function generate an internal IP (CIDR range = 10.132.0.0/20)
function GenerateIp {
    RANDOMIP=10.132.$((0 + RANDOM % 16)).$((1 + RANDOM % 256))
}

# create a UID
function GenerateUid {
    RANDOMUID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
}

# set the subproject ID
function SetSubProjectId {
    exec 3>&1;
    PROJECTNAME=$(dialog --inputbox "What is the name of the sub-project?" 0 0 2>&1 1>&3)
    exec 3>&-;

    gsutil ls gs://dorel-io--config-bucket/${PROJECTNAME}.json
    if [ $? -eq 0 ]; then
        dialog --msgbox "Loaded sub-project:\n\n${PROJECTNAME}" 0 0
    else
        dialog --msgbox "The project ${PROJECTNAME} does not exist, try again please" 0 0
        SetSubProjectId
    fi 
}

# Setup the shell
set -e
clear
echo "Setting up Dorel Juvenile Google Cloud setup by @bobvanluijt..."
mkdir -p ~/.cloudshell
touch ~/.cloudshell/no-apt-get-warning
sudo apt-get -qq -y update
sudo apt-get -qq -y install dialog jq

# Setup the log file
sudo mkdir -p /var/log/dorel
sudo touch /var/log/dorel/debug.log
sudo chmod 777 /var/log/dorel/debug.log

# Setup input fields
HEIGHT=25
WIDTH=80
CHOICE_HEIGHT=16
BACKTITLE="Dorel.io SETUP"
TITLE="Dorel.io SETUP"

# Ask project ID
exec 3>&1;
PROJECTID=$(dialog --inputbox "What is the Google Project Id?" 0 0 2>&1 1>&3);
exitcode=$?;
exec 3>&-;

# Ask for Git Branch
MENU="What Git Branch do you want to use?"
OPTIONS=(1 "develop"
            2 "master")

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
            GITBRANCH="develop"
            ;;
        2)
            GITBRANCH="master"
            ;;
esac

# Ask: What do you want to do?
MENU="What do you want to do?"
OPTIONS=(1 "New Wordpress installation"
         2 "Recreate Wordpress installation"
         3 "Delete Wordpress installation"
         4 "Create new Docker worker within a Docker project"
         5 "Create a new Docker project")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT 0 $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            TASK=$(echo new_wordpress)
            ;;
        2)
            TASK=$(echo recreate_wordpress)
            ;;
        3)
            TASK=$(echo delete_wordpress)
            ;;
        4)
            TASK=$(echo create_worker)
            ;;
        5)
            TASK=$(echo init_google_cloud)
            ;;
esac

########
########
##
## INSTALLATION PROCESS STARTS HERE
##
########
########

###
# Run CREATE WORKER task
###
if [[ "$TASK" == "create_worker" ]]
then
    # Set the sub-project id
	SetSubProjectId

    # Get a new IP
    GenerateIp
    SWARMWORKERIP=${RANDOMIP}

    # Collect manager type
    MENU="Select a worker type?"
    OPTIONS=("n1-standard-1" "Standard 1 CPU machine type with 1 virtual CPU and 3.75 GB of memory."
             "n1-standard-2" "Standard 2 CPU machine type with 2 virtual CPUs and 7.5 GB of memory."
             "n1-standard-4" "Standard 4 CPU machine type with 4 virtual CPUs and 15 GB of memory.")

    SWARMMANAGERTYPE=$(dialog --clear \
                    --backtitle "$BACKTITLE" \
                    --title "$TITLE" \
                    --menu "$MENU" \
                    $HEIGHT 0 $CHOICE_HEIGHT \
                    "${OPTIONS[@]}" \
                    2>&1 >/dev/tty)

    # Set worker ID
    GenerateUid
    SWARMWORKERID="dorel-io--${PROJECTNAME}--docker-swarm-worker-${RANDOMUID}"

    # Create the worker
    echo $(((100/3)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create a Swarm Worker" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" instances create "${SWARMWORKERID}" --description "Dorel.io Docker Swarm worker" --zone "europe-west1-c" --machine-type "${SWARMMANAGERTYPE}" --subnet "default" --private-network-ip "${SWARMWORKERIP}" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "swarm-manager" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "20" --boot-disk-type "pd-standard" --boot-disk-device-name "swarm-manager" >> /var/log/dorel/debug.log 2>&1

    # Collect the IP of the swarm worker
    gsutil cp gs://dorel-io--config-bucket/${PROJECTNAME}.json ~/${PROJECTNAME}.json
    SWARMTOKEN=$(cat ~/${PROJECTNAME}.json | jq -r '.swarmManager.token')
    SWARMMANAGERIP=$(cat ~/${PROJECTNAME}.json | jq -r '.swarmManager.ip')

    # Connect to worker to the swarm manager
    echo $(((100/3)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Connect the Swarm Worker to the Swarm Manager" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${SWARMWORKERID}" --command "wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/host-worker-setup.sh -O ~/host-worker-setup.sh && chmod +x ~/host-worker-setup.sh && sudo ~/host-worker-setup.sh --swarmip \"${SWARMMANAGERIP}\" --swarmtoken \"${SWARMTOKEN}\"" >> /var/log/dorel/debug.log 2>&1

    # Add worker name to JSON config
    node <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers.push({ "id": "${SWARMWORKERID}", "ip": "${SWARMWORKERIP}" });
        fs.writeFileSync("${PROJECTNAME}.json", JSON.stringify(obj));
EOF
    gsutil cp ~/${PROJECTNAME}.json gs://dorel-io--config-bucket/${PROJECTNAME}.json
    rm ~/${PROJECTNAME}.json

    # Show success message
    dialog --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "The installation of the Swarm Worker is done" 0 0

fi

###
# Run INIT task
###
if [[ "$TASK" == "init_google_cloud" ]]
then
  
  # Give a headsup message
  dialog --pause "During the process you will be asked to create a MYSQL root password and you will get the Swarm Manager information returned. Make sure to store the MYSQL root password and Swarm information in a secure place. It will be needed to setup workers in the future.\n\n\nOutput will be available in: /var/log/dorel/debug.log" 20 0 25

  # Generate project name
  wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/random-nouns.list -O ~/random-nouns.list
  PROJECTNAME=$(shuf -n 1 random-nouns.list)-$(shuf -n 1 random-nouns.list)
  rm random-nouns.list
  dialog --pause "Start generating project:\n\n${PROJECTNAME}" 14 0 25

  # Create instance template for worker
  echo $(((100/9)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create template for swarm worker" 10 70 0
  gcloud --quiet compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io--${PROJECTNAME}--docker-worker-template" --machine-type "n1-standard-2" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --tags "https-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-worker-template" >> /var/log/dorel/debug.log 2>&1
  
  # Create instance template for swarm manager
  echo $(((100/9)*2)) | dialog --gauge "Create template for swarm manager" 10 70 0
  gcloud --quiet compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io--${PROJECTNAME}--docker-manager-template" --machine-type "n1-standard-1" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-manager-template" >> /var/log/dorel/debug.log 2>&1
  
  # Create Swarm Manager
  echo $(((100/9)*3)) | dialog --gauge "Create the Swarm Manager Ubuntu Box" 10 70 0
  GenerateIp
  GenerateUid
  SWARMMANAGERIP=${RANDOMIP}
  SWARMMANAGERID="dorel-io--${PROJECTNAME}--docker-swarm-manager-${RANDOMUID}"
  gcloud --quiet compute --project "${PROJECTID}" instances create "${SWARMMANAGERID}" --description "Dorel.io Docker Swarm manager" --zone "europe-west1-c" --machine-type "n1-standard-1" --subnet "default" --private-network-ip "${SWARMMANAGERIP}" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "swarm-manager" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "20" --boot-disk-type "pd-standard" --boot-disk-device-name "swarm-manager" >> /var/log/dorel/debug.log 2>&1

  # Create SQL
  echo $(((100/9)*4)) | dialog --gauge "Create cloud SQL with replica (might take some time)" 10 70 0
  GenerateUid
  SQLID="dorel-io--${PROJECTNAME}--database-${RANDOMUID}"
  SQLFAILOVERID="dorel-io--${PROJECTNAME}--failover-database-${RANDOMUID}"
  gcloud --quiet beta sql --project "${PROJECTID}" instances create "${SQLID}" --tier "db-n1-highmem-4" --activation-policy "ALWAYS" --backup-start-time "01:23" --database-version "MYSQL_5_7" --enable-bin-log --failover-replica-name "${SQLFAILOVERID}" --gce-zone "europe-west1-c" --maintenance-release-channel "PRODUCTION" --maintenance-window-day "SUN" --maintenance-window-hour "01" --region "europe-west1" --replica-type "FAILOVER" --replication ASYNCHRONOUS --require-ssl --storage-auto-increase --storage-size "50GB" --storage-type "SSD" >> /var/log/dorel/debug.log 2>&1

  # Create datastore bucket
  echo $(((100/9)*5)) | dialog --gauge "Create storage bucket" 10 70 0
  gsutil mb -p "${PROJECTID}" -c "REGIONAL" -l "europe-west1" "gs://dorel-io--${PROJECTNAME}--content-bucket" >> /var/log/dorel/debug.log 2>&1

  # Set password and collect IP
  GeneratePassword
  echo $(((100/9)*6)) | dialog --gauge "Set mysql root password" 10 70 0
  gcloud --quiet sql --project "${PROJECTID}" instances set-root-password "${SQLID}" --password "${PASSWORD1}" >> /var/log/dorel/debug.log 2>&1
  SQLIP=$(gcloud sql --project="${PROJECTID}" --format json instances describe "${SQLID}" | jq -r '.ipAddresses[0].ipAddress')

  # Setup swarm manager inside box
  echo $(((100/9)*7)) | dialog --gauge "Install the Swarm Manager" 10 70 0
  gcloud --quiet compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${SWARMMANAGERID}" --command "wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/host-manager-setup.sh -O ~/host-manager-setup.sh && chmod +x ~/host-manager-setup.sh && sudo ~/host-manager-setup.sh --project \"${PROJECTID}\" --sqlip \"${SQLIP}\" --sqlpass \"${PASSWORD1}\"" >> /var/log/dorel/debug.log 2>&1

  # Collect swarm information 
  echo $(((100/9)*8)) | dialog --gauge "Collect Swarm info" 10 70 0
  SWARMINFO=$(gcloud --quiet compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${SWARMMANAGERID}" --command "cat ~/config-dockerswarm")
  dialog --infobox "Save this information for connecting Swarm workers in the future:\n${SWARMMANAGERID}" 0 0 >> /var/log/dorel/debug.log
  SWARMTOKEN=$(gcloud compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${SWARMMANAGERID}" --command "cat ~/config-dockerswarm")

  # Create the JSON object and Store to bucket
  echo $(((100/9)*9)) | dialog --gauge "Store config to config bucket in file: ${PROJECTNAME}.json" 10 70 0
  PROJECTOBJECT="{ \"projectName\": \"dorel-io--${PROJECTNAME}\", \"projectNameShort\": \"${PROJECTNAME}\", \"swarmManager\": { \"id\": \"${SWARMMANAGERID}\", \"token\": \"${SWARMTOKEN}\", \"ip\": \"${SWARMMANAGERIP}\" }, \"db\": { \"id\": \"${SQLID}\" }, \"workers\": [] }"
  gsutil --quiet mb -p "${PROJECTID}" -c "NEARLINE" -l "europe-west1" "gs://dorel-io--config-bucket" || true
  touch ~/${PROJECTNAME}.json
  echo ${PROJECTOBJECT} > ~/${PROJECTNAME}.json
  gsutil --quiet cp ~/${PROJECTNAME}.json "gs://dorel-io--config-bucket"
  rm ~/${PROJECTNAME}.json

  # Show finish message
  dialog --pause "If you see this message, the initial cloud setup is done. The following object is stored in the config bucket, you might want to store it too.\n\n\n${PROJECTOBJECT}" 20 0 60

fi

# Clear the screen when done
clear