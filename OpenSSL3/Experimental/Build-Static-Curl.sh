# work=$HOME/build/curl; mkdir -p $work; cd $work; git clone https://github.com:/devizer/azure-pipelines-agent-in-docker; cd azure-pipelines-agent-in-docker; git pull; time bash OpenSSL3/Experimental/Build-Static-Curl.sh
set -eu; set -o pipefail

  if [[ "$(uname -m)" == x86_64 && -z "$(command -v qemu-arm-static)" ]]; then
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
  fi
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/../Functions.sh"

artifacts="$SCRIPT_DIR/Artifacts"
rm -rf $artifacts/*

Invoke-Build-Curl() {
  local image="$1"
  local platform="$2"
  pushd $SCRIPT_DIR

  ARTIFACTS_SUFFIX=$(Get-Safe-File-Name "$platform")
  mkdir -p $artifacts
  export DOCKER_DEFAULT_PLATFORM=$platform
  docker run -t --rm \
    -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
    -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
    -e SYSTEM_ARTIFACTSDIRECTORY=/Artifacts \
    -e ARTIFACTS_SUFFIX=$ARTIFACTS_SUFFIX \
    -e PLATFORM=$platform \
    -v $artifacts:/Artifacts \
    -w /job -v $(pwd -P):/job \
    alpine:3.23 sh -c "apk add bash; bash Build-Static-Curl-In-Container.sh"
  popd
}

Invoke-Build-Curl alpine:3.23 linux/i386
Invoke-Build-Curl alpine:3.23 linux/amd64
Invoke-Build-Curl alpine:3.23 linux/arm/v6
Invoke-Build-Curl alpine:3.23 linux/arm/v7
Invoke-Build-Curl alpine:3.23 linux/arm64

