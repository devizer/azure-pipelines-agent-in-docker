set -eu; set -o pipefail
  
  sudo swapon 2>/dev/null || true
  # Download-File https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/build-gcc-utilities.sh build-utilities.sh
  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

      
  if [[ "$(uname -m)" == x86_64 ]]; then
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  fi
      

      Say "Starting image $IMAGE"
      echo "SYSTEM_ARTIFACTSDIRECTORY = [$SYSTEM_ARTIFACTSDIRECTORY]"
      docker rm -f openssl3-container 2>/dev/null 1>&2
      docker run --privileged --rm -d --hostname openssl3-container --name openssl3-container \
          -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
          -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
          -v "$SYSTEM_ARTIFACTSDIRECTORY:$SYSTEM_ARTIFACTSDIRECTORY" \
          -e IMAGE="$IMAGE" \
          -e ARG_TESTS="$ARG_TESTS" \
          -e SSL_VERSION="$SSL_VERSION" \
          -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
          -w /App -v "$(pwd -P)":/App \
          "$IMAGE" sh -c "tail -f /dev/null"

      if [[ "$IMAGE" == *alpine* ]]; then docker exec -t openssl3-container sh -c "echo installing bash on alpine; apk update --no-progress; apk add --no-progress xz curl tar sudo bzip2 bash; apk add --no-progress bash icu-libs ca-certificates libstdc++; echo apk done"; fi

      docker exec openssl3-container bash -e -c "bash install-build-tools-bundle.sh; bash Install-DevOps-Library.sh; Repair-Legacy-OS-Sources --update-repo"

      Say "Container apt repo"
      docker exec openssl3-container bash -c "cat /etc/apt/sources.list 2>/dev/null || true"

      Say "RUN Building '$ARTIFACT_NAME' ... "
      docker exec openssl3-container bash -eu -o pipefail -c "
        set -e; set -u; set -o pipefail; Say --Reset-Stopwatch
        Say 'Starting container for $ARTIFACT_NAME ... '
        bash OpenSSL3/Build-Local.sh
      "
