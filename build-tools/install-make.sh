url=https://ftp.gnu.org/gnu/make/make-4.3.tar.gz
work=$HOME/build/make-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _make.tar.gz "$url"
tar xzf _make.tar.gz
cd make*
time (set -e; ./configure --prefix="${INSTALL_PREFIX:-/usr/local}" && make -j && sudo make install)
popd
rm -rf "$work"
