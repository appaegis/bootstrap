#!/usr/bin/env bash

##
## Bootstrap Appaegis Service Edge container on a Linux host
##


## prepare working directory
mkdir -p se
cd se


## test and install docker
if ! command -v docker &> /dev/null
then
    echo "Install Docker"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
fi


## test and install docker-compose
if ! command -v docker-compose &> /dev/null
then
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi


## copy yaml file
cat << EOF > docker-compose.yml
version: '3'

services:
  se2:
    image: appaegis/se:latest
    network_mode: host
    restart: always
    depends_on:
      - updater
    environment:
      - auth_token
      - auth_secret
      - server_validation_code
      - server_addr
      - network_type
      - network_name
      - service_edge_number
    volumes:
      - ./:/home/se/conf/
    logging:
      driver: "json-file"
      options:
        max-size: "2m"
        max-file: "10"
        compress: "true"
  updater:
    image: appaegis/updater:latest
    network_mode: host
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --debug --label-enable=true --http-api=true
EOF


## setup docker-compose
export auth_token=$1
export auth_secret=$2
export server_validation_code=$3
export server_addr=$4
export network_type=$5
export network_name=$6
export service_edge_number=$7
export label=$8      # optional, should be unique
export serialno=$9   # optional, must be unique


## auto generate metadata.conf file
if [ $network_type = "devicemesh" ] && [ ! -f "metadata.conf" ]
then
    if [ -z "$serialno" ]; then serialno=$(cat /etc/machine-id | tr -d '\n'); fi
    echo -e "\n\
type:       devicemgmt  \n\
label:      $label      \n\
serialno:   $serialno   \n\
hostname:   $(hostname) \n\
privateip:  $(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p') \n\
gateway:    $(ip route show default      | sed -n 's/.*via \([0-9.]\+\).*/\1/p')" > metadata.conf
fi


## run docker-compose
hash -r
docker-compose up --detach --force-recreate --remove-orphans


