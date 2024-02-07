#!/usr/bin/env bash
libcver="$(ldd --version | awk 'NR==1{print 1000 * $NF}')"
Say "Installing dotnet. libc ver is '$libcver'"; 
# TODO NET 8 requires 2.23
export DOTNET_TARGET_DIR=/usr/share/dotnet 
export DOTNET_VERSIONS="2.1 2.2 3.0 3.1 5.0 6.0 7.0"
if [ "$libcver" -ge 2230 ]; then export DOTNET_VERSIONS="$DOTNET_VERSIONS 8.0"; fi
if [[ "$SLIM_IMAGE" == "true" ]]; then 
  export DOTNET_VERSIONS="7.0"; 
  if [ "$libcver" -ge 2230 ]; then export DOTNET_VERSIONS="8.0"; fi
fi
curl -ksSL -o /tmp/install-DOTNET.sh https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; 
set +e
Say "DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER is '${DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER}'"
export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0
# what the hell on qemu-static?
bash /tmp/install-DOTNET.sh;
set -e 
ln="ln -f -s ${DOTNET_TARGET_DIR}/dotnet /usr/local/bin/dotnet"
eval "sudo $ln" || sudo "$ln" 
echo ${DOTNET_TARGET_DIR} > /etc/agent-path.d/dotnet

# next line fails on 20.04 only for armv7 and arm64 only in qemu  
dotnet --info || true; 

rm -rf /root/.dotnet/tools/* || true

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
