# https://github.com/nmilosev/termux-fedora/blob/master/termux-fedora.sh
# image="debian:8"
# image="multiarch/debian-debootstrap:arm64-jessie"
# image="arm64v8/debian:8"
# KEY=rootfs-debian-8-arm64
# [[ "$(command -v jq)" == "" ]] && apt-get install jq -y
set -e; set -u; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash > /dev/null

smart-apt-install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null

# docker buildx imagetools inspect --raw "$image" | jq
# error: Required C99 support is in a test phase.  Please see git-compat-util.h for more details.
# 2.35.0 needs uncompless, e.g. works on Debian:11 only

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done

DEBIAN_VER=8
export USEGCC="" # Empty string for system gcc
export GIT_VER=${GIT_VER:-v2.34.1}
# export GIT_VER=${GIT_VER:-v2.35.0} 
export TRANSIENT_BUILDS="${TRANSIENT_BUILDS:-$HOME/build}"
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"
DEPLOY_DIR="$SYSTEM_ARTIFACTSDIRECTORY/to-deploy"
mkdir -p "$DEPLOY_DIR"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"


function Fix-Git-Symlink() {
  local from="$1"
  local to="$2"
  if cmp -s "$from" "$to"; then
    cmd="ln -f -s $to $from"
    echo "OK FOR SYMLINKING: $cmd"
    eval $cmd
  fi
}

function Fix-All-Git-Symlinks() {
  local dir="$1"
  if [[ -s "${dir}/bin/git" ]]; then
    pushd "${dir}/bin" >/dev/null
    for f in git-*; do Fix-Git-Symlink $f git; done
    cd ../libexec/git-core
    for f in git-*; do Fix-Git-Symlink $f ../../bin/git; done
    popd >/dev/null
  fi
}

function Grab-Folder() {
  local from="$1"
  local to="$2"
  # if skipped
  if [[ -f "$from/skipped" ]]; then
    echo "" > "$DEPLOY_DIR/$to is skipped"
    return;
  fi

  Say "Repack [$from] as [$to]"
  local tmp="${TRANSIENT_BUILDS}/grab-$to"
  mkdir -p "$tmp"
  rm -rf "$tmp/*"
  docker cp "$container":"$from/." "$tmp"
  Fix-All-Git-Symlinks "$tmp"
  pushd $tmp
    rm -rf man || true
    source /tmp/build-gcc-utilities.sh
    sudo chown -R root:root .
    Say "Repack $DEPLOY_DIR/$to.tar.gz"
    tar cf - . | gzip -9 > $DEPLOY_DIR/$to.tar.gz
    build_all_known_hash_sums $DEPLOY_DIR/$to.tar.gz
    Say "Repack $DEPLOY_DIR/$to.tar.xz"
    tar cf - . | xz -z -9 -e > $DEPLOY_DIR/$to.tar.xz
    build_all_known_hash_sums $DEPLOY_DIR/$to.tar.xz
  popd
}

function Build-Git() {

  work="${TRANSIENT_BUILDS}/git-artifacts/$KEY"
  mkdir -p "$work"
  rm -rf "$work/*"
  docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
  container="builder-for-$KEY"
  docker rm -f $container || true
  Say "Start container [$IMAGE] for [$KEY]"
  tmp=/tmp/git-$KEY; mkdir -p $tmp; rm -rf $tmp/*
  docker run -d --privileged --hostname "$container" --name "$container" -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static "$IMAGE" sh -c 'tail -f /dev/null'
  for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd "$container":/usr/bin/$cmd
  done
  for cmd in *.sh /tmp/build-gcc-utilities.sh; do
    file_name_only="$(basename "$cmd")"
    Say "copying $container:/root/$file_name_only"
    docker cp "$cmd" "${container}:/root/${file_name_only}"
  done

  docker cp /tmp/build-gcc-utilities.sh "$container":/root/build-gcc-utilities.sh

  cat <<-'EOF' > /tmp/provisioning-$KEY
    set -e
    cd /root
    Say --Reset-Stopwatch
    export DEBIAN_FRONTEND=noninteractive
    source build-gcc-utilities.sh
    prepare_os
    script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/bin bash

    test -f /etc/os-release && source /etc/os-release
    OS_VER="${ID:-}:${VERSION_ID:-}"

    Say "FOR GIT on $KEY"
    apt-get install libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip -y -q

    Say "NANO 6"
    export INSTALL_PREFIX=/opt/local-links/nano
    bash -eu install-nano.sh

    Say "BASH 5.1 on $KEY" # ok on Debian:7
    export INSTALL_PREFIX=/opt/local-links/bash
    bash -eu install-bash-5.1.sh

    if false && [[ "$OS_VER" == "debian:7" ]]; then 
      Say "INSTALL AUTOMAKE"; 
      bash -e install-automake.sh; 
    fi

    if [[ "$OS_VER" == "debian:7" ]]; then
      Say "Skipping jq 1.6 on $KEY"
      mkdir -p /opt/jq
      touch /opt/jq/skipped
    else
      Say "jq 1.6 on $KEY"
      export INSTALL_PREFIX=/opt/local-links/jq
      # script=https://raw.githubusercontent.com/devizer/azure-pipelines-agent-in-docker/master/build-tools/install-jq-1.6.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
      bash -eu install-jq-1.6.sh
    fi

    Say "7-ZIP ver 16.02 2016-05-21 on $KEY"
    export INSTALL_PREFIX=/opt/local-links/7z
    # script=https://raw.githubusercontent.com/devizer/azure-pipelines-agent-in-docker/master/cross-platform/on-build/7z-install-7zip-16.02-2016-05-21.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
    bash -eu install-7zip-16.02-2016-05-21.sh

    if [[ -n "${USEGCC:-}" ]]; then
      Say "Install GCC "${USEGCC:-}" on $KEY"
      export GCC_INSTALL_VER="$USEGCC" GCC_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/install-gcc.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
    fi

    Say "Build GIT on $KEY"
    export INSTALL_PREFIX=/opt/local-links/git
    # TEST 2.35.1 on debian 10
    export CFLAGS="-std=gnu99" CPPFLAGS="-std=gnu99" CXXFLAGS="-std=gnu99"
    bash -eu install-git.sh

    Say "COMPLETE on $KEY"
EOF

  docker cp /tmp/provisioning-$KEY "$container":/tmp/provisioning-$KEY
  docker exec -t -e USEGCC="${USEGCC:-}" -e GIT_VER="$GIT_VER" -e KEY="$KEY" "$container" bash -e -c "source /tmp/provisioning-$KEY"

  Grab-Folder "/opt/local-links/nano"  "nano-6.0-$KEY"
  Grab-Folder "/opt/local-links/bash"  "bash-5.1-$KEY"
  Grab-Folder "/opt/local-links/jq"    "jq-1.6-$KEY"
  Grab-Folder "/opt/local-links/git"   "git-${GIT_VER}-$KEY"
  Grab-Folder "/usr/local"             "7z-16.02-$KEY"
}


# MUST be debian:8 for 2.34.1
# KEY="x86_64"   IMAGE="debian:8"         Build-Git
KEY="x86_64"   IMAGE="debian:8"          Build-Git
KEY="arm64v8"  IMAGE="arm64v8/debian:8"  Build-Git
KEY="arm32v7"  IMAGE="arm32v7/debian:8"  Build-Git
