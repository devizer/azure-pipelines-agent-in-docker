url=https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz
url=https://ftp.gnu.org/gnu/automake/automake-1.15.1.tar.gz
url=https://ftp.gnu.org/gnu/automake/automake-1.14.1.tar.gz
work=$HOME/automake-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _automake.tar.gz "$url"
tar xzf _automake.tar.gz
cd automake*
./configure && make -j && make install
popd
rm -rf "$work"