#!/bin/bash

# READ IN ENV VARS
for i in $(cat .env)
do
  export $i
done

# run it
docker run --rm --detach \
  --privileged \
  -p 127.0.0.1:30123:1812/udp \
  --env TENANT \
  --env API_CLIENT_ID \
  --env API_CLIENT_SECRET \
  --env RADIUS_CLIENT_SECRET \
  --env PORT \
  --name radiusdemo \
  radiusdemo:latest

echo "The container should be running now. Check with: docker ps -a"
echo "To stop it when done:"
echo "$ docker stop radiusdemo"
