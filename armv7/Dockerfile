FROM ubuntu:xenial

RUN \ 
 apt-get update -q; \
 apt-get install -yq apt-transport-https ca-certificates curl gnupg2 software-properties-common htop mc lsof unzip net-tools bsdutils sudo p7zip-full; apt-get clean; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 curl -ksSL -o /tmp/install-DOTNET.sh https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; \
 bash /tmp/install-DOTNET.sh;

