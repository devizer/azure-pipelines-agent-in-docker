url=https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz
work=$HOME/build/autoconf-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _autoconf.tar.gz "$url"
tar xzf _autoconf.tar.gz
cd autoconf*
./configure --prefix="${INSTALL_PREFIX:-/usr/local}" && make -j && make install
popd
rm -rf "$work"
