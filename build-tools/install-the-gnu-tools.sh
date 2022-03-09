#!/usr/bin/env bash
set -eu
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
function install-a-gnu-tool() {
  local key="$1"
  local url="$2"
  Say "Installing [$key] using [$url]"
  local work=$HOME/build/${key}-src
  mkdir -p "$work"
  pushd .
  cd $work && rm -rf *
  local file="${TMPDIR:-/tmp}/_${key}.archive"
  try-and-retry curl -kSL -o "$file" "$url"
  tar xzf "$file"
  rm -f "$file"
  cd *
  if [[ -x ./configure ]]; then
    ./configure --prefix="${INSTALL_PREFIX:-/usr/local}" --disable-shared && make -j && sudo make install
  else
    # bzip2
    sudo make install PREFIX="${INSTALL_PREFIX:-/usr/local}"
  fi
  popd
  rm -rf "$work"
  Say "Completed: [$key] using [$url]"
}

install-a-gnu-tool "bzip2-1.0.8"     "https://sourceware.org/pub/bzip2/bzip2-latest.tar.gz"
install-a-gnu-tool "gzip-1.11"       "https://ftp.gnu.org/gnu/gzip/gzip-1.11.tar.gz"
install-a-gnu-tool "xz-5.2.5"        "https://raw.githubusercontent.com/devizer/glist/master/bin/lzma-5.2.5.tar.gz"
install-a-gnu-tool "tar-1.34"        "https://ftp.gnu.org/gnu/tar/tar-1.34.tar.gz"

install-a-gnu-tool "sed-4.8"         "https://ftp.gnu.org/gnu/sed/sed-4.8.tar.gz"
install-a-gnu-tool "automake-1.16.5" "https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz"
install-a-gnu-tool "m4-1.4.19"       "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
install-a-gnu-tool "autoconf-2.71"   "https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz"
install-a-gnu-tool "libtool-2.4.6"   "https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.gz"
install-a-gnu-tool "make-4.3"        "https://ftp.gnu.org/gnu/make/make-4.3.tar.gz"
install-a-gnu-tool "gawk-5.1.1"      "https://ftp.gnu.org/gnu/gawk/gawk-5.1.1.tar.gz"
install-a-gnu-tool "grep-3.7"        "https://ftp.gnu.org/gnu/grep/grep-3.7.tar.gz"

function try-symlink() {
  if cmp -s "$1" "$2" && test -s "$1" && test -s "$2"; then ln -f -s "$2" "$1"; fi
}

pushd "${INSTALL_PREFIX:-/usr/local}"
echo "BEFORE STRIP: $(du . --max-depth=0)"
pushd .
find . -name '*.so*' -type f -exec strip {} \;
cd bin
strip * || true
try-symlink gawk gawk-5.1.1
try-symlink automake automake-1.16
try-symlink aclocal aclocal-1.16
popd
echo "AFTER STRIP: $(du . --max-depth=0)"
popd

# https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.gz