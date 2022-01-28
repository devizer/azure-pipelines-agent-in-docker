#!/usr/bin/env bash
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

smart-apt-install libncurses-dev

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

function _skip_extra_highlighters_() {
  cmd="find \"${INSTALL_PREFIX}/share/nano/\" -name \"*.nanorc\" | wc -l"
  Say "Installing extra syntax highlighters. Before: $(eval "$cmd")"
  git clone https://github.com/scopatz/nanorc nanorc-src || true
  cd nanorc-src
  cp -f *.nanorc ${INSTALL_PREFIX}/share/nano
  Say "Added extra syntax highlighters. After: $(eval "$cmd")"
}

popd
rm -rf "$work"; rm -rf "$work"; 


echo '
configure: WARNING: The 'time_t' type stops working after January 2038,
            and this package needs a wider 'time_t' type
            if there is any way to access timestamps after that.
            Configure with 'CC="gcc -std=gnu99 -m64"' perhaps?
'>/dev/null
