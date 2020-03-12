#!/usr/bin/env bash

Say "Installing the latest docker from the official docker repo"
# Recommended: aufs-tools cgroupfs-mount | cgroup-lite pigz libltdl7
source /etc/os-release
smart-apt-install apt-transport-https ca-certificates curl gnupg2 software-properties-common 
try-and-retry bash -c "curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo apt-key add -"

try-and-retry sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
try-and-retry sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 7EA0A9C3F273FCD8
sudo add-apt-repository \
 "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$ID \
 $(lsb_release -cs) \
 stable"
sudo apt-get update
apt-cache policy docker-ce-cli
sudo apt-get install -y docker-ce-cli pigz
sudo usermod -aG docker user || true
sudo docker version || true

Say "Installing docker-compose 1.24.1"
# sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
dock_comp_ver=1.25.0 # is not yet compiled for arm64
dock_comp_ver=1.24.1 # compiled for both armv7 and v7
sudo curl --fail -ksSL -o /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/$dock_comp_ver/docker-compose-$(uname -s)-$(uname -m)" || true
if [[ ! -f /usr/local/bin/docker-compose ]]; then
  sudo curl --fail -ksSL -o /usr/local/bin/docker-compose "https://raw.githubusercontent.com/devizer/test-and-build/master/docker-compose/$dock_comp_ver/docker-compose-$(uname -s)-$(uname -m)" || true    
fi
if [[ -f /usr/local/bin/docker-compose ]]; then
  sudo chmod +x /usr/local/bin/docker-compose
else
  Say "docker-compose $dock_comp_ver can not be installed for $(uname -s) $(uname -m)" 
fi
