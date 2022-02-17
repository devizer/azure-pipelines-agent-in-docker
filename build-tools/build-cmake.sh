set -eu;
machine=$(uname -m); 
[[ $machine == aarch64 ]] && machine=arm64v8
[[ $machine == armv* ]] && machine=arm32v7
cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
GCCVER=${GCCVER:-11}; # [[ $machine == arm32v7 ]] && GCCVER=5
Say "Processors: $cpus, GCC $GCCVER, EXPLICIT_OPENSSL_OPTIONS=${EXPLICIT_OPENSSL_OPTIONS}"

export GCC_INSTALL_VER=$GCCVER GCC_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/install-gcc.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash

EXPLICIT_OPENSSL_OPTIONS="${EXPLICIT_OPENSSL_OPTIONS:-True}"
lib_dir=/usr/local/lib; test -d /usr/local/lib64 && lib_dir="/usr/local/lib64"
# works on x86_64 and arm32v7 + GCC 11.2
options="-DOPENSSL_ROOT_DIR=/usr/local -DCMAKE_USE_OPENSSL:BOOL=ON -DOPENSSL_CRYPTO_LIBRARY:FILEPATH=$lib_dir/libcrypto.so -DOPENSSL_INCLUDE_DIR:PATH=/usr/local/include -DOPENSSL_SSL_LIBRARY:FILEPATH=$lib_dir/libssl.so"
if [[ "${EXPLICIT_OPENSSL_OPTIONS:-True}" != True ]]; then
  # works on arm64?
  options=""
fi
Say "CMAKE BOOTSTRAP OPTIONS: [$options]"


# export INSTALL_DIR=/usr/local TOOLS="bash git jq 7z nano gnu-tools"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash

OPENSSL_HOME=/usr/local

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

  ./config --prefix=$OPENSSL_HOME --openssldir=$OPENSSL_HOME |& tee "$work/log-openssl-config.txt"
  time make -j${cpus} |& tee "$work/log-openssl-make.log"
  # make test
  make install |& tee "$work/log-openssl-install.log"
  popd
  # rm -rf $work
}

# sudo apt-get install libssl-dev libncursesw5-dev libncurses5-dev -y -q
sudo apt-get install libncursesw5-dev libncurses5-dev -y -q; apt-get purge libssl-dev; pushd .; time install_openssl_111; popd

INSTALL_DIR="${INSTALL_DIR:-/opt/local-links/cmake}"

mkdir -p "$INSTALL_DIR"; rm -rf "$INSTALL_DIR"/* || rm -rf "$INSTALL_DIR"/* || rm -rf "$INSTALL_DIR"/*

url=https://github.com/Kitware/CMake/releases/download/v3.22.2/cmake-3.22.2.tar.gz
work=$HOME/build/cmake-src
mkdir -p "$work"
pushd .
cd $work && rm -rf * || true
rm -rf "${INSTALL_DIR}"
curl -kSL -o _cmake.tar.gz "$url"
tar xzf _cmake.tar.gz
cd cmake*
# minimum: gcc 5.5 for armv7, gcc 9.4 for x86_64
export CC=gcc CXX="c++" LD_LIBRARY_PATH="$lib_dir"
cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
./bootstrap --parallel=${cpus} --prefix="${INSTALL_DIR}" -- -DCMAKE_BUILD_TYPE:STRING=Release \
  $options \
  |& tee "$work/log-cmake-bootstrap.log"

# -DOPENSSL_ROOT_DIR=/usr/local -DOPENSSL_CRYPTO_LIBRARY=/usr/local/lib64 -DOPENSSL_INCLUDE_DIR=/usr/local/include
# 22 minutes, lib for 
make -j$(nproc) |& tee "$work/log-cmake-make.log"
# sudo make install -j
time sudo -E bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; make install -j" |& tee "$work/log-cmake-install.log"
popd
# rm -rf "$work" || rm -rf "$work" || rm -rf "$work" || true

function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum "'"$file"'" | awk '{print $1}')
      printf "$sum" > "$file.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}


pushd "$INSTALL_DIR"
cd bin
strip * || true
cd "$INSTALL_DIR"
mkdir -p deps; cd deps
for lib in /usr/local/lib64 /usr/local/lib; do
for file in libgcc_s.so.1 libstdc++.so.6 libcrypto.so.1.1 libssl.so.1.1; do
  test -s "$lib/$file" && cp -f "$lib/$file" .
done
done
strip * || true # deps
cd "$INSTALL_DIR"
Say "pack [$(pwd)] release as gz"
archname="../cmake-3.22.2-$machine"
tar cf - . | gzip -9 > ${archname}.tar.gz
Say "pack [$(pwd)] release as xz"
tar cf - . | xz -z -9 -e > ${archname}.tar.xz
build_all_known_hash_sums ${archname}.tar.xz
build_all_known_hash_sums ${archname}.tar.gz
popd

exit 0;
echo '
cd /opt/local-links/cmake/bin
export LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib; 
printf "" > /tmp/cmake
for exe in ccmake  cmake  cpack  ctest; do ldd -v -r $exe >> /tmp/cmake; done
cat /tmp/cmake | grep "/usr/local" | awk '{print $NF}' | sort -u | while IFS='' read file; do test -e $file && echo $file; done
'

# x86_64
/usr/local/lib64/libgcc_s.so.1
/usr/local/lib64/libstdc++.so.6
# armv7
/usr/local/lib/libgcc_s.so.1
/usr/local/lib/libstdc++.so.6


# example
mkdir -p $HOME/my-cmake-app1
cd $HOME/my-cmake-app1 && rm -rf *
echo '
# cmake_minimum_required(VERSION 2.9)  LANGUAGES C
project(AcceptanceTestProject)
add_executable(say42 say42-source.c)
' > CMakeLists.txt
echo '
#include <stdio.h>
void main() { printf("42"); } 
' > say42-source.c
mkdir -p build
cd build
time (cmake .. && make all || true)
./say42


