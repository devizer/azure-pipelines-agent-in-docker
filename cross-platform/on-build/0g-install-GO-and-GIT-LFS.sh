#!/usr/bin/env bash
script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-GO.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
echo /usr/local/go/bin > /etc/agent-path.d/go

GIT_LFS_VER=${GIT_LFS_VER:-v2.11.0}
Say "Installing GIT-LFS $GIT_LFS_VER from source"
 
work=$HOME/build/git-lfs-src
mkdir -p $work
pushd $work >/dev/null
rm -rf *
# sudo apt-get install -y build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext unzip
git clone https://github.com/git-lfs/git-lfs
cd git-lfs*
git checkout $GIT_LFS_VER
make -B
sudo mv bin/git-lfs /usr/local/bin/git-lfs

# the right way
go clean -cache


popd
rm -rf $work

Say "Done"
Say "GO cache size: $(du -h -d 1 ~/.cache/go-build || true)"
