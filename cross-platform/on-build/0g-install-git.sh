#!/usr/bin/env bash
GIT_VER=${GIT_VER:-v2.25.1}
work=$HOME/build/git-src
mkdir -p $work
pushd $work >/dev/null
sudo apt-get install -y build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext unzip
url=https://codeload.github.com/git/git/zip/$GIT_VER
wget -q --no-check-certificate -O _git-src.zip "$url"  || curl -kfSL -o _git-src.zip "$url"
unzip -q _git-src.zip
rm -f _git-src.zip
cd git*

time make prefix=/usr/local all
sudo make prefix=/usr/local install
cd ../..
rm -rf $(basename $work)
bash -c "git --version"

popd >/dev/null