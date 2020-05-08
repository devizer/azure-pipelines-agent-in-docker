ARG BASE_IMAGE
FROM ubuntu:${BASE_IMAGE}

VOLUME [ "/sys/fs/cgroup" ]
# VOLUME [ "/var/run/docker.sock" ]
VOLUME [ "/var/run" ]

ENV DEBIAN_FRONTEND=noninteractive \
 DOTNET_ROOT=/usr/share/dotnet \
 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
 DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1 \
 container=docker \
 LC_ALL=en_US.UTF8 \
 LANG=en_US.UTF8 

WORKDIR /
COPY .  /pre-configure
SHELL ["/bin/bash", "-c"]
  
RUN echo; \
 set -e; set -u; \
 build_date="$(date --utc '+%F %T %Z')"; echo $build_date>/version; \
 cd /pre-configure; \
 echo "Starting in '$(pwd)' for $(uname -m)"; \
 find . -name "*.sh" | xargs chmod +x; \
 apt-get update -q; \
 apt-get install -yq locales systemd apt-utils inetutils-ping apt-transport-https ca-certificates gnupg2 software-properties-common htop mc lsof unzip net-tools bsdutils sudo p7zip-full wget git time ncdu tree nano procps p7zip-full jq pv binutils bsdutils; \
 bash install-libcurl.sh; \
 bash disable-ipv6.sh; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 bash install-locales.sh; \
 bash config-system.sh; \
 Say "Configure SystemD in docker for $(uname -m)"; \
     pushd /lib/systemd/system/sysinit.target.wants/ \
     && ls | grep -v systemd-tmpfiles-setup | xargs rm -f  \
     && rm -f /lib/systemd/system/multi-user.target.wants/* \
     /etc/systemd/system/*.wants/* \
     /lib/systemd/system/local-fs.target.wants/* \
     /lib/systemd/system/sockets.target.wants/*udev* \
     /lib/systemd/system/sockets.target.wants/*initctl* \
     /lib/systemd/system/basic.target.wants/* \
     /lib/systemd/system/anaconda.target.wants/* \
     /lib/systemd/system/plymouth* \
     /lib/systemd/system/systemd-update-utmp*; popd; \
 Say "Confugure user 'user' for $(uname -m)"; \
    useradd -m -s /bin/bash user; \
    usermod -aG sudo user; \ 
    echo "user    ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo; \
    printf "pass\npass\n" | passwd user; \
    passwd -u user; \
 Say "Provisioning container for $(uname -m)"; \
    pushd /pre-configure/on-build >/dev/null; \
    for f in $(ls -1 *.sh | sort); do Say "TRY '$f' from on-build for $(uname -m)"; bash -e "$f"; done; \
    popd >/dev/null; \
    if false && [[ "$(uname -m)" == aarch64 ]]; then bash -e /pre-configure/arm32-on-arm64.sh; fi; \ 
 Say "Clean-up for $(uname -m)"; \
 echo SKIP: dotnet nuget locals all --clear; \
 chown -R user /home/user; \
 sudo rm -f /pre-configure/on-build/*.core || true; \
 sudo rm -rf /pre-configure/bin || true; \
 sudo rm -rf /var/lib/apt/lists/*; \
 sudo rm -rf /var/cache/apt/*; \
 sudo rm -rf /var/tmp/*; \
 sudo rm -rf /tmp/*; \
 Say "FINISHED for $(uname -m). PATH is [$PATH]"; 

# systemd should have pid=1 
CMD ["/lib/systemd/systemd"]
