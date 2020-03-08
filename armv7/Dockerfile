FROM ubuntu:xenial

ARG VSTS_URL="https://devizer.visualstudio.com/"
ARG VSTS_PAT=undefined
ARG VSTS_POOL=undefined
ARG VSTS_AGENT=undefined 
ARG VSTS_WORK=undefined

ENV DEBIAN_FRONTEND=noninteractive \
 DOTNET_ROOT=/opt/dotnet \
 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
 DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1

COPY install-apa.sh /tmp/install-apa.sh
  
RUN echo; \
 apt-get update -q; \
 apt-get install -yq apt-utils apt-transport-https ca-certificates curl libcurl3 gnupg2 software-properties-common htop mc lsof unzip net-tools bsdutils sudo p7zip-full wget git; apt-get clean; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 Say "Confugure user 'user'"; \
    useradd -m -s /bin/bash user; \
    usermod -aG sudo user; \ 
    echo "user    ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo; \
    printf "pass\npass\n" | passwd user; \
    passwd -u user; \
 Say "Installing PowerShell and NodeJS"; \
    script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s pwsh node; \
 Say "Installing dotnet"; \
    curl -ksSL -o /tmp/install-DOTNET.sh https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; \
    bash /tmp/install-DOTNET.sh; \
    ln -f -s /opt/dotnet/dotnet /usr/local/bin/dotnet; dotnet --info; \
 Say "Cleanup"; \
 dotnet nuget locals all --clear; \ 
 su -c "bash /tmp/install-apa.sh" user; \
 sudo rm -rf /var/lib/apt/lists/*; \
 sudo rm -rf /var/cache/apt/*; \
 sudo rm -rf /var/tmp/*; \
 sudo rm -rf /tmp/*; \
 Say "PATH is [$PATH]"; 


CMD su -c "cd ~/pipeline-agent; ./run.sh" user
