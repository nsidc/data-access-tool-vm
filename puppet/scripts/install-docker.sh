#!/bin/bash
# Install docker and compose. Must be run by a sudoer.

######################
# docker
######################
DOCKER_VERSION="18.06.1~ce~3-0~ubuntu"

sudo apt-get update
sudo apt-get install -y\
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update
sudo apt-get install -y docker-ce=$DOCKER_VERSION

######################
# docker-compose
######################
COMPOSE_VERSION="1.23.1"

sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
