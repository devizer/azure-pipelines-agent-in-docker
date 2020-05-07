#!/usr/bin/env bash
# should be run as USER
set -e

export NVM_DIR="/opt/nvm"
echo $NVM_DIR | sudo tee /etc/NVM_DIR
sudo mkdir -p $NVM_DIR
sudo chown -R user:user $NVM_DIR
Say "Installing nvm to $NVM_DIR" 
script=https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh; 
(wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
strip $(nvm which current)
node_path=$(dirname `nvm which current`)
new_PATH="$PATH:$node_path"
printf "\n\nPATH=\"${new_PATH}\"" | sudo tee -a /etc/environment
Say "Node Version: $(node --version)"
time npm install yarn --global
time yarn config set network-timeout 600000 -g
nvm cache clear
