#!/usr/bin/env bash

source /etc/os-release
if false && [[ "${VERSION_ID:-}" == "8" && "$ID" == "debian" ]]; then
  Say "SKIPPING Docker for jessie"
  exit 0;
fi 

Say "Installing the latest docker from the official docker repo"
# Recommended: aufs-tools cgroupfs-mount | cgroup-lite pigz libltdl7
source /etc/os-release
smart-apt-install apt-transport-https ca-certificates curl gnupg2 software-properties-common pigz 
try-and-retry bash -c "curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo apt-key add -"

# try-and-retry timeout 100 sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D 
# try-and-retry timeout 100 sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D 
  curl -fksSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || true
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - || true
  true

# second is optional
# try-and-retry sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 7EA0A9C3F273FCD8
if [[ "$UBUNTU_CODENAME" == focal ]]; then
  # bionic also works
  echo "deb https://download.docker.com/linux/ubuntu eoan stable" | sudo tee /etc/apt/sources.list.d/docker.list
elif [[ "$PRETTY_NAME" == *"bullseye/sid"* ]]; then
  echo "deb https://download.docker.com/linux/debian buster stable" | sudo tee /etc/apt/sources.list.d/docker.list
else
 sudo add-apt-repository \
 "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$ID $(lsb_release -cs) stable"
fi

sudo apt-get update --allow-unauthenticated || sudo apt-get update --allow-unauthenticated || sudo apt-get update --allow-unauthenticated

# Debian 8 has docker-ce only
if [[ "$VERSION_ID" == "8" && "$ID" == "debian" ]]; then
    apt-cache policy docker-ce
    smart-apt-install docker-ce
    systemctl disable docker.service
    systemctl disable docker.socket
    rm -f /usr/bin/dockerd
else
    apt-cache policy docker-ce-cli
    smart-apt-install docker-ce-cli 
fi
sudo groupadd docker || true
sudo usermod -aG docker user || true
sudo docker version || true

echo '
alias docker="sudo docker"
alias docker-compose="sudo docker-compose"
' >> /home/user/.bashrc

mkdir -p /home/user/.docker /root/.docker || true
echo '{ "experimental": "enabled" }' | tee /home/user/.docker/config.json || true
echo '{ "experimental": "enabled" }' | tee /root/.docker/config.json || true
chown -R user /home/user

smart-apt-install python3-pip python3-dev libffi-dev libssl-dev

if [[ $(uname -m) == x86_64 ]]; then 
    Say "Installing precompiled docker-compose 1.26.2 for $(uname -m)"
    # sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    dock_comp_ver=1.25.0 # is not yet compiled for arm64
    dock_comp_ver=1.24.1 # compiled for both armv7 and v7
    dock_comp_ver=1.26.2
    sudo curl --fail -ksSL -o /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/$dock_comp_ver/docker-compose-$(uname -s)-$(uname -m)" || true
    if [[ ! -f /usr/local/bin/docker-compose ]]; then
      sudo curl --fail -ksSL -o /usr/local/bin/docker-compose "https://raw.githubusercontent.com/devizer/test-and-build/master/docker-compose/$dock_comp_ver/docker-compose-$(uname -s)-$(uname -m)" || true    
    fi
    if [[ -f /usr/local/bin/docker-compose ]]; then
      sudo chmod +x /usr/local/bin/docker-compose
    else
      Say "docker-compose $dock_comp_ver can not be installed for $(uname -s) $(uname -m)" 
    fi
 else
    
    Say "Installing docker-compose 1.26.2 for $(uname -m) using pip3"
    # sudo apt-get install -y python3-pip libffi-dev libssl-dev
    # optional
    sudo -H pip3 install --no-cache-dir --upgrade pip || sudo -H pip3 install --upgrade pip
    # build/install
    # time sudo pip3 install --no-cache-dir docker-compose==1.26.2 || time sudo pip3 install docker-compose==1.26.2
    export CRYPTOGRAPHY_DONT_BUILD_RUST=1
    time pip3 install --no-cache-dir docker-compose==1.28.2 || time sudo pip3 install docker-compose==1.28.2
 fi
