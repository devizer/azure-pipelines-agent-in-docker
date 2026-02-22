  
  Download-File https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/build-gcc-utilities.sh build-utilities.sh
  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

      
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
      

      
      Say "Start image $(IMAGE)"
      docker run --privileged -t --rm -d --hostname gcc-container --name gcc-container \
          -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
          -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
          -e IMAGE="$IMAGE" \
          -e SSL_VERSION="$SSL_VERSION" \
          -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
          "$IMAGE" sh -c "tail -f /dev/null"

      for cmd in install-build-tools-bundle.sh Install-DevOps-Library.sh build-utilities.sh; do
        docker cp $(pwd -P)/$cmd gcc-container:/$cmd
      done
      if [[ "$IMAGE" == alpine* ]]; then docker exec -t gcc-container sh -c "apk update --no-progress; apk add --no-progress curl tar sudo bzip2 bash; apk add --no-progress bash icu-libs ca-certificates krb5-libs libgcc libstdc++ libintl libstdc++ tzdata userspace-rcu zlib openssl; echo"; fi

      docker exec gcc-container bash /install-build-tools-bundle.sh
      docker exec gcc-container bash /Install-DevOps-Library.sh
      docker exec gcc-container bash -c ". /build-utilities.sh; adjust_os_repo"

      Say "RUN Building '$ARTIFACT_NAME' ... "
      docker exec gcc-container bash -c "
        set -e; set -u; set -o pipefail; Say --Reset-Stopwatch
        Say 'Starting container for $ARTIFACT_NAME ... '
      "
