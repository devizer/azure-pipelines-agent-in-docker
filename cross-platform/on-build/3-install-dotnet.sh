#!/usr/bin/env bash
Say "Installing dotnet"; 
curl -ksSL -o /tmp/install-DOTNET.sh https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; 
export DOTNET_TARGET_DIR=/usr/share/dotnet; 
set +e
Say "DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER is '${DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER}'"
export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0
# what the hell on qemu-static?
bash /tmp/install-DOTNET.sh;
set -e 
ln -f -s ${DOTNET_TARGET_DIR}/dotnet /usr/local/bin/dotnet;  
dotnet --info; 
