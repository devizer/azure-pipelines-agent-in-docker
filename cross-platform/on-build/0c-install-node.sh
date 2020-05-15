#!/usr/bin/env bash

# same as install git
sudo apt-get install -y -qq build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext unzip

Say "Installing NodeJS LTS as $(whoami)";

source /etc/os-release
if true || [[ "$VERSION_ID" == "10" && "$ID" == "debian" ]]; then
    # network does not work properly for Buster over qemu
    Say "Installing Node LTS using custom installer"
    script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s node
    node_path=$(dirname $(ls -1 /opt/node/node*/bin/node))
    Say "New node_path via custom node installer is: [$node_path]"
else
    export NVM_DIR=/opt/nvm
    mkdir -p $NVM_DIR
    chown -R user:user $NVM_DIR
    echo $NVM_DIR | sudo tee /etc/NVM_DIR
    su -c 'export HOME=/home/user; export NVM_DIR='$NVM_DIR'; bash -e ../install-nvm-and-node-as-user.sh' user
    
    Say "Looking for node path as $(whoami) for /etc/environment"
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
    node_path=$(dirname `nvm which current || true` || true)
fi

Say "Store node path for /etc/environment: [$node_path]"
source /etc/environment
new_PATH="$PATH:$node_path"
sed '/PATH/d' /etc/environment
printf "\nPATH=${new_PATH}\n" | sudo tee /etc/environment

# script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s node;

# yarn config set network-timeout 600000 -g

