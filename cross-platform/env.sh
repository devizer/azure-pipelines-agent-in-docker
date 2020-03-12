#!/usr/bin/env bash
if [[ "$(uname -m)" == aarch64 ]]; then
  # Add arm-linux-gnueabihf libs to LD_LIBRARY_PATH 
  # (This tells ld where it can find libs in addition to the default /lib dir,
  # Point it to the default path for armhf libs
  export LD_LIBRARY_PATH="/usr/arm-linux-gnueabihf/lib/"
fi

