#!/bin/bash

# Import our environment variables from systemd since when running as a service we don't get all the env by default
# Inspired by https://unix.stackexchange.com/questions/146995/inherit-environment-variables-in-systemd-docker-container
for e in $(tr "\000" "\n" < /proc/1/environ); do
        eval "export $e"
done

#
# You need to establish these variables in the environment.
# That might be as simple as defining them here before running the script
# or you might establish them as docker or kubernetes environment
# variables (e.g. from a kubernetes secret) before running the script.
#

#TENANT=YOURTENANT.verify.ibm.com
#API_CLIENT_ID=YOUR_API_CLIENT_ID
#API_CLIENT_SECRET=YOUR_API_CLIENT_SECRET
#RADIUS_CLIENT_SECRET=YOUR_RADIUS_CLIENT_SECRET

if [ -z "$TENANT" ] ; then echo "TENANT not defined"; exit 1; fi
if [ -z "$API_CLIENT_ID" ] ; then echo "API_CLIENT_ID not defined"; exit 1; fi
if [ -z "$API_CLIENT_SECRET" ] ; then echo "API_CLIENT_SECRET not defined"; exit 1; fi
if [ -z "$RADIUS_CLIENT_SECRET" ] ; then echo "RADIUS_CLIENT_SECRET not defined"; exit 1; fi

#
# You should not really need to change anything below for a demo, only perhaps some of the configuration
# options that are passed to the pam_ibm_auth.so library set in the isv-auth-choice file.
#
#

# move to working directory
cd /root/resources

echo "Configuring IVG Linux RADIUS for:"
echo "TENANT: $TENANT"
echo "API_CLIENT_ID: $API_CLIENT_ID"
if [ ! -z "$PORT" ]
then
  echo "PORT: $PORT"
fi

# unzip and install IVG for Linux RADIUS
echo "Unzipping and installing IVG for Linux RADIUS binaries"
unzip -u ISVG_RADIUS_*.zip
unzip -u linux_radius.zip
unzip -u linux_radius/rhel-8.zip
rpm -ivh ibm-auth-api-*.x86_64.rpm  ibm-radius-*.x86_64.rpm

# generate obfuscated client secret and create theconfig file
# and enable trace
CFGFILE="/etc/IbmRadiusConfig.json"
echo "Configuring config file: $CFGFILE"
if [ ! -f "$CFGFILE".bak ] 
then
    echo "Backing up original config file"
    cp "$CFGFILE" "$CFGFILE".bak
fi
OBF_API_CLIENT_SECRET=$(/opt/ibm/ibm_auth/ibm_authd_64 --obf "$API_CLIENT_SECRET" | sed -e 's/\//\\\//g')
OBF_RADIUS_CLIENT_SECRET=$(/opt/ibm/ibm_auth/ibm_authd_64 --obf "$RADIUS_CLIENT_SECRET" | sed -e 's/\//\\\//g')
if [ -z "$PORT" ]
then
    PORT="443"
fi

cat <<EOF | sed -e "s/TENANT/$TENANT/" \
    -e "s/API_CLIENT_ID/$API_CLIENT_ID/" \
    -e "s/OBF_API_CLIENT_SECRET/$OBF_API_CLIENT_SECRET/" \
    -e "s/OBF_RADIUS_CLIENT_SECRET/$OBF_RADIUS_CLIENT_SECRET/" \
    -e "s/PORT/$PORT/" \
     > "$CFGFILE"
{
    "address":"::",
    "port":1812,
    "trace-file":"/tmp/ibm-auth-api.log",
    "trace-rollover":12697600,
    "ibm-auth-api":{
        "client-id":"API_CLIENT_ID",
        "obf-client-secret":"OBF_API_CLIENT_SECRET",
        "protocol":"https",
        "host":"TENANT",
        "port":PORT,
        "max-handles":16
    },
    "clients":[
        /* This demo configuration only defines a localhost client */
        {
            "name":"client1",
            "address":"127.0.0.1",
            "mask":"255.255.255.255",
            "obf-secret":"OBF_RADIUS_CLIENT_SECRET",
            "auth-method":"password-then-totp",
            "require-msg-auth": true
        }
    ],
    "policy":[
        {
            "name":"policy1",
            "match":{
                "apply": "before-each-response" /* apply for every packet send back */
            },
            "return-attrs":[
                {
                    "name":"Proxy-State",  /* If RADIUS proxy present it requires this var to be returned */
                    "value":"{{reflect}}", /* Send back the Proxy-State variable sent to us */
                    "value-type":"text"    /* Override this attrs input type of "string" of octets as "text". */
                }
            ],
            "action":"continue"
        }
    ]
}
EOF

# restart radius server
echo "Restarting radius server"
systemctl restart ibm_radius_64
echo "DONE!"
