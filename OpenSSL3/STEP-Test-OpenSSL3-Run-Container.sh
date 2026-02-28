set -eu; set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"


Build-Test-Image() {
  Say "BUILDING 'openssl-test-image' image from $IMAGE"
  sudo swapon 2>/dev/null || true

  if [[ "$(uname -m)" == x86_64 ]]; then
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  fi

  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

  ssl_versions="1.1.1w 3.5.5 3.0.19 3.3.6 3.4.4 3.6.1"
  runtimes="arm arm64 x64 musl-arm musl-arm64 musl-x64"
  index=0;
  for ssl_version in $ssl_versions; do
  for rid in $runtimes; do
    index=$((index+1))
    echo "[$index of 36] Downloading openssl $ssl_version binaries for [linux-$rid]"
    Run-Remote-Script https://devizer.github.io/devops-library/install-libssl.sh \
        $ssl_version \
        --target-folder "./openssl-binaries/linux-$rid/openssl-$ssl_version" \
        --rid "linux-$rid"
  done
  done
  tree -h ./openssl-binaries


  if [[ $IMAGE == *"arm32v7"* ]]; then export DOCKER_DEFAULT_PLATFORM=linux/arm/v7; fi
  if [[ $IMAGE == *"arm64v8"* ]]; then export DOCKER_DEFAULT_PLATFORM=linux/arm64; fi
  if [[ -n "${IMAGE_PLATFORM:-}" ]]; then export DOCKER_DEFAULT_PLATFORM="${IMAGE_PLATFORM:-}"; fi
  cp -v /usr/bin/qemu-arm-static ./
  cp -v /usr/bin/qemu-aarch64-static ./
  Say "PULL BASE IMAGE [$IMAGE]"
  echo "DOCKER_DEFAULT_PLATFORM = [${DOCKER_DEFAULT_PLATFORM:-}]"
  try-and-retry docker pull -q $IMAGE
  docker build --build-arg BASE_IMAGE=$IMAGE -f OpenSSL3/Dockerfile.TEST-OpenSSL3 -t openssl-test-image .
}

time Build-Test-Image

docker run --privileged --rm --hostname openssl-container \
  -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
  -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
  openssl-test-image \
  bash -c '
           Say "Get-NET-RID = [$(Get-NET-RID)]";
           Say "Get-Linux-OS-ID = [$(Get-Linux-OS-ID)]";
           Say "Get-Linux-OS-Architecture = [$(Get-Linux-OS-Architecture)]";
           Say "Get-Glibc-Version = [$(Get-Glibc-Version)]";
           Say "FOLDER: $(pwd -P)";
'

if [[ "${ARG_SET:-}" == "X64_ONLY" ]] && [[ "${IMAGE:-}" == *":arm"* || $IMAGE_PLATFORM == *"arm"* ]]; then
  echo "SKIPPING ARM on X64_ONLY Workflow"
  exit 0
fi

set -x
docker run --privileged --rm --name openssl-container --hostname openssl-container \
  -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
  -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
  -v "$SYSTEM_ARTIFACTSDIRECTORY:$SYSTEM_ARTIFACTSDIRECTORY" \
  -e IMAGE="$IMAGE" \
  -e IMAGE_PLATFORM=$IMAGE_PLATFORM \
  -e ARTIFACT_NAME="$ARTIFACT_NAME" \
  -e ARG_SET="$ARG_SET" \
  -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
  openssl-test-image \
  bash -e -u -c "bash -e -u -o pipefail OpenSSL3/STEP-Test-OpenSSL3-Test-in-Container.sh;"

exit 0