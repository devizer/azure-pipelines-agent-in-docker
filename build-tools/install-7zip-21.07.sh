#!/usr/bin/env bash

# nano ../../../../C/7zCrc.c: USE_CRC_EMU

function install_7z() {
  TRANSIENT_BUILDS="${TRANSIENT_BUILDS:-$HOME/build}"
  work=$HOME/7z-21.07-src
  mkdir -p $work
  pushd $work
  url=https://www.7-zip.org/a/7z2107-src.tar.xz
  file=$(basename $url)
  curl -fkSL -o _$file $url
  tar xJf _$file
  cd CPP/7zip/Bundles/Alone2
  export PLATFORM=arm; 
  make -j -f ../../cmpl_clang.mak

}

export PLATFORM=arm
install_7z
