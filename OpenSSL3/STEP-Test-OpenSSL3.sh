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

  if [[ $IMAGE == *"arm32v7"* ]]; then export DOCKER_DEFAULT_PLATFORM=linux/arm/v7; fi
  if [[ $IMAGE == *"arm64v8"* ]]; then export DOCKER_DEFAULT_PLATFORM=linux/arm64; fi
  Say "PULL BASE IMAGE [$IMAGE]"
  try-and-retry docker pull -q $IMAGE
  docker build --build-arg BASE_IMAGE=$IMAGE -f OpenSSL3/Dockerfile.TEST-OpenSSL3 -t openssl-test-image .
}

time Build-Test-Image

docker run --privileged --rm --name openssl-container --hostname openssl-container openssl-test-image \
  -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
  -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
  -v "$SYSTEM_ARTIFACTSDIRECTORY:$SYSTEM_ARTIFACTSDIRECTORY" \
  -e IMAGE="$IMAGE" \
  -e ARTIFACT_NAME="$ARTIFACT_NAME"
  -e ARG_SET="$ARG_SET" \
  -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
  bash -c 'echo;
           Say "Get-NET-RID = [$(Get-NET-RID)]"
           Say "Get-Linux-OS-ID = [$(Get-Linux-OS-ID)]"
           Say "Get-Linux-OS-Architecture = [$(Get-Linux-OS-Architecture)]"
           Say "Get-Glibc-Version = [$(Get-Glibc-Version)]"
           Say "ARTIFACT_NAME = [$ARTIFACT_NAME]"
           Say "FOLDER: $(pwd -P)"
           ls -la || true;
           if [[ -d ./OpenSSL-Tests ]]; then
              Say "./OpenSSL-Tests FOLDER"; 
              ls -la OpenSSL-Tests;
           fi
'

if [[ "${ARG_SET:-}" == "X64_ONLY" && "${IMAGE:-}" == *":arm"* ]]; then
  echo "SKIPPING ARM on X64_ONLY Workflow"
  exit 0
fi
