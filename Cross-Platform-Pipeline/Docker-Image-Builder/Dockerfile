ARG BASE_IMAGE 
FROM ${BASE_IMAGE}

ARG BASE_IMAGE 
ARG QEMU_IMAGE_ID

VOLUME [ "/sys/fs/cgroup" ]
# VOLUME [ "/var/run/docker.sock" ]
VOLUME [ "/var/run" ]

ENV DEBIAN_FRONTEND=noninteractive \
 container=docker \
 LC_ALL=en_US.UTF8 \
 LANG=en_US.UTF8 \
 BASE_DOCKER_IMAGE=${BASE_IMAGE}

WORKDIR /
SHELL ["/bin/bash", "-c"]

COPY Install /Install

  
RUN echo; \
 export SLIM_IMAGE BASE_DOCKER_IMAGE BUILD_URL JOB_URL BUILD_SOURCEVERSION BUILD_SOURCEBRANCHNAME BUILD_BUILDID; \
 set -e; set -u; \
 echo "Starting in '$(pwd)' for $(uname -m)"; \
 find . -name "*.sh" | xargs chmod +x; \
 apt-get update -qq; apt-get install curl sudo -qq -y; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 Say --Reset-Stopwatch; \
 smart-apt-install curl xz-utils p7zip-full unzip; \
 bash Install/Download-CloudImage.sh --temp /tmp armrl-debian-11 /Cloud-Image; \
 smart-apt-install sshfs rsync qemy-system-arm locales apt-utils inetutils-ping apt-transport-https ca-certificates gnupg2 software-properties-common \
    lsof unzip time procps p7zip-full jq pv binutils \
    ; \
 echo insecure >> ~/.curlrc; \
 bash install-locales.sh; \
 Say "Installing optional ssl 1.1.1m"; \
    source install-optional-openssl-1.1.sh; install_optional_open_ssl_11; \
 chown -R user /home/user; \
 echo "Core dumps: $(ls *.core)" \
 sudo rm -f /pre-configure/on-build/*.core || true; \
 sudo rm -f /pre-configure/*.core || true; \
 sudo rm -rf /root/build || true; \
 sudo rm -rf /pre-configure/bin || true; \
 sudo rm -rf /var/lib/apt/lists/*; \
 sudo rm -rf /var/cache/apt/*; \
 sudo rm -rf /var/tmp/*; \
 sudo rm -rf /tmp/*; \
 Say "FINISHED for $(uname -m). PATH is [$PATH]"; 

# systemd should have pid=1 
CMD ["/bin/bash"]
