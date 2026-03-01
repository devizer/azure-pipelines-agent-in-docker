# work=$HOME/build/curl; mkdir -p $work; cd $work; git clone https://github.com:/devizer/azure-pipelines-agent-in-docker; cd azure-pipelines-agent-in-docker; git pull; time bash OpenSSL3/Experimental/Build-Static-Curl.sh
set -eu; set -o pipefail

  if [[ "$(uname -m)" == x86_64 ]]; then
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  fi


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

mkdir -p Artifacts
for platofrm in linux/amd64 linux/arm/v7 linux/arm64; do
  export DOCKER_DEFAULT_PLATFORM=linux/arm64
  docker run --rm \
    -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
    -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
    -e SYSTEM_ARTIFACTSDIRECTORY=/Artifacts \
    -v $(pwd)/Artifacts:/Artifacts \
    -w /job -v $(pwd -P):/job \
    alpine:3.23 sh -c "apk add bash; bash Build-Static-Curl-In-Container.sh" 
done 