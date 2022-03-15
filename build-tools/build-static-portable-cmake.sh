# https://cmake.org/cmake/help/v3.7/module/FindOpenSSL.html
# https://github.com/Kitware/CMake/blob/master/Modules/FindOpenSSL.cmake
# docker run -it --rm alpine:edge sh -c "apk add bash nano mc; export PS1='\w # '; bash"
set -eu
set -o pipefail
CMAKE_VER="${CMAKE_VER:-3.22.3}"
PLATFORM="${PLATFORM:-temp}"
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

Say "BUILT-IN DEB Dependencies"
Say Before
cat /etc/apt/sources.list
sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
Say "After #1"
cat /etc/apt/sources.list
Say "After #2"
source /etc/os-release
echo '
deb http://deb.debian.org/debian '$VERSION_CODENAME' main main contrib non-free
deb http://security.debian.org/debian-security '$VERSION_CODENAME'-security main contrib non-free
deb http://deb.debian.org/debian '$VERSION_CODENAME'-updates main contrib non-free
deb-src http://deb.debian.org/debian '$VERSION_CODENAME' main contrib non-free
deb-src http://security.debian.org/debian-security '$VERSION_CODENAME'-security main contrib non-free
deb-src http://deb.debian.org/debian '$VERSION_CODENAME'-updates main contrib non-free
' > /etc/apt/sources.list
if [[ "${ID}:${VERSION_ID}" == "debian:10" ]]; then
echo '
deb http://deb.debian.org/debian buster main contrib non-free
deb http://security.debian.org/debian-security buster/updates main contrib non-free
deb http://deb.debian.org/debian buster-updates main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free
deb-src http://security.debian.org/debian-security buster/updates main contrib non-free
deb-src http://deb.debian.org/debian buster-updates main contrib non-free
' > /etc/apt/sources.list
fi
cat /etc/apt/sources.list

apt-get update -qq
Say "APT Build dependencies"
apt-get build-dep mc ncdu bash nano cmake openssl libarchive -y -q | { grep "Unpacking\|Setting" || true; }

Say "APT Install rest build tools"
apt-get-install curl;
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/bin bash >/dev/null; Say --Reset-Stopwatch
time apt-get-install build-essential git cmake make autoconf automake libtool pkg-config clang \
  sudo xz-utils mc nano sudo xz-utils less \
  zlib1g libncurses5 \
  libncursesw5-dev libncurses5-dev \
  libssl-dev zlib1g-dev libexpat1-dev \
  libbz2-dev lzma-dev \
  libexpat1-dev libarchive-dev libnghttp2-dev libssl-dev libssh-dev libcrypto++-dev

time apt-get-install \
       ca-certificates curl aria2 gnupg software-properties-common htop mc lsof unzip \
       net-tools bsdutils lsb-release wget curl pv sudo less nano ncdu tree \
       procps dialog \
       build-essential libc6-dev libtool gettext autoconf automake bison flex help2man m4 \
       pkg-config g++ gawk \
       curl aria2 htop mc lsof gawk gnupg openssh-client openssl \
       bsdutils lsb-release xz-utils pv sudo less nano ncdu tree \
       procps dialog \
       gettext zlib1g-dev \
       libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip


time (export INSTALL_DIR=/usr/local TOOLS="bash git jq 7z nano gnu-tools cmake curl"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | CMAKE_VER=3.22.2 bash)
fi

if [[ -e /etc/debian_version ]]; then url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash; fi


function _IGNORE_libarchive_() {
Say "Building libarchive"
url=https://github.com/libarchive/libarchive/releases/download/v3.6.0/libarchive-3.6.0.tar.xz
work=$HOME/build/libarchive-src
mkdir -p $work
cd $work
curl -kSL -o _source.tar.xz "$url"
tar xJf _source.tar.xz
cd lib*
time (./configure --prefix="/usr/local" |& tee "$HOME/libarchive.txt" && make -j$(nproc) && make install -j$(nproc) )
}


Say "BUILDING CMAKE"
url=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz
work=$HOME/build/cmake; mkdir -p "$work"; cd $work
try-and-retry curl -f -kSL -o /tmp/_cmake.tar.gz "$url"
tar xzf /tmp/_cmake.tar.gz
cd cmake*
mkdir -p out; cd out

export CC=clang CXX=clang++ CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static"

sslpath=/usr; if [[ -d /opt/networking ]]; then sslpath=/opt/networking; fi
Say "CMaking (ssl root is [$sslpath])"
rm -rf *; time cmake -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX=/opt/cmake \
  -DBUILD_TESTING:BOOL=OFF -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DOPENSSL_ROOT_DIR="$sslpath" \
  .. 2>&1 | tee ~/my-cmake.log

Say "Building"
time make install -j2 VERBOSE=1 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="-static -all-static" |& tee my-make.log 
#  || make install -j2 VERBOSE=1 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="-static -all-static" |& tee my-make-error.log
ldd /opt/cmake/bin/cmake && (Say --Display-As=Error "/opt/cmake/bin/cmake is not static"; exit 13) || true
ls -la /opt/cmake/bin/
/opt/cmake/bin/cmake --version
Say "Stripped copy: /opt/cmake-stripped"
cp -r /opt/cmake /opt/cmake-stripped
strip /opt/cmake-stripped/bin/*
Say "DONE: Static Portable CMake"
