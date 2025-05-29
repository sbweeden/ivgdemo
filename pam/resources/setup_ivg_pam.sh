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
#API_CLIENT_ID=YOUR_CLIENT_ID
#API_CLIENT_SECRET=YOUR_CLIENT_SECRET
#USERNAME="testuser"
#USERPWD="Passw0rd"
#MAPPED_USER="$USERNAME"

if [ -z "$TENANT" ] ; then echo "TENANT not defined"; exit 1; fi
if [ -z "$API_CLIENT_ID" ] ; then echo "API_CLIENT_ID not defined"; exit 1; fi
if [ -z "$API_CLIENT_SECRET" ] ; then echo "API_CLIENT_SECRET not defined"; exit 1; fi
if [ -z "$USERNAME" ] ; then echo "USERNAME not defined"; exit 1; fi
if [ -z "$USERPWD" ] ; then echo "USERPWD not defined"; exit 1; fi
if [ -z "$MAPPED_USER" ] ; then echo "MAPPED_USER not defined"; exit 1; fi

#
# You should not really need to change anything below for a demo, only perhaps some of the configuration
# options that are passed to the pam_ibm_auth.so library set in the isv-auth-choice file.
#
#

# move to working directory
cd /root/resources

echo "Configuring IVG Linux PAM for:"
echo "TENANT: $TENANT"
echo "API_CLIENT_ID: $API_CLIENT_ID"
echo "USERNAME: $USERNAME"
echo "ISVUSER: $MAPPED_USER"
if [ ! -z "$PORT" ]
then
  echo "PORT: $PORT"
fi

# unzip and install IVG for Linux PAM
echo "Unzipping and installing IVG for Linux PAM binaries"
unzip -u ISVGForLinuxPAM*.zip
unzip -u linux_pam/rhel-8.zip
rpm -ivh ibm-auth-api-*.x86_64.rpm  pam-ibm-auth-*.x86_64.rpm

# generate obfuscated client secret and insert tenant-specific config into the config file
# and enable trace
echo "Configuring /etc/pam_ibm_auth.json file"
OBF_SECRET=$(/opt/ibm/ibm_auth/ibm_authd_64 --obf "$API_CLIENT_SECRET")
sed -i \
  -e "s|.*\"host\".*|\"host\":\"$TENANT\",|" \
  -e "s|.*\"client-id\".*|\"client-id\":\"$API_CLIENT_ID\",|" \
  -e "s|.*\"obf-client-secret\".*|\"obf-client-secret\":\"$OBF_SECRET\",|" \
  -e "s|.*\"/tmp/ibm_authd.log\".*|\"trace-file\":\"/tmp/ibm_authd.log\"|" \
  -e "s|.*\"/tmp/pam_ibm_auth.log\".*|\"trace-file\":\"/tmp/pam_ibm_auth.log\"|" \
  /etc/pam_ibm_auth.json
if [ ! -z "$PORT" ]
then
  sed -i \
    -e "s|.*\"port\".*|\"port\":\"$PORT\",|" \
    /etc/pam_ibm_auth.json
fi


# create the nomfa group and add privileged users
echo "Creating nomfa exemption group and adding root"
groupadd -r nomfa
usermod -aG nomfa root

# starting from a copy of the /etc/pam.d/password-auth file create /etc/pam.d/isv-auth-choice
# the backslash at the beginning avoids alias'd cp and therefore uses non-interactive mode
echo "Creating and configuring PAM config file: /etc/pam.d/isv-auth-choice"
\cp -r /etc/pam.d/password-auth /etc/pam.d/isv-auth-choice

# Update isv-auth-choice file with IVG PAM settings per cookbook
# For more information on settings available: https://www.ibm.com/docs/en/security-verify?topic=configuration-pam-system-file
# Some that might be added for debugging: failmode_insecure accept_on_missing_auth_method
# If you are not mapping usernames to a different ISV user, remove gecos_field
sed -i \
   -e "s|auth\s*sufficient\s*pam_unix.so\(.*\)|auth requisite pam_unix.so\1\nauth sufficient pam_ibm_auth.so auth_method=choice-then-otp exempt_group=nomfa add_devices_to_choice transients_in_choice gecos_field=1 |" \
   /etc/pam.d/isv-auth-choice

# update sshd_config to use ChallengeResponseAuthentication
echo "Updating /etc/ssh/sshd_config to allow challenge-response"
sed -i \
  -e "s|^ChallengeResponseAuthentication\s.*|ChallengeResponseAuthentication yes|" \
  /etc/ssh/sshd_config

# update /etc/pam.d/sshd to enable isv
echo "Updating /etc/pam.d/sshd to use ISV"
sed -i \
  -e "s|auth\s*substack\s*password-auth.*|auth substack isv-auth-choice|" \
  /etc/pam.d/sshd

# create the user that will be performing ssh
# Note that mapped user is made the first (and only) gecos entry
# and this is used via the gecos_field setting passed to the PAM configuration above
echo "Creating test user: $USERNAME"
useradd -p $(openssl passwd -1 "$USERPWD") -c "$MAPPED_USER" "$USERNAME"

echo "Adding login message"
cat <<EOF > /etc/motd
=========================================================================
=
= Congrats - you have successfully performed multi-factor authentication!
=
=========================================================================
EOF

# restart sshd
echo "Restarting sshd"
systemctl restart sshd
echo "DONE!"
