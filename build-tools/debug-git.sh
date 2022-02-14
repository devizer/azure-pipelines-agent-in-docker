#!/usr/bin/env bash
work=$HOME/git
mkdir -p $work && cd $work && rm -rf *
curl -kSL https://github.com/devizer/azure-pipelines-agent-in-docker/tarball/master | tar -xz
cd devizer-azure-pipelines-agent*
cd build-tools

function _ignore_() {
test -f /etc/os-release && source /etc/os-release
OS_VER="${ID:-}:${VERSION_ID:-}"
if [[ "$OS_VER" == "debian:7" ]]; then 
  for tool in install-automake.sh install-m4.sh install-autoconf.sh install-libtool.sh; do
    export INSTALL_PREFIX=/usr/local
    Say "INSTALLING [$tool] into [$INSTALL_PREFIX] for $OS_VER";
    time bash -e "$tool";
    Say "Completed: INSTALL [$tool] into [$INSTALL_PREFIX] for $OS_VER";
  done 
fi
}

export INSTALL_PREFIX=/opt/local-links/git
# TEST 2.35.1 on debian 10
export CFLAGS="-std=gnu99" CPPFLAGS="-std=gnu99" CXXFLAGS="-std=gnu99"
bash -eu install-git.sh

function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum "'"$file"'" | awk '{print $1}')
      printf "$sum" > "$file.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}
cd /opt/local-links/git
DEPLOY_DIR=/git-release to=git-v2.34.1-arm32v7
mkdir -p $DEPLOY_DIR
Say "Repack $DEPLOY_DIR/$to.tar.gz"
tar cf - . | gzip -9 > $DEPLOY_DIR/$to.tar.gz
build_all_known_hash_sums $DEPLOY_DIR/$to.tar.gz
Say "Repack $DEPLOY_DIR/$to.tar.xz"
tar cf - . | xz -z -9 -e > $DEPLOY_DIR/$to.tar.xz
build_all_known_hash_sums $DEPLOY_DIR/$to.tar.xz



