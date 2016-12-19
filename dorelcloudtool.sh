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

# Get config
function getConfig {

    PROJECTID=$(nodejs <<EOF 
        var fs = require("fs");
        try {
            var config = fs.readFileSync("/root/.config/gcloud/configurations/config_default", 'utf8');
            var match = /project = (.*)/.exec(config);
            console.log(match[1]);
        }
        catch (e) {
            console.log(false);
        }
EOF
)

    gcloud config set project ${PROJECTID}

    PROJECTLOCATION=$(nodejs <<EOF
        var fs = require("fs");
        try {
            var config = fs.readFileSync("/root/.config/gcloud/configurations/config_default", 'utf8');
            var match = /region = (.*)/.exec(config);
            console.log(match[1]);
        }
        catch (e) {
            console.log(false);
        }
EOF
)

    PROJECTZONE=$(nodejs <<EOF
        var fs = require("fs");
        try {
            var config = fs.readFileSync("/root/.config/gcloud/configurations/config_default", 'utf8');
            var match = /zone = (.*)/.exec(config);
            console.log(match[1]);
        }
        catch (e) {
            console.log(false);
        }
EOF
)

    # If there is no config file, load gcloud init
    if [ $PROJECTID = "false" ]; then
        gcloud init
        getConfig
    fi
}

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

# Get the docker host
function SetWorkerIdForContainer {
    exec 3>&1;
    WORKERIDCLOUDCONTAINER=$(dialog --inputbox "What is the name of the machine?" 0 0 dorel-io--${PROJECTNAME}--docker-worker- 2>&1 1>&3)
    exec 3>&-;

    gcloud compute instances describe "${WORKERIDCLOUDCONTAINER}" --zone ${PROJECTZONE}
    if [ $? -eq 0 ]; then
        echo Found
    else
        echo SetWorkerIdForContainer
    fi
}

function CreateARecord {
    nodejs <<EOF
    'use strict';
    var AWS   = require('aws-sdk'),
    route53   = new AWS.Route53(),
    params,
    topDomain = "${ARECORDDOMAIN}".split('.').slice(2).join('.'); // remove subdomain

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
                        params = {
                            ChangeBatch: {
                            Changes: [
                                {
                                Action: 'CREATE',
                                ResourceRecordSet: {
                                    Name: "${ARECORDDOMAIN}",
                                    Type: 'A',
                                    ResourceRecords: [
                                    {
                                        Value: "${ARECORDIP}"
                                    }
                                    ],
                                    TTL: 86400
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
                                    console.log('DONE');
                                }
                            });
                    }
                });
        });
EOF

}

function CreateCerts {
    nodejs <<EOF
        'use strict';
        var domain = "${CERTDOMAIN}",
            email  = "${CERTEMAIL}";
        var domainSplit = domain.split('.');
        var topDomain = domainSplit[domainSplit.length-2]+'.'+domainSplit[domainSplit.length-1],
            AWS       = require('aws-sdk'),
            route53   = new AWS.Route53(),
            params,
            spawn     = require( 'child_process' ).spawn,
            certbotCommand = spawn( 'certbot',
                ['--text', '--agree-tos', '--email', email,
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
                                params = {
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
                                            TTL: 30
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
                                        }, 45000); // some time to process
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
            params.ChangeBatch.Changes[0].Action = 'DELETE';
            route53
                .changeResourceRecordSets(params, function(err, data) {
                    if (err) {
                        console.log(false);
                        console.log('ERROR IN changeResourceRecordSets');
                        console.log(err);
                    } else {
                        console.log('done');
                    }
                });
        });
EOF

}

