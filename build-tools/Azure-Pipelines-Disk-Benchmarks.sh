set -eu; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null

function Get-Free-Space-For-Directory-in-KB() {
    local dir="${1}"
    pushd "$dir" >/dev/null
      df -Ph . | tail -1 | awk '{print $4}'
    popd >/dev/null
}

function Get-Working-Set-for-Directory-in-KB() {
    local dir="${1}"
    local freeSpace="$(Get-Free-Space-For-Directory-in-KB "$dir")"
    local maxKb=$((freeSpace - 500*1000))
    local ret=$((16*1024*1024))
    if [[ "$ret" -gt "$maxKb" ]]; then ret="$maxKb"; fi
    echo "$ret";
}

ws="$(Get-Working-Set-for-Directory-in-KB "/")"
Say "Default / (the root), WORKING SET: $ws KB"
time sudo File-IO-Benchmark 'ROOT' / "${ws}K" 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/default-root-benchmark.console.txt"

ws="$(Get-Working-Set-for-Directory-in-KB "/")"
Say "Default /mnt, WORKING SET: $ws KB"
time sudo File-IO-Benchmark '/MNT' /mnt "${ws}K" 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/default-mnt-benchmark.console.txt"

