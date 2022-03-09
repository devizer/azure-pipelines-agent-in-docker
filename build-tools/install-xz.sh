set -eu
sudo apt-get install make autoconf build-essential libtool sudo wget curl htop mc cmake pv jq p7zip xz-utils -y -q

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

work=$HOME/build/xz-5.2.5-src
mkdir -p $work
pushd $work
curl -kSL -o lzma-5.2.5.tar.gz https://raw.githubusercontent.com/devizer/glist/master/bin/lzma-5.2.5.tar.gz
tar xzf lzma-5.2.5.tar.gz
rm -f lzma-5.2.5.tar.gz
cd xz*
Say "configure for xz on [$(uname -m)]"
./configure --prefix="${INSTALL_PREFIX}" --disable-shared
Say "make install for xz on [$(uname -m)]"
sudo make -j install
popd

rm -rf "$work"