# Get Wordpress database
function GetWordpressData {
    WEBSITEACCESSPOINT=""
    TITLE=""
    EDITOREMAIL=""
    # open fd
    exec 3>&1
    # Store data to $VALUES variable
    VALUES=$(dialog --output-separator "," \
            --backtitle "$TITLE" \
            --title "Setup Route 53 keys" \
            --form "Create a new user" \
        15 50 0 \
                "Access Url:"    1 1 "$WEBSITEACCESSPOINT" 1 16 40 0 \
                "Website Title:" 2 1 "$TITLE"              2 16 40 0 \
                "Editor Email:"   3 1 "$EDITOREMAIL"         3 16 40 0 \
        2>&1 1>&3)
    exec 3>&-

    set -- "$VALUES" 
    IFS=","; declare -a Array=($*) 
    WEBSITEACCESSPOINT="${Array[0]}" 
    TITLE="${Array[1]}" 
    EDITOREMAIL="${Array[2]}"

    # Validate the URL
    echo $WEBSITEACCESSPOINT | grep -q -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$"
    if [ $? -eq 1 ] ; then
        dialog --msgbox "This (${WEBSITEACCESSPOINT}) is not a valid access url (should be like: www.test.com)" 0 0
        GetWordpressData
    fi

    # Validate email
    echo $EDITOREMAIL | grep -q -P "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"
    if [ $? -eq 1 ] ; then
        dialog --msgbox "This (${EDITOREMAIL}) is not a valid email" 0 0
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
    RANDOMUID2=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
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

###
# INIT, RUN THE SCRIPT
###
set -e
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
# Setup the log file
mkdir -p /var/log/dorel
touch /var/log/dorel/debug.log
chmod 777 /var/log/dorel/debug.log
# Setup the shell
clear
echo "Setting up Dorel Juvenile Google Cloud setup by @bobvanluijt..."
cd ~
mkdir -p ~/.cloudshell
touch ~/.cloudshell/no-apt-get-warning
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
if [ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg -s | apt-key add - >> /var/log/dorel/debug.log 2>&1
fi
apt-get update -qq -y >> /var/log/dorel/debug.log 2>&1
apt-get -qq -y install dialog npm jq letsencrypt python-pip >> /var/log/dorel/debug.log 2>&1
npm install aws-sdk >> /var/log/dorel/debug.log 2>&1
pip install --upgrade pip -q >> /var/log/dorel/debug.log 2>&1
pip install certbot -q >> /var/log/dorel/debug.log 2>&1
pip install certbot-external-auth -q >> /var/log/dorel/debug.log 2>&1
gcloud components update

# Ask project ID
getConfig

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

# Ask: What do you want to do? # note how update and reconnect are both the same!
MENU="What do you want to do?"
OPTIONS=(1 "Dorel.io Service - New"
         2 "Dorel.io Service - Update"
         3 "Dorel.io Service - Reconnect"
         4 "Dorel.io Service - Delete"
         5 "Create a new Docker worker"
         6 "Create a new Docker project"
         7 "Setup Route 53 credentials"
         8 "Change global Google Cloud settings")

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
            TASK=$(echo recreate_wordpress)
            ;;
        4)
            TASK=$(echo delete_wordpress)
            ;;
        5)
            TASK=$(echo create_worker)
            ;;
        6)
            TASK=$(echo init_google_cloud)
            ;;
        7)
            TASK=$(echo route53_setup)
            ;;
        8)
            TASK=$(echo change_project)
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

    # Set the worker id
    SetWorkerIdForContainer

    # Get Wordpress data
    GetWordpressData

    # Download config json
    gsutil cp gs://dorel-io--config-bucket/${PROJECTNAME}.json ~/${PROJECTNAME}.json

    # THIS NEEDS TO BE AUTOMATED AND NEEDS TO BE AN ACTUAL MACHINE, NOT A MACHINE GROUP
    MACHINECHOICE=$(echo "${WORKERIDCLOUDCONTAINER}")
    MACHINECHOICEGROUP=$(echo ${MACHINECHOICE::-5})

    # Generate the Docker Wordpress container
    GenerateUid
    echo $(((100/15)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Generate the Docker Wordpress container" 10 70 0
    ssh -tt -i ~/.ssh/google_compute_engine -oConnectTimeout=600 -oStrictHostKeyChecking=no root@${MACHINECHOICE} "wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/container-setup.sh -O ~/container-setup.sh && chmod +x ~/container-setup.sh && sudo ~/container-setup.sh --website \"${WEBSITEACCESSPOINT}\" --accessurl \"${WEBSITEACCESSPOINT}\" --title \"${TITLE}\" --editoremail \"${EDITOREMAIL}\" --editoruser \"${EDITOREMAIL}\" --editorpass \"${RANDOMUID}\" --adminpass \"${RANDOMUID2}\" -br "${GITBRANCH}" && rm ~/container-setup.sh" >> /var/log/dorel/debug.log 2>&1
    CONTAINERINFO=$(ssh -tt -i ~/.ssh/google_compute_engine -oConnectTimeout=600 -oStrictHostKeyChecking=no root@${MACHINECHOICE} "cat /root/.latestSetup.json")

    # Generate the Docker Redis container
    echo $(((100/15)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Generate the Docker Redis container" 10 70 0

    ##
    # Send hosted zone message
    ##
    dialog --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Make sure a hosted zone for the domain is available in Route 53. A hosted zone name should be formatted as: [domain.toplevel.] Like [testsite.com.]" 0 0

    ##
    # Add the SPA certificate and loadbalancer
    ##

    # CERT I: Create certs for top domain
    echo $(((100/15)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create and distribute SPA certificates" 10 70 0
    GenerateUid
    CERTDOMAIN=$(echo ${WEBSITEACCESSPOINT})
    CERTNAME=$(echo ${CERTDOMAIN//./-})
    CERTEMAIL=$(echo "IO@dorel.eu")
    LOADBALANCERTYPE=$(echo "SPA")
    LOADBALANCERPREFIX=$(echo "dorel-io--${CERTNAME}")
    LOADBALANCERID=$(echo "-spa-${RANDOMUID}")

    # CERT I: Add certs to loadbalancer
    echo $(((100/15)*3)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Requesting certs from Letsencrypt" 10 70 0
    CERTDOMAINSTRIPE=$(echo ${CERTDOMAIN//./-})
    CreateCerts
    # Get the certdomain dir
    CERTDOMAINDIR=$(find /etc/letsencrypt/live -maxdepth 1 -type d -name "*${CERTDOMAIN}*" -printf '%f' -quit)
    # Get the old cert domain dir
    touch cat ~/.certPath.conf
    CERTDOMAINDIROLD=$(cat ~/.certPath.conf)
    # Create random string for unique id
    RANDOMSTRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    # Add certificates but remove first if available
    gcloud -q beta compute ssl-certificates delete "${LOADBALANCERPREFIX}-ssl-certificates" | true
    echo $(((100/15)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Add certificates to ${LOADBALANCERTYPE} load balancer. Requesting certs from Letsencrypt" 10 70 0
    gcloud -q beta compute ssl-certificates create "${LOADBALANCERPREFIX}-ssl-certificates" --certificate "/etc/letsencrypt/live/${CERTDOMAINDIR}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAINDIR}/privkey.pem" >> /var/log/dorel/debug.log 2>&1

    # CERT I: Create proxy to loadbalancer
    echo $(((100/15)*5)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create proxy for ${LOADBALANCERTYPE}" 10 70 0
    gcloud --quiet compute target-https-proxies create "${CERTNAME}-trgt-https-prx" --url-map "${MACHINECHOICEGROUP}-url-maps" --ssl-certificate "${LOADBALANCERPREFIX}-ssl-certificates" >> /var/log/dorel/debug.log 2>&1

    # CERT I: Create forwarding rules to loadbalancer
    echo $(((100/15)*6)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create forwarding rules for ${LOADBALANCERTYPE}" 10 70 0
    gcloud --quiet compute forwarding-rules create "${CERTNAME}-forwarding-rule" --global --ip-protocol "TCP" --port-range "443" --target-https-proxy "${CERTNAME}-trgt-https-prx" >> /var/log/dorel/debug.log 2>&1
 
    # Create A record
    echo $(((100/15)*7)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create A records" 10 70 0
    ARECORDDOMAIN=$(echo ${CERTDOMAIN})
    ARECORDIP=$(gcloud compute forwarding-rules describe "${CERTNAME}-forwarding-rule" --global --format json | jq -r '.IPAddress')
    CreateARecord

    # Add worker name to JSON config
    nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers["${MACHINECHOICEGROUP}"] = obj.workers["${MACHINECHOICEGROUP}"] || [];
        obj.workers["${MACHINECHOICEGROUP}"].push({ "${LOADBALANCERTYPE}": { "ssl-certificates": "${LOADBALANCERPREFIX}-ssl-certificates", "target-https-proxies": "${LOADBALANCERPREFIX}-trgt-https-prx", "forwarding-rules": "${LOADBALANCERPREFIX}-forwarding-rules", "https-health-checks": "${LOADBALANCERPREFIX}-https-health-checks", "backend-services": "${LOADBALANCERPREFIX}-bs", "url-maps": "${LOADBALANCERPREFIX}-url-maps" }});
        fs.writeFileSync("${PROJECTNAME}.json", JSON.stringify(obj));
EOF

    ##
    # Add the Wordpress certificate and loadbalancer
    ##

    # CERT II: Create certs for top domain
    echo $(((100/15)*8)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create and distribute SPA certificates" 10 70 0
    GenerateUid
    CERTDOMAIN=$(echo wrps.api.${WEBSITEACCESSPOINT})
    CERTNAME=$(echo ${CERTDOMAIN//./-})
    CERTEMAIL=$(echo "IO@dorel.eu")
    LOADBALANCERTYPE=$(echo "WRPS")
    LOADBALANCERPREFIX=$(echo "dorel-io--${CERTNAME}")
    LOADBALANCERID=$(echo "-wrps-${RANDOMUID}")

    # CERT II: Add certs to loadbalancer
    echo $(((100/15)*9)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Requesting certs from Letsencrypt" 10 70 0
    CERTDOMAINSTRIPE=$(echo ${CERTDOMAIN//./-})
    CreateCerts
    # Get the certdomain dir
    CERTDOMAINDIR=$(find /etc/letsencrypt/live -maxdepth 1 -type d -name "*${CERTDOMAIN}*" -printf '%f' -quit)
    # Get the old cert domain dir
    touch cat ~/.certPath.conf
    CERTDOMAINDIROLD=$(cat ~/.certPath.conf)
    # Create random string for unique id
    RANDOMSTRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    # Add certificates but remove first if available
    gcloud -q beta compute ssl-certificates delete "${LOADBALANCERPREFIX}-ssl-certificates" | true
    echo $(((100/15)*10)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Add certificates to ${LOADBALANCERTYPE} load balancer. Requesting certs from Letsencrypt" 10 70 0
    gcloud -q beta compute ssl-certificates create "${LOADBALANCERPREFIX}-ssl-certificates" --certificate "/etc/letsencrypt/live/${CERTDOMAINDIR}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAINDIR}/privkey.pem" >> /var/log/dorel/debug.log 2>&1

    # CERT II: Create proxy to loadbalancer
    echo $(((100/15)*11)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create proxy for ${LOADBALANCERTYPE}" 10 70 0
    gcloud --quiet compute target-https-proxies create "${CERTNAME}-trgt-https-prx" --url-map "${MACHINECHOICEGROUP}-url-maps" --ssl-certificate "${LOADBALANCERPREFIX}-ssl-certificates" >> /var/log/dorel/debug.log 2>&1

    # CERT II: Create forwarding rules to loadbalancer
    echo $(((100/15)*12)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create forwarding rules for ${LOADBALANCERTYPE}" 10 70 0
    gcloud --quiet compute forwarding-rules create "${CERTNAME}-forwarding-rule" --global --ip-protocol "TCP" --port-range "443" --target-https-proxy "${CERTNAME}-trgt-https-prx" >> /var/log/dorel/debug.log 2>&1
 
    # Create A record
    echo $(((100/15)*13)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create A records" 10 70 0
    ARECORDDOMAIN=$(echo ${CERTDOMAIN})
    ARECORDIP=$(gcloud compute forwarding-rules describe "${CERTNAME}-forwarding-rule" --global --format json | jq -r '.IPAddress')
    sleep 45 # sleep because of leaky bucket of AWS
    CreateARecord

    echo $(((100/15)*14)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Write to bucket" 10 70 0
    # Add worker name to JSON config
    nodejs <<EOF
        var fs    = require("fs")
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers["${MACHINECHOICEGROUP}"] = obj.workers["${MACHINECHOICEGROUP}"] || [];
        obj.workers["${MACHINECHOICEGROUP}"].push({ "${LOADBALANCERTYPE}": { "ssl-certificates": "${LOADBALANCERPREFIX}-ssl-certificates", "target-https-proxies": "${LOADBALANCERPREFIX}-trgt-https-prx", "forwarding-rules": "${LOADBALANCERPREFIX}-forwarding-rules", "https-health-checks": "${LOADBALANCERPREFIX}-https-health-checks", "backend-services": "${LOADBALANCERPREFIX}-bs", "url-maps": "${LOADBALANCERPREFIX}-url-maps" }});
        fs.writeFileSync("${PROJECTNAME}.json", JSON.stringify(obj));
EOF

    gsutil cp ~/${PROJECTNAME}.json gs://dorel-io--config-bucket/${PROJECTNAME}.json
    rm ~/${PROJECTNAME}.json

    # Show success message
    dialog --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "The new instance is ready and available on domain: ${WEBSITEACCESSPOINT} for user: ${EDITOREMAIL} and password: ${RANDOMUID}. Admin user: io@dorel.eu Admin pass: ${RANDOMUID2}" 0 0

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
    echo $(((100/6)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create a worker" 10 70 0
    gcloud --quiet compute instance-groups managed create "${DOCKERWORKERID}" --zone "${PROJECTZONE}" --base-instance-name "${DOCKERWORKERID}" --template "dorel-io--${PROJECTNAME}--docker-worker-template" --size "1" >> /var/log/dorel/debug.log 2>&1

    # Download the config file
    echo $(((100/6)*2)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Load config" 10 70 0
    gsutil cp gs://dorel-io--config-bucket/${PROJECTNAME}.json ~/${PROJECTNAME}.json

    # Wait for command to finish
    echo $(((100/6)*3)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Wait for creation of Linux box" 10 70 0
    sleep 60 # Need to wait until exec is done.

    # Get the name of the worker
    WORKERID=$(gcloud compute instance-groups managed list-instances "${DOCKERWORKERID}" --zone "${PROJECTZONE}" | grep -P -o "(dorel-io--[^\s]+)")
    WORKERIP=$(gcloud compute instances describe ${WORKERID} --format json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP')

    # Setup the Docker worker
    echo $(((100/5)*3)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Set SQL settings" 10 70 0
    SQLID=$(cat ${PROJECTNAME}.json | jq -r '.db.id')
    SQLIP=$(gcloud sql --format json instances describe "${SQLID}" | jq -r '.ipAddresses[0].ipAddress')
    GenerateSqlPassword
    echo $(((100/6)*4)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Setting up cloud IPs" 10 70 0
    
    # Add access to the SQL instance
    # Issue can be resolved with this: https://github.com/stedolan/jq/issues/354
    SQLADDIPS=$(gcloud sql instances describe ${SQLID} --format json  | jq -r '.settings.ipConfiguration.authorizedNetworks | join(",")')
    gcloud sql instances patch ${SQLID} --authorized-networks=${SQLADDIPS},${WORKERIP} >> /var/log/dorel/debug.log 2>&1

    # Setup loadbalancer data
    echo $(((100/6)*5)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Setting up loadbalancer" 10 70 0
    gcloud --quiet compute backend-services create "${DOCKERWORKERID}-bs" --protocol HTTP --http-health-checks "${PROJECTNAME}-http-health-checks" --port-name "http" >> /var/log/dorel/debug.log 2>&1
    gcloud --quiet compute backend-services add-backend "${DOCKERWORKERID}-bs" --instance-group "${DOCKERWORKERID}" --max-utilization "0.98" --instance-group-zone "${PROJECTZONE}" >> /var/log/dorel/debug.log 2>&1
    gcloud beta --quiet compute backend-services update "${DOCKERWORKERID}-bs" --enable-cdn >> /var/log/dorel/debug.log 2>&1
    gcloud --quiet compute url-maps create "${DOCKERWORKERID}-url-maps" --default-service "${DOCKERWORKERID}-bs" >> /var/log/dorel/debug.log 2>&1
    gcloud --quiet compute url-maps add-path-matcher "${DOCKERWORKERID}-url-maps" --path-matcher-name "${DOCKERWORKERID}-matcher-name" --default-service "${DOCKERWORKERID}-bs" >> /var/log/dorel/debug.log 2>&1

    # This script will create the ssh key files needed to login
    echo $(((100/6)*6)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Building the Docker worker installation (might take some time)" 10 70 0
    gcloud compute ssh ${WORKERID} --command "ls" >> /var/log/dorel/debug.log 2>&1

    # Exec the setup
    ssh -tt -i ~/.ssh/google_compute_engine -oConnectTimeout=600 -oStrictHostKeyChecking=no root@${WORKERID} "sudo wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/host-worker-setup.sh -O ~/host-worker-setup.sh && sudo chmod +x ~/host-worker-setup.sh && sudo ~/host-worker-setup.sh --sqlip \"${SQLIP}\" --sqlpass \"${PASSWORD1}\" -P \"${PROJECTID}\" -b \"${PROJECTNAME}\" && sudo rm ~/host-worker-setup.sh" >> /var/log/dorel/debug.log 2>&1

    # Add worker name to JSON config
    nodejs <<EOF
        var fs = require("fs");
        var obj = JSON.parse(fs.readFileSync("${PROJECTNAME}.json", 'utf8'));
        obj.workers = obj.workers || {};
        obj.workers["${DOCKERWORKERID}"] = obj.workers["${DOCKERWORKERID}"] || [];
        obj.workers["${DOCKERWORKERID}"].push({ "id": "${DOCKERWORKERID}", "workerIds": ["${WORKERID}"] });
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

  DOCKERMANAGERTYPE="n1-standard-4"

  # Generate project name
  wget https://raw.githubusercontent.com/dorel/google-cloud-container-setup/${GITBRANCH}/subservices/random-nouns.list -O ~/random-nouns.list
  PROJECTNAME=$(shuf -n 1 random-nouns.list)-$(shuf -n 1 random-nouns.list)
  rm random-nouns.list
  dialog --pause "Start generating project:\n\n${PROJECTNAME}" 14 0 25

  # Create instance template for worker
  echo $(((100/9)*1)) | dialog --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Create template for worker" 10 70 0
  gcloud --quiet compute -q --verbosity=error instance-templates create "dorel-io--${PROJECTNAME}--docker-worker-template" --machine-type "${DOCKERMANAGERTYPE}" --network "default" --maintenance-policy "MIGRATE" --scopes default="https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/trace.append","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/devstorage.full_control" --tags "http-server" --image "/ubuntu-os-cloud/ubuntu-1604-xenial-v20161020" --boot-disk-size "25" --boot-disk-type "pd-standard" --boot-disk-device-name "dorel-io-docker-worker-template" >> /var/log/dorel/debug.log 2>&1

  # Generate UID
  GenerateUid
  
  # Create SQL and set current IP as auth network
  echo $(((100/9)*4)) | dialog --gauge "Create cloud SQL with replica (might take some time)" 10 70 0
  GenerateUid
  SQLID="dorel-io--${PROJECTNAME}--database-${RANDOMUID}"
  SQLFAILOVERID="dorel-io--${PROJECTNAME}--failover-database-${RANDOMUID}"
  gcloud --quiet beta sql instances create "${SQLID}" --tier "db-n1-highmem-4" --activation-policy "ALWAYS" --backup-start-time "01:23" --database-version "MYSQL_5_7" --enable-bin-log --failover-replica-name "${SQLFAILOVERID}" --gce-zone "${PROJECTZONE}" --maintenance-release-channel "PRODUCTION" --maintenance-window-day "SUN" --maintenance-window-hour "01" --authorized-networks="$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')" --region "${PROJECTLOCATION}" --replica-type "FAILOVER" --replication ASYNCHRONOUS --storage-auto-increase --storage-size "50GB" --storage-type "SSD" >> /var/log/dorel/debug.log 2>&1

  # Create datastore bucket
  echo $(((100/9)*5)) | dialog --gauge "Create storage bucket" 10 70 0
  gsutil mb -p "${PROJECTID}" -c "REGIONAL" -l "${PROJECTLOCATION}" "gs://dorel-io--${PROJECTNAME}--content-bucket" >> /var/log/dorel/debug.log 2>&1

  # Set password and collect IP
  GenerateSqlPassword
  echo $(((100/9)*6)) | dialog --gauge "Set mysql root password" 10 70 0
  gcloud --quiet sql instances set-root-password "${SQLID}" --password "${PASSWORD1}" >> /var/log/dorel/debug.log 2>&1
  SQLIP=$(gcloud sql --format json instances describe "${SQLID}" | jq -r '.ipAddresses[0].ipAddress')

  # Create HTTP Health check
  echo $(((100/9)*7)) | dialog --gauge "Create http health check" 10 70 0
  gcloud --quiet compute http-health-checks create "${PROJECTNAME}-http-health-checks"

  # Create the JSON object and Store to bucket
  echo $(((100/9)*8)) | dialog --gauge "Store config to config bucket in file: ${PROJECTNAME}.json" 10 70 0
  PROJECTOBJECT="{ \"projectName\": \"dorel-io--${PROJECTNAME}\", \"projectNameShort\": \"${PROJECTNAME}\", \"db\": { \"id\": \"${SQLID}\" }, \"workers\": [] }"
  gsutil --quiet mb -p "${PROJECTID}" -c "NEARLINE" -l "${PROJECTLOCATION}" "gs://dorel-io--config-bucket" || true
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

if [[ "$TASK" == "change_project" ]]
then
    gcloud init
    CURRENTSCRIPT=`basename "$0"`
    bash $CURRENTSCRIPT
fi

# Clear the screen when done
clear
