set -eu; set -o pipefail

  Download-File https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/build-gcc-utilities.sh build-utilities.sh
  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

for debian_ver in 10 11 12 13; do
      IMAGE="debian:$debian_ver"
      docker rm -f openssl3-container >/dev/null 2>&1
      docker run --privileged --rm -d --hostname openssl3-container --name openssl3-container \
          -v "$SYSTEM_ARTIFACTSDIRECTORY:$SYSTEM_ARTIFACTSDIRECTORY" \
          -e IMAGE="$IMAGE" \
          -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" \
          -w /App -v "$(pwd -P)":/App \
          "$IMAGE" sh -c "tail -f /dev/null"

      docker exec openssl3-container bash -e -c "bash install-build-tools-bundle.sh; bash Install-DevOps-Library.sh; . ./build-utilities.sh; adjust_os_repo"

      Say "Container repo"
      docker exec openssl3-container bash -c "test -e /etc/apt/sources.list && cat /etc/apt/sources.list || echo ABSENT"

      Say "RUN BENCHMARK for $IMAGE ... "
      docker exec openssl3-container bash -eu -o pipefail -c "
        set -e; set -u; set -o pipefail; Say --Reset-Stopwatch
        Say 'Starting container for $IMAGE ... '
        . ./OpenSSL3/Functions.sh
        try-and-retry apt-get install openssl sudo xz-utils -y --force-yes
        LOG_NAME="$SYSTEM_ARTIFACTSDIRECTORY/OpenSSL-DEBIAN-$debian_ver-$(Get-NET-RID)"
        export COLUMN_TYPE=system
        Benchmark-OpenSSL openssl
      "

done
