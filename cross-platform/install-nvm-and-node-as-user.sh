#!/usr/bin/env bash
# should be run as USER
set -e

# sudo does work in su's subshell?
if [[ -z "${NVM_DIR:-}" ]]; then
  export NVM_DIR="/opt/nvm"
  export NVM_DIR="$HOME/.nvm"
fi
Say "Installing nvm to $NVM_DIR as $(whoami)" 
script=https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.0/install.sh; 
(wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
Say "Activating nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
Say "nvm install --lts"
nvm install --lts
Say "Node installed as [$(nvm which current)]"
strip $(nvm which current) || true
node_path=$(dirname `nvm which current`)
new_PATH="$PATH:$node_path"
printf "\n\nexport PATH=\"\$PATH:$node_path\"" | tee -a ~/.bashrc
Say "Node Version: $(node --version)"
time npm install yarn --global
time yarn config set network-timeout 600000 -g
nvm cache clear
