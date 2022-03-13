# https://cmake.org/cmake/help/v3.7/module/FindOpenSSL.html
# https://github.com/Kitware/CMake/blob/master/Modules/FindOpenSSL.cmake
# docker run -it --rm alpine:edge sh -c "apk add bash nano mc; export PS1='\w # '; bash"
set -eu
set -o pipefail
export PLATFORM=armv5 CMAKE_VER=3.22.2
Say "PLATFORM: $PLATFORM, CMAKE_VER: $CMAKE_VER"
if [[ "$(command -v apk)" != "" ]]; then
apk upgrade
time apk add build-base perl pkgconfig make clang clang-static cmake ncurses-dev ncurses-static linux-headers mc nano \
  openssl-dev openssl-libs-static \
  nghttp2-dev nghttp2-static libssh2-dev libssh2-static \
  zlib-dev zlib-static bzip2-dev bzip2-static curl expat-dev expat-static \
  libarchive-dev libarchive-static
fi

function apt-get-install() { apt-get install -y -qq "$@" | { grep "Unpacking\|Setting" || true; }  }
if [[ "$(command -v apt-get)" != "" ]]; then
apt-get update -qq; apt-get-install curl;
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/bin bash >/dev/null; Say --Reset-Stopwatch
time apt-get-install build-essential git cmake make autoconf automake libtool pkg-config clang \
  sudo xz-utils mc nano sudo xz-utils less \
  libssl-dev zlib1g-dev libexpat1-dev \
  libexpat1-dev libarchive-dev libnghttp2-dev libssl-dev libssh-dev libcrypto++-dev
fi

if [[ -e /etc/debian_version ]]; then url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash; fi

url=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz
work=$HOME/build/cmake; mkdir -p "$work"; cd $work
try-and-retry curl -f -kSL -o /tmp/_cmake.tar.gz "$url"
tar xzf /tmp/_cmake.tar.gz
cd cmake*
mkdir -p out; cd out

export CC=clang CXX=clang++ CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static"

Say "CMaking"
rm -rf *; time cmake -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX=/opt/cmake \
  -DBUILD_TESTING:BOOL=OFF -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DOPENSSL_ROOT_DIR=/usr \
  .. 2>&1 | tee ~/my-cmake.log

Say "Building"
time make install -j$(nproc) CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="-static -all-static" |& tee my-make.log \
  || make install VERBOSE=1 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="-static -all-static" |& tee my-make-error.log
ldd /opt/cmake/bin/cmake && (Say --Display-As=Error "/opt/cmake/bin/cmake is not static"; exit 13) || true
ls -la /opt/cmake/bin/
/opt/cmake/bin/cmake --version
Say "Stripped copy: /opt/cmake-stripped"
cp -r /opt/cmake /opt/cmake-stripped
strip /opt/cmake-stripped/bin/*
Say "DONE: Static Portable CMake"
