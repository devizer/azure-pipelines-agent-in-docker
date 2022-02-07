set -eu; set -o pipefail

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null
Say --Reset-Stopwatch

Say "apt-get install util-linux fio"
sudo apt-get install util-linux fio tree -y -qq >/dev/null
sudo tree -a -h -u /mnt |& tee tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.tree.txt"
sudo swapon |& tee tee "$SYSTEM_ARTIFACTSDIRECTORY/swapon.txt"
sudo cp -f /mnt/*.txt "$SYSTEM_ARTIFACTSDIRECTORY/"


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

function Setup-Raid0() {
    local freeSpace="$(Get-Free-Space-For-Directory-in-KB "/mnt")"
    local size=$(((freeSpace-500*1000)/1024))
    size=1000
    Say "Allocate ${size} as /mnt/disk-on-mnt"
    sudo fallocate -l "${size}M" /mnt/disk-on-mnt
    size2=1000
    Say "Allocate ${size2} as /disk-on-root"
    sudo fallocate -l "${size}M" /disk-on-root
    Say "sudo losetup /dev/loop21 /mnt/disk-on-mnt"
    sudo losetup /dev/loop21 /mnt/disk-on-mnt
    Say "sudo losetup /dev/loop22 /disk-on-root"
    sudo losetup /dev/loop22 /disk-on-root
    Say "sudo losetup -a"
    sudo losetup -a
    Say "mdadm --zero-superblock --verbose --force /dev/loop{21,22}"
    mdadm --zero-superblock --verbose --force /dev/loop{21,22}


    Say "mdadm --create ..."
    sudo mdadm --create --verbose /dev/md0 --level=0  --raid-devices=2 /dev/loop21 /dev/loop22 || true
    Say "mdadm --detail ..."
    sudo mdadm --detail /dev/md0 || true

    Say "Setup-Raid0 complete"
}

Say "/etc/mdadm/mdadm.conf"
sudo cat /etc/mdadm/mdadm.conf |& tee "$SYSTEM_ARTIFACTSDIRECTORY/mdadm.conf" || true

Setup-Raid0



Say "sudo cat /proc/mdstat"
sudo cat /proc/mdstat || true
Say "cat /proc/mdstat"
cat /proc/mdstat || true
Say "lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT"
sudo lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT

Say "Small /mnt"
sudo Drop-FS-Cache
time sudo File-IO-Benchmark 'Small /mnt' /mnt "1G" 15 3 |& tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.small-benchmark.console.txt"
Say "Small ROOT"
sudo Drop-FS-Cache
time sudo File-IO-Benchmark 'Small ROOT' / "1G" 15 3 |& tee "$SYSTEM_ARTIFACTSDIRECTORY/root.small-benchmark.console.txt"

sudo Drop-FS-Cache
ws="$(Get-Working-Set-for-Directory-in-KB "/mnt")"; ws=$((ws/1024))
Say "LARGE /mnt, WORKING SET: $ws MB"
time sudo File-IO-Benchmark 'LARGE /mnt' /mnt "${ws}M" 60 15 |& tee "$SYSTEM_ARTIFACTSDIRECTORY/mnt.large-benchmark.console.txt"

sudo Drop-FS-Cache
ws="$(Get-Working-Set-for-Directory-in-KB "/")"; ws=$((ws/1024))
Say "LARGE / (the root), WORKING SET: $ws MB"
time sudo File-IO-Benchmark 'Large ROOT' / "${ws}M" 60 15 |& tee "$SYSTEM_ARTIFACTSDIRECTORY/root.large-benchmark.console.txt"


