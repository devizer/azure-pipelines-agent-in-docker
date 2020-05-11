#!/usr/bin/env bash
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash;

ver=3.8.2
source /etc/os-release
if [[ "$VERSION_ID" != "8" || "$ID" != "debian" ]]; then
    Say "Skipping Python $ver";
    exit 0;
fi

cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
Say "Installing Open SSL and Python $ver from source"

sudo apt-get install -y -q build-essential libc6-dev \
 libncurses5-dev libncursesw5-dev libreadline6-dev \
 libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev \
 libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev \
 uuid-dev \
 libffi-dev; 


# https://wiki.openssl.org/index.php/Compilation_and_Installation#ARM
work=$HOME/build/openssl-src
mkdir -p $work
pushd $work
rm -rf *
url=https://www.openssl.org/source/openssl-1.1.1g.tar.gz
url=https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
try-and-retry wget --no-check-certificate -O _openssl.tgz $url || curl -ksSL -o _openssl.tgz $url
tar -zxf _openssl.tgz
cd openssl*
# ./config --prefix=/usr/local
./config --prefix=/usr/local/ssl
time make -j${cpus}
time sudo make install
popd; rm -rf $work


ver=3.8.2
echo Installing Python $ver
work=$HOME/build/python3-src
mkdir -p $work
pushd $work
rm -rf *
url=https://www.python.org/ftp/python/$ver/Python-$ver.tgz
try-and-retry wget --no-check-certificate -O _python.tgz $url || curl -ksSL -o _python.tgz $url
tar -zxf _python.tgz
cd Python*

echo '
SSL=/usr/local/ssl
_ssl _ssl.c \
       -DUSE_SSL -I$(SSL)/include -I$(SSL)/include/openssl \
       -L$(SSL)/lib -lssl -lcrypto
' >> Modules/Setup


time ./configure          2>&1 | tee ~/configure-python-$ver.log    # 26 sec --enable-optimizations? no
time make -j${cpus}       2>&1 | tee ~/make-python-$ver.log         # 1m 16 sec
time sudo make install    2>&1 | tee ~/install-python-$ver.log      # ~ 4 min
popd; rm -rf $work

# upgrade:
sudo pip3 install -U pip
sudo pip3 install -U setuptools

