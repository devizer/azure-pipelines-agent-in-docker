set -eu; set -o pipefail
sudo="$(command -v sudo || true)"
Say "apt-get update"
time $sudo apt-get update -qq 
Say "apt-get install build-essential perl"
time $sudo apt-get install build-essential perl -y -qq
work=$HOME/build/openssl-3.0; mkdir -p "$work"; cd "$work" && rm -rf *
# https://openssl-library.org/source/
ver=3.0.19
ver=3.5.5
ver=3.3.6
ver=3.4.4
ver=3.6.1
suffix="${ver%.*}"
url="https://github.com/openssl/openssl/releases/download/openssl-$ver/openssl-$ver.tar.gz"
file="_$(basename "$url")"
Download-File "$url" "$file"
tar xzf "$file"
cd openssl*
prefix=/usr/local/openssl-$suffix
# ./Configure shared --prefix=/usr/local/openssl-$suffix
./Configure linux-x86_64 \
    shared \
    --prefix=/usr/local/openssl-$suffix \
    -march=x86-64 \
    -mtune=generic \
    -mno-sse3 -mno-ssse3 -mno-sse4 -mno-sse4.1 -mno-sse4.2 \
    -mno-avx -mno-avx2

time make -j
# time make test
time $sudo make install
LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64 $prefix/bin/openssl version
