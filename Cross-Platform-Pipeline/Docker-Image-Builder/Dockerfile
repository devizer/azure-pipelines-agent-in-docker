ARG BASE_IMAGE 
FROM ${BASE_IMAGE}

ARG BASE_IMAGE 
ARG QEMU_IMAGE_ID

VOLUME [ "/sys/fs/cgroup" ]
# VOLUME [ "/var/run/docker.sock" ]
VOLUME [ "/var/run" ]

ENV DEBIAN_FRONTEND=noninteractive \
 container=docker \
 BASE_DOCKER_IMAGE=${BASE_IMAGE} \
 QEMU_IMAGE_ID=${QEMU_IMAGE_ID} \
 USER=root \
 HOME=/root

WORKDIR /
SHELL ["/bin/bash", "-c"]

COPY Install /Install

  
RUN echo; \
 export SLIM_IMAGE BASE_DOCKER_IMAGE BUILD_URL JOB_URL BUILD_SOURCEVERSION BUILD_SOURCEBRANCHNAME BUILD_BUILDID; \
 set -e; set -u; set -o pipefail; \
 echo "Starting image building in '$(pwd)' for $(uname -m)"; \
 find . -name "*.sh" | xargs chmod +x; \
 apt-get update -qq; apt-get install -qq curl sudo -y | grep Setting; \
 echo insecure >> ~/.curlrc; \
 script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; \
 Say --Reset-Stopwatch; \
 Say "$QEMU_IMAGE_ID Image is building"; \
 \
 if [[ "$QEMU_IMAGE_ID" == i?86* ]] || [[ "$QEMU_IMAGE_ID" == x64* ]]; then qemu_packet=qemu-system-x64; else qemu_packet=qemu-system-arm; fi; \
 \
 try-and-retry apt-get -y -qq --no-install-recommends --no-install-suggests install curl xz-utils p7zip-full unzip sshpass sshfs $qemu | grep "Setting\|Unpack"; \
 bash Install/Download-CloudImage.sh --temp /tmp ${QEMU_IMAGE_ID} /Cloud-Image; \
 rm -f /pre-configure/on-build/*.core || true; \
 rm -f /pre-configure/*.core || true; \
 rm -rf /root/build || true; \
 rm -rf /pre-configure/bin || true; \
 rm -rf /var/lib/apt/lists/*; \
 rm -rf /var/cache/apt/*; \
 rm -rf /var/tmp/*; \
 rm -rf /tmp/*; \
 Say "$QEMU_IMAGE_ID FINISHED on $(uname -m). PATH is [$PATH]"; 

# systemd should have pid=1 
# CMD ["/bin/bash"]
ENTRYPOINT ["/Install/Entry-Point.sh"]
