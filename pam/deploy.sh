#!/bin/bash
#
# Used to deploy the pamdemo to kubernetes
#

PODNAME=pamdemo

# You could modify the environment variables here, but better to create a .env file with them in it
# The .env file is included in .gitignore and will not be checked inA

TENANT=YOURTENANT.verify.ibm.com
API_CLIENT_ID=YOUR_CLIENT_ID
API_CLIENT_SECRET=YOUR_CLIENT_SECRET
USERNAME="testuser"
USERPWD="Passw0rd"
MAPPED_USER="$USERNAME"
PORT=443

# Allow override of above variables from a local .env file (which is in .gitignore)
# Basically you can create a .env file with those variables above defined in it with your 
# own values, then you do not have to ever modify this script.
if [ -f .env ]
then
. .env
fi

SNAME=$(kubectl get secrets -o "jsonpath={range .items[?(.metadata.name==\"$PODNAME\")]}{.metadata.name}{end}" 2>/dev/null)
if [ ! -z "$SNAME" ]
then
	echo "Removing existing secret: $SNAME"
	kubectl delete secret $SNAME
fi

kubectl create secret generic $PODNAME \
  --from-literal=TENANT=$TENANT \
  --from-literal=API_CLIENT_ID=$API_CLIENT_ID \
  --from-literal=API_CLIENT_SECRET=$API_CLIENT_SECRET \
  --from-literal=USERNAME=$USERNAME \
  --from-literal=USERPWD=$USERPWD \
  --from-literal=MAPPED_USER=$MAPPED_USER \
  --from-literal=PORT=$PORT
 

POD=$(kubectl get pod -o json | jq -r ".items[] | select(.metadata.labels.app==\"$PODNAME\") | .metadata.name")

if [ ! -z "$POD" ]
then 
  echo "Deleting existing pod: $PODNAME"
  kubectl delete pod $PODNAME
fi

PODSVC=$(kubectl get svc -o json | jq -r ".items[] | select(.metadata.name==\"$PODNAME\") | .metadata.name")
if [ ! -z "$PODSVC" ]
then 
  echo "Deleting existing service: $PODSVC"
  kubectl delete service $PODSVC
fi

kubectl create -f "$PODNAME.yaml"
