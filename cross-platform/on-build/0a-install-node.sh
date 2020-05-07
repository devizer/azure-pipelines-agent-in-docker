#!/usr/bin/env bash

# same as install git
sudo apt-get install -y -qq build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext unzip

export NVM_DIR=/opt/nvm
Say "Installing NodeJS LTS as $(whoami)";
mkdir -p $NVM_DIR
chown -R user:user $NVM_DIR
echo $NVM_DIR | sudo tee /etc/NVM_DIR

su -c 'export HOME=/home/user; export NVM_DIR='$NVM_DIR'; bash -e ../install-nvm-and-node-as-user.sh' user

# script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s node;

# yarn config set network-timeout 600000 -g

