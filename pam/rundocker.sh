#!/bin/bash

# READ IN ENV VARS
for i in $(cat .env)
do
  export $i
done

# run it
docker run --rm --detach \
  --privileged \
  -p 127.0.0.1:30222:22/tcp \
  --env TENANT \
  --env API_CLIENT_ID \
  --env API_CLIENT_SECRET \
  --env USERNAME \
  --env USERPWD \
  --env MAPPED_USER \
  --env PORT \
  --name pamdemo \
  pamdemo:latest

echo "The container should be running now. Check with: docker ps -a"
echo "To try it:"
echo "$ ssh -l $USERNAME -p 30222 localhost"
echo "To stop it when done:"
echo "$ docker stop pamdemo"