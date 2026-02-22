# work=$HOME/build/openssl3; mkdir -p $work; cd $work; git clone https://github.com:/devizer/azure-pipelines-agent-in-docker; cd azure-pipelines-agent-in-docker; git pull; bash OpenSSL3/Arm-Build-OpenSSL3.sh
set -eu; set -o pipefail
Arm-Build-OpenSSL3() {
  export SSL_VERSION="$1"
  export IMAGE="$2"
  tag=$(echo "$IMAGE" | awk -F":" '{print $2}')
  export SYSTEM_ARTIFACTSDIRECTORY="/OpenSSL3/OpenSSL3-$SSL_VERSION-$tag"
  mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"
  Say "STORE TO [$SYSTEM_ARTIFACTSDIRECTORY]"
  bash -eu STEP-Run-Container.sh
}

Arm-Build-OpenSSL3 3.0.19 "multiarch/debian-debootstrap:arm64-jessie"
