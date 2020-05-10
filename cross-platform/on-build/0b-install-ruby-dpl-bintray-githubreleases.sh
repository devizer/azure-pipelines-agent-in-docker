#!/usr/bin/env bash
echo ":ssl_verify_mode: 0" | tee -a ~/.gemrc
Say "Installing ruby-dev via apt"
gem=$(apt-cache search gem | grep -E '^gem ' | awk '{print $1}')
sudo apt-get install -y ruby-dev $gem
Say "Installing dpl dpl-releases dpl-bintray via gem"
sudo gem install dpl dpl-releases dpl-bintray