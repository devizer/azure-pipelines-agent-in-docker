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

if [[ -d /etc/agent-path.d ]]; then
    for file in $(ls -1 /etc/agent-path.d/*); do 
        while read path; do
            if [[ -d "${path}" ]]; then
                Say "Adding '$path' to the PATH from $(basename file)"
                export PATH="$path:$PATH"
             else
                Say "Skipping '$path' for PATH from $(basename file). Directory does not exists"
            fi
        done <"${file}"
    done
fi

if [[ -d /home/user/.dotnet/tools ]]; then
  export PATH="$PATH:/home/user/.dotnet/tools"
fi

if [[ -d /opt/portable-ruby/bin ]]; then
  export PATH="/opt/portable-ruby/bin:$PATH"
fi

file=/usr/local/share/ssl/cacert.pem
test -s $file && export CURL_CA_BUNDLE="$file"

echo "Path is [$PATH]"
