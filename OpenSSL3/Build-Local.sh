set -eu; set -o pipefail
sudo="$(command -v sudo || true)"
Say "apt-get update"
time $sudo apt-get update -qq 
Say "apt-get install build-essential perl"
time $sudo apt-get install sudo build-essential perl wget -y -qq | { grep --line-buffered "Setting\|Prepar" || true; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

if [[ "$(hostname)" == *"container"* ]]; then
  url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
  Say "Final UNAME MACHINE: $(uname -m)"
else
  Say " Install-Fake-UName.sh skipped. HOSTNAME '$(hostname)' does not contain 'container'."
fi

work=$HOME/build/openssl-3.0; mkdir -p "$work"; cd "$work" && rm -rf * || true
# https://openssl-library.org/source/
ver=3.0.19
ver=3.5.5
ver=3.3.6
ver=3.4.4
ver=3.6.1
ver="${SSL_VERSION:-$ver}"
suffix="${ver%.*}"
export url="https://github.com/openssl/openssl/releases/download/openssl-$ver/openssl-$ver.tar.gz"
export file="_$(basename "$url")"
echo "Download-File '$url' '$file' is starting ..."
try-and-retry bash -e -c 'Download-File "$url" "$file"; gzip -t "$file"'
tar xzf "$file"
cd openssl*
prefix=/usr/local/openssl-$suffix
config_options="shared no-tests -O3 no-module no-afalgeng"
[[ "$ver" == "3.6"* ]] && config_options="$config_options -std=gnu99"
Say "OpenSSL3 $ver Prefix: [$prefix], Configure Options: [$config_options]"
LOG_NAME="$SYSTEM_ARTIFACTSDIRECTORY/OpenSSL-$ver-$(Get-NET-RID)"
echo "LOG_NAME (a prefix) = [$LOG_NAME]"
if [[ "$(uname -m)" == "x86_64" ]]; then
    Say "Tune for SSE2 only with assembler on x64"
    ./Configure linux-x86_64 $config_options \
        -march=x86-64 \
        -mtune=generic \
        -mno-sse3 -mno-ssse3 -mno-sse4 -mno-sse4.1 -mno-sse4.2 \
        -mno-avx -mno-avx2 \
        --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == i?86 ]]; then
    Say "TUNE i686"
    # -march=pentium3 | -march=i686
    ./Configure linux-elf $config_options \
         -march=pentium3 -m32 -mno-sse2 \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "aarch64" ]]; then
    Say "TUNE ARM64"
    # TODO: -mavx2
    ./Configure linux-aarch64 $config_options \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "armv7"* ]]; then
    Say "TUNE ARMv7l 32 bit"
    # -D__ARM_MAX_ARCH__=4 \
    # for 3.6 tests: -std=c99
    # AFALG engine is a bridge that allows OpenSSL to offload cryptographic operations to the Linux Kernel Crypto API
    ./Configure linux-armv4 $config_options \
         -marm -mfloat-abi=hard \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
else
    Say "Default shared Configuration"
   ./Configure shared $c99 $no_module --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
fi
perl configdata.pm --dump 2>&1 | tee ${LOG_NAME}.config.data.log || true

time (make -j >/dev/null && { Say "MAKE SUCCESS. Running make install" || true; } && $sudo make install >/dev/null) 2>&1 && printf "%s" $prefix > $prefix/prefix.txt && printf $ver > $prefix/version.txt | tee ${LOG_NAME}.make.install.txt
# time make test
export LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64 
$prefix/bin/openssl version 2>&1 | tee ${LOG_NAME}.SHOW.VERSION.txt
Benchmark-OpenSSL "$prefix/bin/openssl"

export GZIP="-9"
Say "PACK FULL"
cd $prefix
cd ..
time tar czf ${LOG_NAME}.full.tar.gz "$(basename $prefix)"
tar cf - "$(basename $prefix)" | xz -9 > ${LOG_NAME}.full.tar.xz

Say "PACK BINARIES-ONLY"
cd $prefix
mkdir -p ~/only-so
find -name '*.so.3' | while IFD= read -r file; do cp -v "$file" ~/only-so/; done
cd ~/only-so
printf $(Get-NET-RID) | tee rid.txt
printf $ver | tee version.txt
tar czf ${LOG_NAME}.binaries-only.tar.gz *
tar cJf ${LOG_NAME}.binaries-only.tar.xz *

Say "PACK BINARIES-ONLY STRIPPED"
strip *.so*
tar czf ${LOG_NAME}.binaries-only.stripped.tar.gz *
tar cJf ${LOG_NAME}.binaries-only.stripped.tar.xz *


