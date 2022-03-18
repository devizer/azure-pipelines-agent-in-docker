set -eu; set -o pipefail
cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
machine=$(uname -m); 
[[ $machine == x86_64 ]] && [[ "$(getconf LONG_BIT)" == "32" ]] && machine=i386
[[ $machine == aarch64 ]] && machine=arm64v8
[[ $machine == armv* ]] && machine=arm32v7
[[ "$(dpkg --print-architecture)" == armel ]] && machine=arm32v5

url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash

Say "Building mono. Suffix: [-${machine}]"
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
mkdir -p /usr/local/lib /usr/local/lib64
Add-LD-Path /usr/local/lib /usr/local/lib64
Say "GCC: [$(gcc --version | head -1)]"

Say "Install cmake and gnu build tools"
script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | INSTALL_DIR=/usr/local TOOLS="gnu-tools cmake git" bash


export DEBIAN_FRONTEND=noninteractive
export TRANSIENT_BUILDS=/transient-builds
export MONO_VER="${MONO_VER:-6.12.0.122}"
# export MONO_HOME=/opt/mono-${MONO_VER}
export MONO_HOME=/usr/local

apt-get -y install lsof binutils git \
   build-essential autoconf pkg-config \
   zlib1g zlib1g-dev pv libncurses5-dev libncurses5 libncursesw5-dev libncursesw5 gettext \
   pv libncurses5 procps binutils tmux python3

export PKG_CONFIG_PATH=/opt/networking/lib/pkgconfig:/usr/lib/pkgconfig

##### MONO
work=/transient-builds/mono-src
url=https://download.mono-project.com/sources/mono/mono-${MONO_VER}.tar.xz
file=$(basename $url)
mkdir -p $work 
cd $work
rm -f _$file || true
curl -kSL -o _$file "$url"
time (pv _$file | tar xJf -)
rm -f _$file
cd mono*
export CFLAGS="-O2"
export CXXFLAGS="$CFLAGS"
sed -i 's/git:\/\//https:\/\//g' mono/utils/jemalloc/SUBMODULES.json
cat mono/utils/jemalloc/SUBMODULES.json

bash -c "while true; do sleep 5; printf '\u2026\n'; done" &
pid=$!

# --disable-boehm --with-gc=none --with-sgen=yes
# doesn't work: --with-libgc=included
time ./autogen.sh --prefix="$MONO_HOME" --with-jemalloc=no --disable-werror --enable-dtrace=no \
  --with-profile2=no --disable-maintainer-mode --disable-dependency-tracking \
  --enable-boehm --with-sgen=yes \
  --disable-llvm --disable-dtrace \
  --with-mcs-docs=no --with-compiler-server=no \
  --with-static_mono=yes --with-shared_mono=no \
  --disable-gtk-doc --with-mcs-docs=no --enable-nls=no  \
  --with-ikvm-native=no --enable-minimal=profiler,attach,com \
  |& tee autogen.log

time (make -j$(nproc) && make install)
echo "make install complete"
$MONO_HOME/bin/mono --version


cd "$MONO_HOME"
Say "pack [$(pwd)] release as gz"
artifact="$SYSTEM_ARTIFACTSDIRECTORY/mono-${MONO_VER}-$machine"
tar cf - . | gzip -9 > ${artifact}.tar.gz
Say "pack [$(pwd)] release as xz"
tar cf - . | xz -z -9 -e > ${artifact}.tar.xz
build_all_known_hash_sums ${artifact}.tar.xz
build_all_known_hash_sums ${artifact}.tar.gz

Say "Done"
kill $pid || true
