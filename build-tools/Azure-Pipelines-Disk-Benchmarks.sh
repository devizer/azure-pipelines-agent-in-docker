set -eu; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null
Say --Reset-Stopwatch

Say "apt-get install util-linux fio"
sudo apt-get install util-linux fio tree -y -qq >/dev/null
sudo tree -a -h -u /mnt |& tee tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.tree.txt"
sudo swapon |& tee tee "$SYSTEM_ARTIFACTSDIRECTORY/swapon.txt"
cp -f /mnt/* "$SYSTEM_ARTIFACTSDIRECTORY/"
exit 0;


function Get-Free-Space-For-Directory-in-KB() {
    local dir="${1}"
    pushd "$dir" >/dev/null
      df -P . | tail -1 | awk '{print $4}'
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

Say "sudo cat /proc/mdstat"
sudo cat /proc/mdstat || true
Say "cat /proc/mdstat"
cat /proc/mdstat || true
Say "lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT"
sudo lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT

Say "Small /mnt"
sudo Drop-FS-Cache
time sudo File-IO-Benchmark 'Small /mnt' /mnt "1G" 15 3 | tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.small-benchmark.console.txt"
Say "Small ROOT"
sudo Drop-FS-Cache
time sudo File-IO-Benchmark 'Small ROOT' / "1G" 15 3 | tee "$SYSTEM_ARTIFACTSDIRECTORY/root.small-benchmark.console.txt"

sudo Drop-FS-Cache
ws="$(Get-Working-Set-for-Directory-in-KB "/mnt")"; ws=$((ws/1024))
Say "LARGE /mnt, WORKING SET: $ws MB"
time sudo File-IO-Benchmark 'LARGE /mnt' /mnt "${ws}M" 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.large-benchmark.console.txt"

sudo Drop-FS-Cache
ws="$(Get-Working-Set-for-Directory-in-KB "/")"; ws=$((ws/1024))
Say "LARGE / (the root), WORKING SET: $ws MB"
time sudo File-IO-Benchmark 'Large ROOT' / "${ws}M" 60 15 | tee "$SYSTEM_ARTIFACTSDIRECTORY/root.large-benchmark.console.txt"


