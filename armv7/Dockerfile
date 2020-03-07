FROM ubuntu:xenial

ENV \
 DOTNET_ROOT=/opt/dotnet \
 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
 DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1
  
RUN \ 
 apt-get update -q; \
 apt-get install -yq apt-transport-https ca-certificates curl gnupg2 software-properties-common htop mc lsof unzip net-tools bsdutils sudo p7zip-full; apt-get clean; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 curl -ksSL -o /tmp/install-DOTNET.sh https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; \
 bash /tmp/install-DOTNET.sh; \
 ls -f -s /opt/dotnet /usr/local/bin/dotnet; dotnet --info; \
 \
 dotnet nuget locals all --clear; 
 sudo rm -rf /var/lib/apt/lists/*; \
 sudo rm -rf /var/cache/apt/*; \
 sudo rm -rf /var/tmp/*; \
 sudo rm -rf /tmp/*; \

 

