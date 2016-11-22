#!/bin/bash
###############
#
# Bash script for managing the Google Cloud
# Author: Bob van Luijt
# Readme: https://github.com/dorel/google-cloud-container-setup
#
###############

# Setup input fields
HEIGHT=25
WIDTH=80
CHOICE_HEIGHT=16
BACKTITLE="Dorel.io SETUP"
TITLE="Dorel.io SETUP"

# function to create Passwords
function GenerateSqlPassword {
    # Get first time
    exec 3>&1;
    PASSWORD1=$(dialog --passwordbox "Mysql root password." 0 0 2>&1 1>&3);
    exitcode=$?;
    exec 3>&-;

    # Get second time to validate
    exec 3>&1;
    PASSWORD2=$(dialog --passwordbox "Mysql root password again." 0 0 2>&1 1>&3);
    exitcode=$?;
    exec 3>&-;

    echo "${PASSWORD1} and ${PASSWORD2}"
    if [ "${PASSWORD1}" != "${PASSWORD2}" ]; then
        GenerateSqlPassword
    fi
}

# Get Wordpress database
function GetWordpressData {
    WEBSITEACCESSPOINT=""
    TITLE=""
    ADMINEMAIL=""
    # open fd
    exec 3>&1
    # Store data to $VALUES variable
    VALUES=$(dialog --output-separator "," \
            --backtitle "Linux User Managment" \
            --title "Useradd" \
            --form "Create a new user" \
        15 50 0 \
                "Access Url:"    1 1 "$WEBSITEACCESSPOINT" 1 16 40 0 \
                "Website Title:" 2 1 "$TITLE"              2 16 40 0 \
                "Admin Email:"   3 1 "$ADMINEMAIL"         3 16 40 0 \
        2>&1 1>&3)
    exec 3>&-

    set -- "$VALUES" 
    IFS=","; declare -a Array=($*) 
    WEBSITEACCESSPOINT="${Array[0]}" 
    TITLE="${Array[1]}" 
    ADMINEMAIL="${Array[2]}"

    # Validate the URL
    echo $WEBSITEACCESSPOINT | grep -q -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$"
    if [ $? -eq 1 ] ; then
        dialog --msgbox "This (${WEBSITEACCESSPOINT}) is not a valid access url (should be like: www.test.com)" 0 0
        GetWordpressData
    fi

    # Validate email
    echo $ADMINEMAIL | grep -q -P "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"
    if [ $? -eq 1 ] ; then
        dialog --msgbox "This (${ADMINEMAIL}) is not a valid email" 0 0
        GetWordpressData
    fi

}

