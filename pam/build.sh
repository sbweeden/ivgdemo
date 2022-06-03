#!/bin/bash

# Check for the existence of some zip file in the resources directory as if there is nothing 
# then likely the user has not downloaded the IVG package:

if ! ls resources/*zip 1> /dev/null 2>&1
then
  echo "It does not look like you have the ISVGForLinuxPAMxxx.zip file in the resources directory."
  echo "Please download it from the IBM App Exchange: https://exchange.xforce.ibmcloud.com/hub/IdentityandAccess"
  echo "Exiting!"
  exit 1
fi

# Build - including support for building on my M1 Mac
if uname -a | grep -q arm64
then
  # This is how I build it on an M1 Mac and push straight to a target container registry
  # You change the target registry and/or remove the --push as needed
  docker buildx build --push --platform linux/amd64 --tag ubuntu-k8s:32000/pamdemo:latest .
else
  # This is typical on an intel system
  docker build --tag pamdemo:latest .
fi
