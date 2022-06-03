#!/bin/bash
#
# Used to cleanup kubernetes artifacts for the pamdemo
#

PODNAME=pamdemo

SNAME=$(kubectl get secrets -o "jsonpath={range .items[?(.metadata.name==\"$PODNAME\")]}{.metadata.name}{end}" 2>/dev/null)
if [ ! -z "$SNAME" ]
then
	echo "Removing secret: $SNAME"
	kubectl delete secret $SNAME
fi

POD=$(kubectl get pod -o json | jq -r ".items[] | select(.metadata.labels.app==\"$PODNAME\") | .metadata.name")
if [ ! -z "$POD" ]
then 
  echo "Deleting pod: $PODNAME"
  kubectl delete pod $PODNAME
fi

PODSVC=$(kubectl get svc -o json | jq -r ".items[] | select(.metadata.name==\"$PODNAME\") | .metadata.name")
if [ ! -z "$PODSVC" ]
then 
  echo "Deleting service: $PODSVC"
  kubectl delete service $PODSVC
fi

