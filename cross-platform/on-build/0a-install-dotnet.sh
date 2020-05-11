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

# next line fails on 20.04 only for armv7 and arm64 only  
dotnet --info || true; 

# support for .NET Core tools 
mkdir -p /home/user/.dotnet/tools
chown -R user:user /home/user/.dotnet/tools
source /etc/environment
new_PATH="/home/user/.dotnet/tools:$PATH"
Say "New PATH for /etc/environment: [$new_PATH]"
sed '/PATH/d' /etc/environment
printf "\nPATH=$new_PATH\n" >> /etc/environment

printf "\n\nexport PATH=\"\$PATH:/home/user/.dotnet/tools\"" | tee -a /home/user/.bashrc
chown user:user /home/user/.bashrc