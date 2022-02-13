url=https://ftp.gnu.org.ua/gnu/libtool/libtool-2.4.6.tar.gz
work=$HOME/build/libtool-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _libtool.tar.gz "$url"
tar xzf _libtool.tar.gz
cd libtool*
./configure --prefix="${INSTALL_PREFIX:-/usr/local}" && make -j && make install
popd
rm -rf "$work"
