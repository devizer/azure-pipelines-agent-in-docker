#!/usr/bin/env bash
GIT_VER=${GIT_VER:-v2.26.2}
work=$HOME/build/git-src
mkdir -p $work
pushd $work >/dev/null
smart-apt-install build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip 
url=https://codeload.github.com/git/git/zip/$GIT_VER
wget -q --no-check-certificate -O _git-src.zip "$url"  || curl -kfSL -o _git-src.zip "$url"
unzip -q _git-src.zip
rm -f _git-src.zip
cd git*

cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
time make prefix=/usr/local all -j${cpus}
sudo make prefix=/usr/local install
cd ../..
rm -rf $(basename $work)
bash -c "git --version"

popd >/dev/null

Say "Strip git"
pushd /usr/local/libexec/git-core
strip * || true
popd