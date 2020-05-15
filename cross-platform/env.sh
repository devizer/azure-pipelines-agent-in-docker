#!/usr/bin/env bash
# for agent 1.166+ it is not needed
if false && [[ "$(uname -m)" == aarch64 ]]; then
  # Add arm-linux-gnueabihf libs to LD_LIBRARY_PATH
  # (This tells ld where it can find libs in addition to the default /lib dir,
  # Point it to the default path for armhf libs
  export LD_LIBRARY_PATH="/usr/arm-linux-gnueabihf/lib/"
fi

if [[ -s /etc/NVM_DIR ]]; then
  NVM_DIR=$(cat /etc/NVM_DIR)
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    export NVM_DIR
    source "$NVM_DIR/nvm.sh"
  fi
fi

if [[ -d /home/user/.dotnet/tools ]]; then
  export PATH="$PATH:/home/user/.dotnet/tools"
fi

echo "Path is [$PATH]"
