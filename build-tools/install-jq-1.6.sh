set -eu
# jq? missong on raspbian:7
sudo apt-get install make autoconf build-essential libtool sudo wget curl htop mc cmake pv p7zip xz-utils -y -q

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

work=$HOME/build/jq-1.6-src
mkdir -p $work
pushd $work
curl -kSL -o jq-1.6.tar.gz https://github.com/stedolan/jq/releases/download/jq-1.6/jq-1.6.tar.gz
tar xzf jq-1.6.tar.gz
rm -f jq-1.6.tar.gz
cd jq*
Say "autoreconf for jq on [$(uname -m)]"
autoreconf -fi
Say "configure for jq on [$(uname -m)]"
./configure --prefix="${INSTALL_PREFIX}" --disable-maintainer-mode --with-oniguruma=builtin
Say "make install for jq on [$(uname -m)]"
sudo make -j install
Say "strip for jq on [$(uname -m)]"
if [[ -d "${INSTALL_PREFIX}/bin" ]]; then
  pushd "${INSTALL_PREFIX}/bin"
    strip jq onig* || true
  popd
fi
if [[ -d "${INSTALL_PREFIX}/lib" ]]; then
  pushd "${INSTALL_PREFIX}/lib"
    strip *libjq*so* *libonig*so* || true
  popd
fi

popd

rm -rf "$work"
