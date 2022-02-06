set -eu; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null

Say "Default / (the root)"
time sudo File-IO-Benchmark 'ROOT' /    12G 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/default-root-benchmark.console.txt"

Say "Default /mnt"
time sudo File-IO-Benchmark '/MNT' /mnt 12G 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/default-mnt-benchmark.console.txt"

