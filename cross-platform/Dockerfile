FROM ubuntu:xenial

ARG VSTS_URL="https://devizer.visualstudio.com/"
ARG VSTS_PAT=undefined
ARG VSTS_POOL=undefined
ARG VSTS_AGENT=undefined 
ARG VSTS_WORK=undefined

ENV DEBIAN_FRONTEND=noninteractive \
 DOTNET_ROOT=/usr/share/dotnet \
 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
 DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1 \
 container=docker \
 LC_ALL=en_US.UTF8 \
 LANG=en_US.UTF8 

WORKDIR /pre-configure
COPY .  /pre-configure
SHELL ["/bin/bash", "-c"]
  
RUN echo; \
 set -e; set -u; \
 echo "Starting in '$(pwd)'"; \
 find . -name "*.sh" | xargs chmod +x; \
 apt-get update -q; \
 apt-get install -yq locales systemd apt-utils apt-transport-https ca-certificates curl libcurl3 gnupg2 software-properties-common htop mc lsof unzip net-tools bsdutils sudo p7zip-full wget git time ncdu procps p7zip-full jq pv; apt-get clean; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 bash install-locales.sh; \
 Say "Configure SystemD in docker"; \
     pushd /lib/systemd/system/sysinit.target.wants/ \
     && ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 \
     && rm -f /lib/systemd/system/multi-user.target.wants/* \
     /etc/systemd/system/*.wants/* \
     /lib/systemd/system/local-fs.target.wants/* \
     /lib/systemd/system/sockets.target.wants/*udev* \
     /lib/systemd/system/sockets.target.wants/*initctl* \
     /lib/systemd/system/basic.target.wants/* \
     /lib/systemd/system/anaconda.target.wants/* \
     /lib/systemd/system/plymouth* \
     /lib/systemd/system/systemd-update-utmp*; popd; \
 Say "Confugure user 'user'"; \
    useradd -m -s /bin/bash user; \
    usermod -aG sudo user; \ 
    echo "user    ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo; \
    printf "pass\npass\n" | passwd user; \
    passwd -u user; \
 Say "Provisioning container"; \
    pushd /pre-configure/on-build >/dev/null; \
    for f in $(ls -1 *.sh | sort); do Say "TRY '$f' from on-build"; bash -e "$f"; done; \
    popd >/dev/null; \
    if [[ "$(uname -m)" == aarch64 ]]; then bash -e /pre-configure/arm32-on-arm64.sh; fi; \ 
 Say "Cleanup"; \
 dotnet nuget locals all --clear; \ 
 sudo rm -rf /var/lib/apt/lists/*; \
 sudo rm -rf /var/cache/apt/*; \
 sudo rm -rf /var/tmp/*; \
 sudo rm -rf /tmp/*; \
 Say "FINISH. PATH is [$PATH]"; 

VOLUME [ "/sys/fs/cgroup" ]
VOLUME ["/var/run/docker.sock"]

# systemd should have pid=1 
CMD ["/lib/systemd/systemd"]
