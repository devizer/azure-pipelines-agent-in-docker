#!/usr/bin/env bash
set -eu
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

apt-get install git libncurses-dev -y -qq


url="https://ftp.gnu.org/gnu/nano/nano-6.0.tar.gz"
file="$(basename "$url")"
work=$HOME/build/nano-src
mkdir -p "$work"
pushd "$work"
rm -rf "$work/*"
Say "Downloading $url"
curl -kSL -o _$file "$url" || wget -O _$file --no-check-certificate "$url"
tar xzf _$file
cd nano*
time ./configure --prefix="${INSTALL_PREFIX}"
make -j
make install

  
  cmd="find \"${INSTALL_PREFIX}/share/nano/\" -name \"*.nanorc\" | wc -l"
  Say "Installing extra syntax highlighters. Before: $(eval "$cmd")"
  git clone https://github.com/scopatz/nanorc nanorc-src || true
  cd nanorc-src
  cp -f *.nanorc ${INSTALL_PREFIX}/share/nano
  Say "Added extra syntax highlighters. After: $(eval "$cmd")"

  # include "~/.nano/apacheconf.nanorc"
  pushd "${INSTALL_PREFIX}/share/nano" >/dev/null
  mkdir -p "${INSTALL_PREFIX}/etc"
  for f in *.nanorc; do
    echo "include \"$(pwd)/$f\"" >> "${INSTALL_PREFIX}/etc/nanorc"
  done
  popd >/dev/null

popd
rm -rf "$work"; rm -rf "$work"; 


echo '
configure: WARNING: The 'time_t' type stops working after January 2038,
            and this package needs a wider 'time_t' type
            if there is any way to access timestamps after that.
            Configure with 'CC="gcc -std=gnu99 -m64"' perhaps?
'>/dev/null
