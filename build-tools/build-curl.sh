set -eu; set -o pipefail
cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
machine=$(uname -m); 
[[ $machine == aarch64 ]] && machine=arm64v8
[[ $machine == armv* ]] && machine=arm32v7
[[ "$(dpkg --print-architecture)" == armel ]] && machine=arm32v5

Say "Building curl. Suffix: [-${machine}]"
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"
CONFIG_LOG="$SYSTEM_ARTIFACTSDIRECTORY/config-logs"; mkdir -p "$CONFIG_LOG"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

utils_fixed_url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/58e96809ba79e162b901095fad1c6555bb91b746/4gcc/build-gcc-utilities.sh
try-and-retry curl -kSL -o /tmp/build-gcc-utilities.sh "${utils_fixed_url}"
source /tmp/build-gcc-utilities.sh

function Add-LD-Path() {
  local tmp="$(mktemp)"
  for dir in $*; do Say "Permanent ld path: [$dir]"; echo $dir >> "$tmp"; done
  cat /etc/ld.so.conf >> "$tmp"; mv -f "$tmp" /etc/ld.so.conf
  ldconfig || true
}

Say "Install gcc 11.2"
export GCC_INSTALL_VER=11 GCC_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/install-gcc.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
Say "Install cmake and gnu build tools"
script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | INSTALL_DIR=/usr/local TOOLS="gnu-tools cmake" bash

Add-LD-Path /usr/local/lib /usr/local/lib64

export DEBIAN_FRONTEND=noninteractive
export TRANSIENT_BUILDS=/transient-builds
export OPENSSL_HOME=/opt/networking
# preprare /opt/networking paths
mkdir -p "$OPENSSL_HOME/lib" "$OPENSSL_HOME/lib64" "$OPENSSL_HOME/bin"
export PATH="$OPENSSL_HOME/bin:$PATH"
Add-LD-Path "$OPENSSL_HOME/lib" "$OPENSSL_HOME/lib64"

export OPENSSL_VERSION="1.1.1m"

export CFLAGS="-Wno-error -O3 -Wno-error=implicit-function-declaration"


# rm -rf $OPENSSL_HOME
Say "Building OpenSSL $OPENSSL_VERSION to [$OPENSSL_HOME]"
# script=https://raw.githubusercontent.com/devizer/w3top-bin/master/tests/openssl-1.1-from-source.sh
# file=/tmp/openssl-1.1.1.sh
# try-and-retry wget --no-check-certificate -O $file $script 2>/dev/null || curl -ksSL -o $file $script
# source $file
Say "System OpenSSL Version: $(get_openssl_system_version)"
bash -c "while true; do sleep 5; printf '\u2026\n'; done" &
pid=$!

