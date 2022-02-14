url=https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz
work=$HOME/build/m4-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _m4.tar.gz "$url"
tar xzf _m4.tar.gz
cd m4*
./configure --prefix="${INSTALL_PREFIX:-/usr/local}" && make -j && sudo make install
popd
rm -rf "$work"
