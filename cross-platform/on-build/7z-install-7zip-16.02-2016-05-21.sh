#!/usr/bin/env bash

function install_7z() {
  work=~/build/7zip-16.02
  mkdir -p $work
  pushd $work
  url=https://downloads.sourceforge.net/p7zip/p7zip_16.02_src_all.tar.bz2
  url=https://netcologne.dl.sourceforge.net/project/p7zip/p7zip/16.02/p7zip_16.02_src_all.tar.bz2
  file=$(basename $url)
  wget -O _$file --no-check-certificate $url
  tar xjf _$file 
  cd p7zip*
  sed -i 's/OPTFLAGS=-O /OPTFLAGS=-O3 /g' makefile.machine
  cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
  time make test_7z -j${cpus} && sudo make install
  /usr/local/bin/7z || echo "7Z not found"
  popd

  rm -rf $work
}

s7zip=$(7z | grep "zip Version" | awk '{print $3}')
if [[ "$s7zip" != "16.02" ]]; then
    install_7z
fi
