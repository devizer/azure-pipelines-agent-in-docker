#!/usr/bin/env bash
script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-GO.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
echo /usr/local/go/bin > /etc/agent-path.d/go

# GIT_LFS_VER=${GIT_LFS_VER:-v2.11.0}
GIT_LFS_VER=${GIT_LFS_VER:-v2.13.2}
Say "Downloading GIT-LFS $GIT_LFS_VER source from github"
 
work=$HOME/build/git-lfs-src
TRANSIENT_BUILDS="${TRANSIENT_BUILDS:-$HOME/build}"
work=$TRANSIENT_BUILDS/build/git-lfs-src
mkdir -p $work
pushd $work >/dev/null
rm -rf *
# sudo apt-get install -y build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext unzip
git clone https://github.com/git-lfs/git-lfs
cd git-lfs*
git checkout $GIT_LFS_VER
Say "Downloading dependencies for GIT-LFS $GIT_LFS_VER"
time try-and-retry timeout 666 go mod download
Say "Building GIT-LFS $GIT_LFS_VER"
time make -B
sudo mv bin/git-lfs /usr/local/bin/git-lfs

# the right way
go clean -cache

rm -rf ~/go || true

popd
rm -rf $work

Say "Done"
Say "GO cache size: $(du -h -d 1 ~/.cache/go-build || true)"
