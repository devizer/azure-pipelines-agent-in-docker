set -eu; set -o pipefail
sudo="$(command -v sudo || true)"
Say "apt-get update"
time $sudo apt-get update -qq 
Say "apt-get install build-essential perl"
time $sudo apt-get install build-essential perl wget -y -qq | { grep "Setting\|Prepar" || true; }

if [[ "$(hostname)" == *"container"* ]]; then
  url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
  Say "Final UNAME MACHINE: $(uname -m)"
else
  Say " Install-Fake-UName.sh skipped. HOSTNAME '$(hostname)' does not contain 'container'."
fi

work=$HOME/build/openssl-3.0; mkdir -p "$work"; cd "$work" && rm -rf *
# https://openssl-library.org/source/
ver=3.0.19
ver=3.5.5
ver=3.3.6
ver=3.4.4
ver=3.6.1
ver="${SSL_VERSION:-$ver}"
suffix="${ver%.*}"
url="https://github.com/openssl/openssl/releases/download/openssl-$ver/openssl-$ver.tar.gz"
file="_$(basename "$url")"
Download-File "$url" "$file"
tar xzf "$file"
cd openssl*
prefix=/usr/local/openssl-$suffix
Say "OpenSSL3 $ver Prefix: [$prefix]"
# ./Configure shared --prefix=/usr/local/openssl-$suffix
if [[ "$(uname -m)" == "x86_64" ]]; then
    Say "Tune for SSE2 only with assembler on x64"
    ./Configure linux-x86_64 \
        shared \
        --prefix=/usr/local/openssl-$suffix \
        -march=x86-64 \
        -mtune=generic \
        -mno-sse3 -mno-ssse3 -mno-sse4 -mno-sse4.1 -mno-sse4.2 \
        -mno-avx -mno-avx2
else
    Say "Default shared Configuration"
   ./Configure shared --prefix=/usr/local/openssl-$suffix
fi

time make -j
# time make test
time $sudo make install
LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64 $prefix/bin/openssl version

Say "PACK"
cd $prefix
cd ..
time tar czf $SYSTEM_ARTIFACTSDIRECTORY/OpenSSL-$ver-for-$(uname -m).tar.gz "$(basename $prefix)"
