set -eu; set -o pipefail
  
  Download-File https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/build-gcc-utilities.sh build-utilities.sh
  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

      
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
      

      
      Say "Starting image $IMAGE"
      echo "SYSTEM_ARTIFACTSDIRECTORY = [$SYSTEM_ARTIFACTSDIRECTORY]"
      docker rm -f openssl3-container 2>/dev/null 1>&2
      docker run --privileged --rm -d --hostname openssl3-container --name openssl3-container \
          -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
          -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
          -v "$SYSTEM_ARTIFACTSDIRECTORY:$SYSTEM_ARTIFACTSDIRECTORY" \
          -e IMAGE="$IMAGE" \
          -e SSL_VERSION="$SSL_VERSION" \
          -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
          "$IMAGE" sh -c "tail -f /dev/null"

      for cmd in install-build-tools-bundle.sh Install-DevOps-Library.sh build-utilities.sh; do
        docker cp $(pwd -P)/$cmd openssl3-container:/$cmd
      done
      docker cp OpenSSL3/Build-Local.sh openssl3-container:/Build-Local.sh
      if [[ "$IMAGE" == alpine* ]]; then docker exec -t openssl3-container sh -c "apk update --no-progress; apk add --no-progress curl tar sudo bzip2 bash; apk add --no-progress bash icu-libs ca-certificates krb5-libs libgcc libstdc++ libintl libstdc++ tzdata userspace-rcu zlib openssl; echo"; fi

      docker exec openssl3-container bash /install-build-tools-bundle.sh
      docker exec openssl3-container bash /Install-DevOps-Library.sh
      docker exec openssl3-container bash -c ". /build-utilities.sh; adjust_os_repo"

      Say "Container repo"
      docker exec openssl3-container bash -c "cat /etc/apt/sources.list"

      Say "RUN Building '$ARTIFACT_NAME' ... "
      docker exec openssl3-container bash -eu -o pipefail -c "
        set -e; set -u; set -o pipefail; Say --Reset-Stopwatch
        Say 'Starting container for $ARTIFACT_NAME ... '
        bash /Build-Local.sh
      "
