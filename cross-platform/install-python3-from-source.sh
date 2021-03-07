#!/usr/bin/env bash
# apt-get update
apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev wget curl sudo locales
url=https://www.python.org/ftp/python/3.7.10/Python-3.7.10.tgz
work=$HOME/build/python3-src
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
mkdir -p $work
pushd $work
file=$(basename $url)
(wget -q -nv --no-check-certificate -O _$file $url 2>/dev/null || curl -ksSL -o _$file $url)
tar xzf _$file
cd Python*
export LC_ALL=en_US.UTF8 LANG=en_US.UTF8
cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
if false; then
  # local
  time ./configure --enable-optimizations
  time make -j $cpus
  time make -j $cpus install
else
  # portable
  time ./configure
  time make -j $cpus build_all
  time make -j $cpus install
fi
popd