function install_openssl_111() {
  OPENSSL_HOME=${OPENSSL_HOME:-/opt/openssl}
  OPENSSL_VERSION="${OPENSSL_VERSION:-1.1.1m}"

  command -v apt-get 1>/dev/null &&
     (apt-get update -q; apt-get install build-essential make autoconf libtool zlib1g-dev curl wget -y -q)
  if [[ "$(command -v dnf)" != "" ]]; then
     (dnf install gcc make autoconf libtool perl zlib-devel curl wget -y -q)
  fi
  if [[ "$(command -v zypper)" != "" ]]; then
     zypper -n in -y gcc make autoconf libtool perl zlib-devel curl tar gzip wget
  fi

  url=https://www.openssl.org/source/openssl-1.1.1m.tar.gz
  file=$(basename $url)
  local work=$HOME/build/open-ssl-1.1
  mkdir -p $work
  rm -rf $work/* || true
  pushd $work
  curl -kSL -o _$file $url || curl -kSL -o _$file $url
  tar xzf _$file
  cd open*

  Say "Configuring OpenSSL"
  march=""
  if [[ "$(dpkg --print-architecture)" == "armel" ]]; then march="-march=armv4t"; fi
  export CFLAGS="${CFLAGS:-} $march"
  export CXXFLAGS="$CFLAGS"
  Say "CFLAGS: [$CFLAGS]"
  ./config enable-rc5 enable-md2 --prefix=$OPENSSL_HOME --openssldir=$OPENSSL_HOME |& tee "$CONFIG_LOG/openssl.txt"
  perl configdata.pm --dump |& tee -a "$CONFIG_LOG/openssl.txt" || true
  Say "Compiling OpenSSL"
  time make -j${cpus} |& tee "$HOME/log-openssl-make.log"
  # make test
  Say "Installing OpenSSL (silent)"
  time make install -j$((cpus+3)) >"$HOME/log-openssl-install.log" 2>&1
  Say "Complete OpenSSL"
  popd
  # rm -rf $work
}

sudo apt-get install libncursesw5-dev libncurses5-dev -y -q; apt-get purge libssl-dev
install_openssl_111 # > /dev/null
ldconfig

export CFLAGS="-I${OPENSSL_HOME}/include" CPPFLAGS="-I${OPENSSL_HOME}/include" LDFLAGS="-L${OPENSSL_HOME}/lib -L${OPENSSL_HOME}/lib64" PKG_CONFIG_PATH="${OPENSSL_HOME}/lib64/pkgconfig:${OPENSSL_HOME}/lib/pkgconfig"

function _IGNORE_openldap() {
  Say "Building openldap"
  apt-get install groff -y -q | grep -E "^Setting"
  url=https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz
  work=$HOME/build/libldap-src
  mkdir -p $work
  cd $work
  curl -kSL -o _source.tar.gz "$url"
  tar xzf _source.tar.gz
  cd open*
  rm -rf /opt/ldap
  ./configure --disable-slapd --prefix="$OPENSSL_HOME" |& tee "$CONFIG_LOG/openldap.txt" && make -j depend && make -j && make install -j
  rm -f "$OPENSSL_HOME/bin/ldap"*
}


Say "Building libpsl (public domain suffix list)"
url=https://github.com/rockdaboot/libpsl/releases/download/0.21.1/libpsl-0.21.1.tar.gz
work=$HOME/build/libpls-src
mkdir -p $work
cd $work
curl -kSL -o _source.tar.gz "$url"
tar xzf _source.tar.gz
cd lib*
./configure --prefix="$OPENSSL_HOME" |& tee "$CONFIG_LOG/libpls.txt" && make -j && make install -j

Say "Building libidn2 (international domanin names)"
url=https://ftp.gnu.org/gnu/libidn/libidn2-2.3.2.tar.gz
work=$HOME/build/libidn2-src
mkdir -p $work
cd $work
curl -kSL -o _source.tar.gz "$url"
tar xzf _source.tar.gz
cd lib*
./configure --prefix="$OPENSSL_HOME" |& tee "$CONFIG_LOG/libidn2.txt" && make -j && make install -j


Say "Building libssh2"
url=https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
work=$HOME/build/libssh2-src
mkdir -p $work
cd $work
curl -kSL -o _source.tar.gz "$url"
tar xzf _source.tar.gz
cd lib*
mkdir -p builddir; cd builddir
cmake -DCMAKE_INSTALL_PREFIX=$OPENSSL_HOME -DENABLE_ZLIB_COMPRESSION:BOOL=ON -DCRYPTO_BACKEND:STRING=OpenSSL .. |& tee "$CONFIG_LOG/libssh2.txt"
make install -j


Say "Building brotli"
# https://github.com/google/brotli
url=https://github.com/google/brotli/tarball/v1.0.9
work=$HOME/build/brotli-src
mkdir -p $work; cd $work
curl -kSL -o _source.tar.gz "$url"
tar xzf _source.tar.gz
cd google-brotli*
mkdir -p out; cd out
# cmake -LH ..
cmake -DCMAKE_INSTALL_PREFIX=$OPENSSL_HOME -DCMAKE_BUILD_TYPE:STRING=Release .. |& tee "$CONFIG_LOG/brotli.txt"
time make install -j
ldconfig


Say "Building zstd"
url=https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz
work=$HOME/build/zstd-src
mkdir -p $work
cd $work
curl -kSL -o _source.tar.gz "$url"
tar xzf _source.tar.gz
cd zstd*
cd build/cmake
mkdir -p builddir; cd builddir
cmake -DCMAKE_INSTALL_PREFIX=$OPENSSL_HOME -DZSTD_PROGRAMS_LINK_SHARED:BOOL=ON .. |& tee "$CONFIG_LOG/zstd.txt"
make install -j
ldconfig

Say "Building nghttp2"
# https://github.com/nghttp2/nghttp2
# apt-get install libc-ares-dev libev-dev -y -qq | grep "Unpacking\|Setting" || true # for nghttp, nghttpd, nghttpx and h2load
url=https://github.com/nghttp2/nghttp2/releases/download/v1.46.0/nghttp2-1.46.0.tar.gz
work=$HOME/build/nghttp2-src
mkdir -p $work
cd $work
try-and-retry curl -kSL -o _nghttp2.tar.gz "$url"
tar xzf _nghttp2.tar.gz
cd nghttp*
mkdir build-cmake; cd build-cmake
cmake -DCMAKE_INSTALL_PREFIX=$OPENSSL_HOME .. |& tee "$CONFIG_LOG/libssh2.txt"
make -j install
ldconfig

Say "Building curl"
work=$HOME/build/curl-src
mkdir -p $work
pushd $work && rm -rf *
url=https://github.com/curl/curl/releases/download/curl-7_65_3/curl-7.65.3.tar.gz
url=https://github.com/curl/curl/releases/download/curl-7_59_0/curl-7.59.0.tar.gz
url=https://github.com/curl/curl/releases/download/curl-7_44_0/curl-7.44.0.tar.gz
url=https://github.com/curl/curl/releases/download/curl-7_43_0/curl-7.43.0.tar.gz
url=https://github.com/curl/curl/releases/download/curl-7_69_1/curl-7.69.1.tar.gz
url=https://github.com/curl/curl/releases/download/curl-7_81_0/curl-7.81.0.tar.gz
file=$(basename $url)
try-and-retry curl -kSL -o _$file $url || wget --no-check-certificate -O _$file $url 2>/dev/null
tar xzf _$file
cd curl*
# ./configure --with-openssl=$OPENSSL_HOME --prefix=$OPENSSL_HOME
function _IGNORE_() {
for lib in lib lib64; do
  if [[ -d $OPENSSL_HOME/$lib/pkgconfig ]]; then 
    pkgssl=$OPENSSL_HOME/$lib/pkgconfig; 
    Say "PKG_CONFIG_PATH: $pkgssl"
  fi
  if [[ -e $OPENSSL_HOME/$lib/libssl.so ]]; then
    OPENSSL_LIB=$OPENSSL_HOME/$lib
    Say "OPENSSL_LIB: ${OPENSSL_LIB}"
  fi
done
# CPPFLAGS="-I${OPENSSL_HOME}/include" LDFLAGS="-L${OPENSSL_HOME}/lib" ./configure
# env CPPFLAGS="-I${OPENSSL_HOME}/include" LDFLAGS="-L${OPENSSL_LIB}" PKG_CONFIG_PATH=$pkgssl ./configure --with-nghttp2=$OPENSSL_HOME --with-ssl=$OPENSSL_HOME --with-openssl=$OPENSSL_HOME --prefix=$OPENSSL_HOME --disable-werror |& tee /opt/curl-config.log
# env CPPFLAGS="-I${OPENSSL_HOME}/include" LDFLAGS="-L${OPENSSL_HOME}/lib -L${OPENSSL_HOME}/lib64" PKG_CONFIG_PATH="${OPENSSL_HOME}/lib64/pkgconfig:${OPENSSL_HOME}/lib/pkgconfig" ./configure --with-nghttp2=$OPENSSL_HOME --with-ssl=$OPENSSL_HOME --with-openssl=$OPENSSL_HOME --prefix=$OPENSSL_HOME --disable-werror |& tee /opt/curl-config.log
}

./configure --with-ldap-lib=$OPENSSL_HOME --with-brotli=$OPENSSL_HOME --with-zstd=$OPENSSL_HOME --with-nghttp2=$OPENSSL_HOME --with-ssl=$OPENSSL_HOME --with-openssl=$OPENSSL_HOME --prefix=$OPENSSL_HOME --disable-werror |& tee "$CONFIG_LOG/curl.txt"
# time make -j > /dev/null
time make install -j > /dev/null
ldconfig

Say "CHECK VERSIONs"
for exe in curl openssl curl-config; do
  if [[ -e $OPENSSL_HOME/bin/$exe ]]; then
    ln -f -s $OPENSSL_HOME/bin/$exe /usr/local/bin/$exe
    Say "Link /usr/local/bin/$exe"
  fi
done
bash -c 'openssl version
curl --version
Say "Check https://raw.githubusercontent.com using TLS 1.2"
curl -I -L --tlsv1.2 https://raw.githubusercontent.com
Say "Check https://raw.githubusercontent.com using TLS 1.3"
curl -I -L --tlsv1.3 https://raw.githubusercontent.com
'

$OPENSSL_HOME/bin/curl --version |& tee "$CONFIG_LOG/curl.version.txt"

# strip
Say "Stripping"
cd $OPENSSL_HOME
deps=$(mktemp)
for f in bin/* lib/*.so* lib/*.so*; do
  echo "checking $f ..."
  strip $f || true
  ldd $f | grep '/usr/local' | awk '{print $NF}' >> "$deps" || true
done
mkdir -p deps
for f in $(cat "$deps" | sort -u); do
  if [[ -e "$f" ]]; then
    cp -f "$f" deps/
  fi
done
for dir in deps lib lib64; do
  echo "Check is $dir/ empty"
  content="$(ls -1 $dir)"
  if [[ -z "$content" ]]; then
    Say "$dir/ is empty"
    rm -rf $dir
  fi
done 

cd "$OPENSSL_HOME"
rm -rf share/man/man3
Say "pack [$(pwd)] release as gz"
artifact="$SYSTEM_ARTIFACTSDIRECTORY/curl-7.81.0-$machine"
tar cf - . | gzip -9 > ${artifact}.tar.gz
Say "pack [$(pwd)] release as xz"
tar cf - . | xz -z -9 -e > ${artifact}.tar.xz
build_all_known_hash_sums ${artifact}.tar.xz
build_all_known_hash_sums ${artifact}.tar.gz

Say "Done"
kill $pid || true
