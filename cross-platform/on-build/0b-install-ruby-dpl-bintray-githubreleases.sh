#!/usr/bin/env bash
echo ":ssl_verify_mode: 0" | tee -a ~/.gemrc
Say "Installing ruby-dev via apt"
sudo apt-get install -y ruby-dev
Say "Installing dpl dpl-releases dpl-bintray via gem"
sudo gem install dpl dpl-releases dpl-bintray