# Set route 53 keys
function SetRoute53Keys {
    AWSACCESSKEY=""
    AWSSECKEY=""
    # open fd
    exec 3>&1
    # Store data to $VALUES variable
    VALUES=$(dialog --output-separator "," \
            --backtitle "Linux User Managment" \
            --title "Useradd" \
            --form "Create a new user" \
        15 50 0 \
                "Access Key Id:"     1 1 "$AWSACCESSKEY" 1 24 40 0 \
                "Secret Access Key:" 2 1 "$AWSSECKEY"    2 24 40 0 \
        2>&1 1>&3)
    exec 3>&-

    set -- "$VALUES" 
    IFS=","; declare -a Array=($*) 

    mkdir -p ~/.aws
    echo "[default]" > ~/.aws/credentials
    echo "aws_access_key_id=${Array[0]}" >> ~/.aws/credentials
    echo "aws_secret_access_key=${Array[1]}" >> ~/.aws/credentials

    AWSCHECK=$(nodejs <<EOF
        var AWS = require('aws-sdk');
        var route53 = new AWS.Route53();
        route53
            .listHostedZones({}, function(err, data) {
                if (err) {
                    console.log(false);
                } else {
                    console.log(true);
                }
            });
EOF
)

    if [[ "$AWSCHECK" == "false" ]]
    then
        dialog --msgbox "The cloud keys seem to be incorrect, please try again." 0 0
        SetRoute53Keys
    else
        dialog --msgbox "SUCCESS! The script will restart." 0 0
        CURRENTSCRIPT=`basename "$0"`
        bash $CURRENTSCRIPT
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

function GetAndSetCerts {
    # Create certs, this Node script checks if there is access to AWS, finds the hosted zone and runs certbot
nodejs <<EOF
        'use strict';

        var domain = "${CERTDOMAIN}",
            email  = "${CERTEMAIL}";

        var domainSplit = domain.split('.');

        var topDomain = domainSplit[domainSplit.length-2]+'.'+domainSplit[domainSplit.length-1],
            AWS       = require('aws-sdk'),
            route53   = new AWS.Route53(),
            spawn     = require( 'child_process' ).spawn,
            certbotCommand = spawn( 'certbot',
                ['--staging',
                '--text', '--agree-tos', '--email', email,
                '--expand', '--renew-by-default',
                '--configurator', 'certbot-external-auth:out',
                '--certbot-external-auth:out-public-ip-logging-ok',
                '-d', domain,
                '--renew-by-default',
                '--preferred-challenges', 'dns',
                'certonly']);

        function IsJsonString(str) {
            try {
                JSON.parse(str);
            } catch (e) {
                return false;
            }
            return true;
        }

        certbotCommand.stdin.setEncoding('utf-8');

        certbotCommand.stdout.on( 'data', function(data) {
            if(IsJsonString(data) === true){
                // Check if this script has the challenges
                var JSONOBJECT1 = JSON.parse(data);
                if(typeof JSONOBJECT1.txt_domain !== 'undefined' && typeof JSONOBJECT1.validation !== 'undefined'){
                    /**
                    * Create the settings in route 53
                    */
                    route53
                        .listHostedZones({}, function(err, data) {

                            if(err){
                                console.log('false');
                                console.log('ERROR IN listHostedZones');
                                console.log(err);
                            }

                            data
                            .HostedZones
                            .forEach(function(val, key){
                                if(val.Name.indexOf(topDomain) !== -1){
                                var params = {
                                    ChangeBatch: {
                                    Changes: [
                                        {
                                        Action: 'CREATE',
                                        ResourceRecordSet: {
                                            Name: JSONOBJECT1.txt_domain,
                                            Type: 'TXT',
                                            ResourceRecords: [
                                            {
                                                Value: '"' + JSONOBJECT1.validation + '"'
                                            }
                                            ],
                                            TTL: 60
                                        }
                                        }
                                    ],
                                    Comment: 'Automated Creation from Dorel Cloud tool'
                                    },
                                    HostedZoneId: val.Id
                                };

                                route53
                                    .changeResourceRecordSets(params, function(err, data) {
                                    if (err) {
                                        console.log(false);
                                        console.log('ERROR IN changeResourceRecordSets');
                                        console.log(err);
                                    } else {
                                        setTimeout(function(){
                                            certbotCommand.stdin.write("next\n");
                                        }, 60000); // some time to process
                                    }
                                    });
                                }
                            });
                        });
                }
            }
        });

        certbotCommand.stdout.on('error', function (err) {
            console.log(err);
        });

        certbotCommand.on( 'close', function(code) {
            console.log( 'child process exited with code ' + code );
        });
EOF

}

###
# INIT
###

# Setup the shell
set -e
clear
echo "Setting up Dorel Juvenile Google Cloud setup by @bobvanluijt..."
cd ~
mkdir -p ~/.cloudshell
touch ~/.cloudshell/no-apt-get-warning
sudo apt-get -qq -y update
sudo apt-get -qq -y install dialog npm jq letsencrypt python-pip
npm install aws-sdk
sudo pip install --upgrade pip -q
sudo pip install certbot -q
sudo pip install certbot-external-auth -q

# Setup the log file
sudo mkdir -p /var/log/dorel
sudo touch /var/log/dorel/debug.log
sudo chmod 777 /var/log/dorel/debug.log

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
         4 "Create new Docker worker within a sub-project"
         5 "Create a new Docker project"
         6 "Setup Route 53 credentials")

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
        6)
            TASK=$(echo route53_setup)
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
if [[ "$TASK" == "new_wordpress" ]]
then

    # Set the sub-project id
	SetSubProjectId

    # Get Wordpress data
    GetWordpressData

    # Download config json
    gsutil cp gs://dorel-io--config-bucket/${PROJECTNAME}.json ~/${PROJECTNAME}.json

    # Select the machine
    # AUTO SELECT MACHINE WITH LEAST LOAD
    #clear
    #MACHINESELECTLIST=()
    #while read -r line; do
    #    toutput=$(echo "$line" | grep -Po "(dorel-io--[^\s]+)")
    #    MACHINESELECTLIST+=("$toutput" "x")
    #done < <( gcloud compute instance-groups list )
    #MACHINECHOICE=$(dialog --title "List file of directory /home" --menu "Select your machine" 24 80 17 "${MACHINESELECTLIST[@]}" 3>&2 2>&1 1>&3)
    
    # THIS NEEDS TO BE AUTOMATED
    MACHINECHOICE=$(echo "dorel-io--economic-fearful--docker-worker-zhll63-jk6y")

    # Generate the Docker Wordpress container
    GenerateUid
    echo $(((100/7)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Generate the Docker Wordpress container" 10 70 0
    # gcloud --quiet compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${MACHINECHOICE}" --command "wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/container-setup.sh -O ~/container-setup.sh && chmod +x ~/container-setup.sh && sudo ~/container-setup.sh --website --accessurl \"${WEBSITEACCESSPOINT}\" --title \"${TITLE}\" --adminemail \"${ADMINEMAIL}\" --adminuser \"${ADMINEMAIL}\" --adminpass \"${RANDOMUID}\" && rm ~/container-setup.sh" >> /var/log/dorel/debug.log 2>&1

    # Generate the Docker Redis container
    echo $(((100/7)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Generate the Docker Redis container" 10 70 0

    # Generate the Docker PHP FPM container
    echo $(((100/7)*3)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Generate the Docker PHP FPM container" 10 70 0

    # Set proxy information
    WORKERPROXY=$(nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers.forEach(function(val, key){
            if(val.id === "${MACHINECHOICE}"){
                console.log(val.loadbalancer.proxy);
            }
        })
EOF
)
    WORKERFORWARDRULES=$(nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers.forEach(function(val, key){
            if(val.id === "${MACHINECHOICE}"){
                console.log(val.loadbalancer.forwardrules);
            }
        })
EOF
)
    WORKERURLMAP=$(nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers.forEach(function(val, key){
            if(val.id === "${MACHINECHOICE}"){
                console.log(val.loadbalancer.urlmap);
            }
        })
EOF
)

    # CERT I: Create certs for top domain
    echo $(((100/7)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create SPA certs" 10 70 0
    CERTDOMAIN=$(echo ${WEBSITEACCESSPOINT})
    CERTNAME=$(echo ${CERTDOMAIN//./-})
    CERTEMAIL=$(echo "IO@dorel.eu")
    GetAndSetCerts

    # CERT I: Add certs to loadbalancer
    gcloud beta compute ssl-certificates create "${CERTNAME}" --certificate "/etc/letsencrypt/live/${CERTDOMAIN}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAIN}/privkey.pem"

    # CERT I: Create proxy to loadbalancer
    echo $(((100/12)*8)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create proxy" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" target-http-proxies create "${WORKERPROXY}" --url-map "${WORKERURLMAP}" --ssl-certificate "${CERTNAME}" >> /var/log/dorel/debug.log 2>&1

    # CERT I: Create forwarding rules to loadbalancer
    echo $(((100/12)*9)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create forwarding rules" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" forwarding-rules create "${WORKERFORWARDRULES}" --global --ip-protocol "TCP" --port-range "443" --target-http-proxy "${WORKERPROXY}" >> /var/log/dorel/debug.log 2>&1

    # CERT II: Create certs for top domain
    echo $(((100/7)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create SPA certs" 10 70 0
    CERTDOMAIN=$(echo wrps.api.${WEBSITEACCESSPOINT})
    CERTNAME=$(echo ${CERTDOMAIN//./-})
    CERTEMAIL=$(echo "IO@dorel.eu")
    GetAndSetCerts

    # CERT II: Add certs to loadbalancer
    gcloud beta compute ssl-certificates create "${CERTNAME}" --certificate "/etc/letsencrypt/live/${CERTDOMAIN}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAIN}/privkey.pem"

    # CERT II: Create proxy to loadbalancer
    echo $(((100/12)*8)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create proxy" 10 70 0

    gcloud --quiet compute --project "${PROJECTID}" target-http-proxies create "${WORKERPROXY}" --url-map "${WORKERURLMAP}" --ssl-certificate "${CERTNAME}" >> /var/log/dorel/debug.log 2>&1

    # CERT II: Create forwarding rules to loadbalancer
    echo $(((100/12)*9)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create forwarding rules" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" forwarding-rules create "${WORKERFORWARDRULES}" --global --ip-protocol "TCP" --port-range "443" --target-http-proxy "${WORKERPROXY}" >> /var/log/dorel/debug.log 2>&1

    # CERT III: Create certs for top domain
    echo $(((100/7)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create SPA certs" 10 70 0
    CERTDOMAIN=$(echo mage.api.${WEBSITEACCESSPOINT})
    CERTNAME=$(echo ${CERTDOMAIN//./-})
    CERTEMAIL=$(echo "IO@dorel.eu")
    GetAndSetCerts

    # CERT III: Add certs to loadbalancer
    gcloud beta compute ssl-certificates create "${CERTNAME}" --certificate "/etc/letsencrypt/live/${CERTDOMAIN}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAIN}/privkey.pem"

    # CERT III: Create proxy to loadbalancer
    echo $(((100/12)*8)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create proxy" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" target-http-proxies create "${WORKERPROXY}" --url-map "${WORKERURLMAP}" --ssl-certificate "${CERTNAME}" >> /var/log/dorel/debug.log 2>&1

    # CERT III: Create forwarding rules to loadbalancer
    echo $(((100/12)*9)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create forwarding rules" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" forwarding-rules create "${WORKERFORWARDRULES}" --global --ip-protocol "TCP" --port-range "443" --target-http-proxy "${WORKERPROXY}" >> /var/log/dorel/debug.log 2>&1

    # Show success message
    dialog --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "The new Wordpress instance is ready and available on domain: ${WEBSITEACCESSPOINT} for user: ${ADMINEMAIL} and password: ${RANDOMUID}" 0 0

    ##
    # Add container routing https://cloud.google.com/compute/docs/load-balancing/http/content-based-example
    # Also add SSL certs to https
    ##

fi

###
# Run CREATE WORKER task
###
if [[ "$TASK" == "create_worker" ]]
then

    # Set the sub-project id
	SetSubProjectId

    # Set worker ID
    GenerateUid
    DOCKERWORKERID="dorel-io--${PROJECTNAME}--docker-worker-${RANDOMUID}"

    # Create the worker
    echo $(((100/12)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create a worker" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" instance-groups managed create "${DOCKERWORKERID}" --zone "europe-west1-c" --base-instance-name "${DOCKERWORKERID}" --template "dorel-io--${PROJECTNAME}--docker-worker-template" --size "1" >> /var/log/dorel/debug.log 2>&1

    # Download the config file
    echo $(((100/12)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Load config" 10 70 0
    gsutil cp gs://dorel-io--config-bucket/${PROJECTNAME}.json ~/${PROJECTNAME}.json

    # Create Heatlth Check for loadbalancer
    echo $(((100/12)*3)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create health check service" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" http-health-checks create http-basic-check-${RANDOMUID} >> /var/log/dorel/debug.log 2>&1

    # Create backend service for loadbalancer
    echo $(((100/12)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create backend service" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" backend-services create "${DOCKERWORKERID}" --protocol HTTP --http-health-checks http-basic-check-${RANDOMUID} >> /var/log/dorel/debug.log 2>&1
 
    # enable CDN
    echo $(((100/12)*5)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Enable CDN" 10 70 0
    gcloud beta --quiet compute backend-services update "${DOCKERWORKERID}" --enable-cdn --global

    # create the backend service
    echo $(((100/12)*6)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Setup load balancer" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" backend-services add-backend "${DOCKERWORKERID}" --instance-group "${DOCKERWORKERID}" --instance-group-zone "europe-west1-c"

    # Create url map
    echo $(((100/12)*7)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create URL MAP" 10 70 0
    WORKERURLMAP="dorel-io--${PROJECTNAME}--urlmap-${RANDOMUID}"
    gcloud --quiet compute --project "${PROJECTID}" url-maps create "${WORKERURLMAP}" --default-service "${DOCKERWORKERID}" >> /var/log/dorel/debug.log 2>&1

    # Wait for command to finish
    echo $(((100/12)*10)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Wait for creation of Linux box" 10 70 0
    sleep 5 # Need to wait until exec is done.

    # Get the name of the worker
    WORKERID=$(gcloud compute instance-groups managed list-instances "${DOCKERWORKERID}" --zone "europe-west1-c" | grep -P -o "(dorel-io--[^\s]+)")

    # Setup the Docker worker
    SQLID=$(cat ${PROJECTNAME}.json | jq -r '.db.id')
    SQLIP=$(gcloud sql --project="${PROJECTID}" --format json instances describe "${SQLID}" | jq -r '.ipAddresses[0].ipAddress')
    GenerateSqlPassword
    echo $(((100/12)*11)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Setting up Docker, Nginx and Let's Encrypt on the worker (might take some time)" 10 70 0
    gcloud --quiet compute --project "${PROJECTID}" ssh --zone "europe-west1-c" "${WORKERID}" --command "wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/host-worker-setup.sh -O ~/host-worker-setup.sh && chmod +x ~/host-worker-setup.sh && sudo ~/host-worker-setup.sh --sqlip \"${SQLIP}\" --sqlpass \"${PASSWORD1}\" --project \"${PROJECTID}\" && rm ~/host-worker-setup.sh" >> /var/log/dorel/debug.log 2>&1

    # Add worker name to JSON config
    nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers.push({ "id": "${DOCKERWORKERID}", "loadbalancer": { "backendservice": "${DOCKERWORKERID}", "urlmap": "${WORKERURLMAP}", "proxy": "${WORKERPROXY}", "forwardrules": "${WORKERFORWARDRULES}", "workerIds": ["${WORKERID}"]  }});
        fs.writeFileSync("${PROJECTNAME}.json", JSON.stringify(obj));
EOF
    gsutil cp ~/${PROJECTNAME}.json gs://dorel-io--config-bucket/${PROJECTNAME}.json
    rm ~/${PROJECTNAME}.json

    # Show success message
    dialog --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "The installation of the Worker is done. All information is stored in the JSON Config Bucket" 0 0

fi

###
# Run INIT task
###
if [[ "$TASK" == "init_google_cloud" ]]
then
  
  # Give a headsup message
  dialog --pause "During the process you will be asked to create a MYSQL root password and you will get the project information returned. Make sure to store the MYSQL root password and Swarm information in a secure place. It will be needed to setup workers in the future.\n\n\nOutput will be available in: /var/log/dorel/debug.log" 20 0 25

  # Collect manager type
    MENU="Select a worker type?"
    OPTIONS=("n1-standard-1" "Standard 1 CPU machine type with 1 virtual CPU and 3.75 GB of memory."
             "n1-standard-2" "Standard 2 CPU machine type with 2 virtual CPUs and 7.5 GB of memory."
             "n1-standard-4" "Standard 4 CPU machine type with 4 virtual CPUs and 15 GB of memory.")

    DOCKERMANAGERTYPE=$(dialog --clear \
                    --backtitle "$BACKTITLE" \
                    --title "$TITLE" \
                    --menu "$MENU" \
                    $HEIGHT 0 $CHOICE_HEIGHT \
                    "${OPTIONS[@]}" \
                    2>&1 >/dev/tty)

  # Generate project name
  wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/random-nouns.list -O ~/random-nouns.list
  PROJECTNAME=$(shuf -n 1 random-nouns.list)-$(shuf -n 1 random-nouns.list)
  rm random-nouns.list
  dialog --pause "Start generating project:\n\n${PROJECTNAME}" 14 0 25

  # Create instance template for worker
  echo $(((100/9)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create template for worker" 10 70 0
  gcloud --quiet compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io--${PROJECTNAME}--docker-worker-template" --machine-type "${DOCKERMANAGERTYPE}" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --tags "https-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-worker-template" >> /var/log/dorel/debug.log 2>&1
  
  # Create instance template for manager
  echo $(((100/9)*2)) | dialog --gauge "Create template for manager" 10 70 0
  gcloud --quiet compute -q --verbosity=error --project "${PROJECTID}" instance-templates create "dorel-io--${PROJECTNAME}--docker-manager-template" --machine-type "${DOCKERMANAGERTYPE}" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-manager-template" >> /var/log/dorel/debug.log 2>&1

  # Generate UID
  GenerateUid
  
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
  GenerateSqlPassword
  echo $(((100/9)*6)) | dialog --gauge "Set mysql root password" 10 70 0
  gcloud --quiet sql --project "${PROJECTID}" instances set-root-password "${SQLID}" --password "${PASSWORD1}" >> /var/log/dorel/debug.log 2>&1
  SQLIP=$(gcloud sql --project="${PROJECTID}" --format json instances describe "${SQLID}" | jq -r '.ipAddresses[0].ipAddress')

  # Create the JSON object and Store to bucket
  echo $(((100/9)*9)) | dialog --gauge "Store config to config bucket in file: ${PROJECTNAME}.json" 10 70 0
  PROJECTOBJECT="{ \"projectName\": \"dorel-io--${PROJECTNAME}\", \"projectNameShort\": \"${PROJECTNAME}\", \"db\": { \"id\": \"${SQLID}\" }, \"workers\": [] }"
  gsutil --quiet mb -p "${PROJECTID}" -c "NEARLINE" -l "europe-west1" "gs://dorel-io--config-bucket" || true
  touch ~/${PROJECTNAME}.json
  echo ${PROJECTOBJECT} > ~/${PROJECTNAME}.json
  gsutil --quiet cp ~/${PROJECTNAME}.json "gs://dorel-io--config-bucket"
  rm ~/${PROJECTNAME}.json

  # Show finish message
  dialog --pause "If you see this message, the initial cloud setup is done. Make sure to save the sub-project name: ${PROJECTNAME}" 20 0 60
fi

if [[ "$TASK" == "route53_setup" ]]
then
    SetRoute53Keys
fi

# Clear the screen when done
clear