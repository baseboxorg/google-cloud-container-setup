#!/bin/bash
##
# The Cloud Cert Cron script connects to Route 53 and refreshes domain certificates
#
##

###
# Load all arguments
###
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -t|--type)
    TYPE="$2"
    shift # past argument
    ;;
    -cd|--certdomain)
    CERTDOMAIN="$2"
    shift # past argument
    ;;
    -ce|--certemail)
    CERTEMAIL="$2"
    shift # past argument
    ;;
    -l|--loadbalancer)
    LOADBALANCER="$2"
    shift # past argument
    ;;
    -u|--urlmap)
    URLMAP="$2"
    shift # past argument
    ;;
    *)
    ;;
esac
shift # past argument or value
done

###
# Validate if needed arguments are available
###
if [ -z ${TYPE} ];         then echo "-t or --type is unset | use cron (for the cronjob) or setup";    exit 1; fi
if [ -z ${CERTDOMAIN} ];   then echo "-cd or --certdomain is unset | abort";  exit 1; fi
if [ -z ${CERTEMAIL} ];    then echo "-ce or --certemail is unset | abort";      exit 1; fi
if [ -z ${LOADBALANCER} ]; then echo "-l or --loadbalancer is unset | abort"; exit 1; fi
if [ -z ${URLMAP} ];       then echo "-u or --urlmap is unset | abort";  exit 1; fi

# Replace dots with stripes
CERTDOMAINSTRIPE=$(echo ${CERTDOMAIN//./-})

# go to home dir
cd ~

# Node script gets and sets all information from / to Route 53
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

# Get the certdomain dir
CERTDOMAINDIR=$(find /etc/letsencrypt/live -maxdepth 1 -type d -name "*${CERTDOMAIN}*" -printf '%f' -quit)

# Create random string for unique id
RANDOMSTRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)

# Add certificates
gcloud -q beta compute ssl-certificates create "${CERTDOMAINSTRIPE}-ssl-certificates-${RANDOMSTRING}" --certificate "/etc/letsencrypt/live/${CERTDOMAINDIR}/fullchain.pem" --private-key "/etc/letsencrypt/live/${CERTDOMAINDIR}/privkey.pem"

# Update the load balancer with the new cert
gcloud -q compute target-https-proxies update "${LOADBALANCER}" --ssl-certificate "${CERTDOMAINSTRIPE}-ssl-certificates-${RANDOMSTRING}"

if [[ ${TYPE} -eq cron ]]
then
    # Get the previous cert name
    LATESTCERTNAME=$(cat ~/.certName.conf) # Get this from a file and remove the file

    # delete old certificates if they are there
    gcloud -q beta compute ssl-certificates delete "${LATESTCERTNAME}"
fi

# Replace the url in the nginx settings
sed -i -e 's/[[CERTDOMAIN]]/${CERTDOMAIN}/g' /etc/nginx/sites-enabled/default

# Save to cert file
echo "${CERTDOMAINSTRIPE}-ssl-certificates-${RANDOMSTRING}" > ~/.certName.conf

# Reload nginx
service nginx reload

# remove cert files
rm -r /etc/letsencrypt/live/${CERTDOMAINDIR}