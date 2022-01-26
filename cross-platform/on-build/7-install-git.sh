#!/usr/bin/env bash
# GIT_VER=${GIT_VER:-v2.26.2}
# GIT_VER=${GIT_VER:-v2.28.0}
GIT_VER=${GIT_VER:-v2.34.1}
TRANSIENT_BUILDS="${TRANSIENT_BUILDS:-$HOME/build}"
work=$TRANSIENT_BUILDS/build/git-src
mkdir -p $work
pushd $work >/dev/null
smart-apt-install build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip 
url=https://codeload.github.com/git/git/zip/$GIT_VER
wget -q --no-check-certificate -O _git-src.zip "$url"  || curl -kfSL -o _git-src.zip "$url"
unzip -q _git-src.zip
rm -f _git-src.zip
cd git*

Say "GCC $(gcc --version)"
cpus=$(nproc)
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
time make prefix="$INSTALL_PREFIX" all -j${cpus}
sudo make prefix="$INSTALL_PREFIX" install
sudo strip "$INSTALL_PREFIX/bin/*" || true
sudo strip "$INSTALL_PREFIX/libexec/git-core/*" || true
cd ../..
rm -rf $(basename $work)
export PATH="$INSTALL_PREFIX/bin:$PATH"
bash -c "git --version"

popd >/dev/null

Say "Strip git"
pushd /usr/local/libexec/git-core
strip * || true
popd

Say "git version"
git --version
Say "Force git http version to HTTP/1.1"
git config --global http.version HTTP/1.1
Say "git configuration"
git config -l

