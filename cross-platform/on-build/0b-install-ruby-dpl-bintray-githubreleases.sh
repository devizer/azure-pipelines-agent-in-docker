#!/usr/bin/env bash
echo ":ssl_verify_mode: 0" | tee -a ~/.gemrc
source /etc/os-relase
if [[ "$VERSION_ID" == "8" && "$ID" == "debian" ]]; then
    Say "Skipping dpl, dpl-releases, dpl-bintray on Debian Jessie";
else
    Say "Installing ruby-dev via apt"
    # gem=$(apt-cache search gem | grep -E '^gem ' | awk '{print $1}')
    sudo apt-get install -y ruby-dev
    Say "Installing dpl dpl-releases dpl-bintray via gem"
    sudo gem install dpl dpl-releases dpl-bintray
fi