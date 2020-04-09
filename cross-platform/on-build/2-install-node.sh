#!/usr/bin/env bash

Say "Installing NodeJS LTS";
su -c 'export HOME=/home/user; bash -e ../install-nvm-and-node-as-user.sh' user

# script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s node;

yarn config set network-timeout 600000 -g

