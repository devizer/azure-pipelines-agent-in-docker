set -eu
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
  ./configure --prefix="${INSTALL_PREFIX:-/usr/local}" && make -j && sudo make install
  popd
  rm -rf "$work"
  Say "Completed: [$key] using [$url]"
}

install-a-gnu-tool "automake-1.16.5" "https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz"
install-a-gnu-tool "m4-1.4.19"       "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
install-a-gnu-tool "autoconf-2.71"   "https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz"
install-a-gnu-tool "libtool-2.4.6"   "https://ftp.gnu.org.ua/gnu/libtool/libtool-2.4.6.tar.gz"
install-a-gnu-tool "make-4.3"        "https://ftp.gnu.org/gnu/make/make-4.3.tar.gz"
install-a-gnu-tool "gawk-5.1.1"      "https://ftp.gnu.org/gnu/gawk/gawk-5.1.1.tar.gz"
install-a-gnu-tool "grep-3.7"        "https://ftp.gnu.org/gnu/grep/grep-3.7.tar.gz"
