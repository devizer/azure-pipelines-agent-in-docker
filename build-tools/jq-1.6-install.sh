set -eu
sudo apt-get install make autoconf build-essential libtool sudo wget curl htop mc cmake pv jq p7zip xz-utils -y -qq

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

work=$HOME/src/jq-1.6
mkdir -p $work
pushd $work
curl -kSL -o jq-1.6.tar.gz https://github.com/stedolan/jq/releases/download/jq-1.6/jq-1.6.tar.gz
tar xzf jq-1.6.tar.gz
rm -f jq-1.6.tar.gz
cd jq*
autoreconf -fi
./configure --prefix="${INSTALL_PREFIX}" --disable-maintainer-mode
sudo make -j install
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
