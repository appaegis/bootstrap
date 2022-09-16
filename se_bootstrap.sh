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
    echo "Install docker"
    if uname -a |grep amzn2 &> /dev/null
    then
    # for Amazon Linux 2
        sudo yum update
        sudo yum install docker
        sudo systemctl enable docker.service
        sudo systemctl start docker.service
    else
    # for other Linux
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
    fi
fi


## test and install docker-compose
if ! command -v docker-compose &> /dev/null
then
    echo "Install docker-compose"
    ARCH=$(uname -m)
    if [ "$ARCH" = "armv7l" ]; then
        ARCH="armv7"
    fi
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$ARCH" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi


## setup docker-compose
export auth_token=$1
export auth_secret=$2
export server_validation_code=$3
export server_addr=$4
export network_type=$5
export network_name=$6
export service_edge_number=$7
export label=$8      # only applicable to device-mesh, should be unique
export serialno=$9   # only applicable to device-mesh, must be unique
export proxyUrl=$10  # if need to connect through proxy. Format is http://[username:password@]proxyAddr


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
      - auth_token="$auth_token"
      - auth_secret="$auth_secret"
      - server_validation_code="$server_validation_code"
      - server_addr="$server_addr"
      - network_type="$network_type"
      - network_name="$network_name"
      - service_edge_number="$service_edge_number"
      - HTTP_PROXY=$proxyUrl
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
sudo docker-compose up --detach --force-recreate --remove-orphans


