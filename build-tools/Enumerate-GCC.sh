set -e; set -u; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash > /dev/null
smart-apt-install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null

# docker buildx imagetools inspect --raw "$image" | jq
# error: Required C99 support is in a test phase.  Please see git-compat-util.h for more details.
# 2.35.0 needs uncompless, e.g. works on Debian:11 only

SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds/Enumerate-GCC}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"
 function Jump-Into-Container() {
  CONTAINER="${IMAGE//[\/:]/-}-${GCC_INSTALL_VER//[.]/-}"
  Say "Start contianer [$CONTAINER]"

  export TARGET_DIR="$HOME/.local/tmp/"; mkdir -p "$TARGET_DIR"; script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash >/dev/null


  if [[ ! -e /usr/bin/qemu-aarch64-static ]]; then
    Say "Installing qemu-user-static"
    apt-get install qemu-user-static -y -qq
  fi
  local marker="${TMPDIR:-/tmp}/"
  if [[ "$(uname -m)" == x86_64 ]] && [[ ! -e "$marker" ]]; then
    Say "Registering binary formats for qemu-user-static"
    docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
    touch "$marker"
  fi
  local f=build-gcc-utilities.sh; curl -ksSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
  [[ "${1:-}" == "--reset" ]] && docker rm -f "$CONTAINER" || true
  docker run -d --sysctl net.ipv6.conf.all.disable_ipv6=1 --privileged --hostname "$CONTAINER" --name "$CONTAINER" -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static "$IMAGE" sh -c 'tail -f /dev/null'
  for cmd in "$TARGET_DIR"/* /tmp/build-gcc-utilities.sh; do
    file_name_only=$(basename $cmd)
    docker cp $cmd "$CONTAINER":/usr/bin/$file_name_only
  done

  cat <<-'EOF' > /tmp/provisioning-$CONTAINER
    set -e
    cd /root
    Say --Reset-Stopwatch
    export DEBIAN_FRONTEND=noninteractive
    source /usr/bin/build-gcc-utilities.sh
    prepare_os
    script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/bin bash

    test -f /etc/os-release && source /etc/os-release
    OS_VER="${ID:-}:${VERSION_ID:-}"

    if [[ -n "${GCC_INSTALL_VER:-}" ]]; then
      Say "Installing GCC ${GCC_INSTALL_VER:-}"
      export GCC_INSTALL_VER
      export GCC_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/install-gcc.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
    fi

    source /tmp/provisioning-$CONTAINER
    Say "COMPLETE"
EOF

  docker cp /tmp/provisioning-$CONTAINER "$CONTAINER":/tmp/provisioning-$CONTAINER
  docker exec -it -e GCC_INSTALL_VER="$GCC_INSTALL_VER" -e IMAGE="$IMAGE" -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" -e CONTAINER="$CONTAINER" $CONTAINER \
         bash -c "source /tmp/provisioning-$CONTAINER"

  mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY/$CONTAINER"
  docker cp "$CONTAINER":"$SYSTEM_ARTIFACTSDIRECTORY/." "$SYSTEM_ARTIFACTSDIRECTORY/$CONTAINER"

}

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done

for ver in 8.5.0 10.3.0 11.2.0; do
  IMAGE="multiarch/debian:arm64-jessie" GCC_INSTALL_VER="$ver" Jump-Into-Container --reset
done

for ver in 8.5.0 9.4.0 10.3.0 11.2.0; do
  IMAGE="multiarch/debian:armhf-jessie" GCC_INSTALL_VER="$ver" Jump-Into-Container --reset
done
