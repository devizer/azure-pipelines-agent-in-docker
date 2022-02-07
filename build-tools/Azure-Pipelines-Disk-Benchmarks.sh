set -eu; set -o pipefail

CMD_COUNT=0
function Wrap-Cmd() {
    local cmd="$*"
    cmd="${cmd//[\/]/\ ∕}"
    Say "$cmd"
    CMD_COUNT=$((CMD_COUNT+1))
    local fileName="$SYSTEM_ARTIFACTSDIRECTORY/$(printf "%04u" "$CMD_COUNT") ${cmd}.log"
    eval "$@" |& tee "$fileName"
}

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null
Say --Reset-Stopwatch

Say "apt-get install util-linux fio"
sudo apt-get install util-linux fio tree -y -qq >/dev/null
Wrap-Cmd sudo tree -a -h -u /mnt
Wrap-Cmd sudo swapon
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
    size=2000
    Wrap-Cmd sudo fallocate -l "${size}M" /mnt/disk-on-mnt
    size2=2000
    Wrap-Cmd sudo fallocate -l "${size}M" /disk-on-root
    Wrap-Cmd sudo losetup --direct-io=off /dev/loop21 /mnt/disk-on-mnt
    Wrap-Cmd sudo losetup --direct-io=off /dev/loop22 /disk-on-root
    Wrap-Cmd sudo losetup -a
    Wrap-Cmd sudo losetup -l
    Wrap-Cmd sudo mdadm --zero-superblock --verbose --force /dev/loop{21,22}

    Say "mdadm --create ..."
    yes | sudo mdadm --create /dev/md0 --force --level=0 --raid-devices=2 /dev/loop21 /dev/loop22 || true
    
    Say "sleep 3 seconds"
    sleep 3

    Wrap-Cmd sudo mdadm --detail /dev/md0

    Say "sudo mkfs.ext2 /dev/md0; and mount"
    Wrap-Cmd sudo mkfs.ext2 /dev/md0
    Wrap-Cmd sudo mkdir -p /raid-buffered
    Wrap-Cmd sudo mount -o noatime /dev/md0 /raid-buffered
    Wrap-Cmd sudo chown -R "$(whoami)" /raid-buffered
    Wrap-Cmd ls -la /raid-buffered
    Wrap-Cmd sudo df -h -T

    Say "Setup-Raid0 complete"
}

Wrap-Cmd sudo cat /etc/mdadm/mdadm.conf

Setup-Raid0

Drop-FS-Cache
Wrap-Cmd sudo File-IO-Benchmark 'RAID' /raid-buffered "3900M" 20 3


Wrap-Cmd sudo cat /proc/mdstat
Wrap-Cmd sudo lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
Say "Destory /raid-buffered"
Wrap-Cmd sudo umount /raid-buffered
Wrap-Cmd sudo mdadm --stop /dev/md0
Wrap-Cmd sudo cat /proc/mdstat
Say "UnMap loop"
Wrap-Cmd losetup -d /dev/loop{21,22}
Wrap-Cmd losetup -a
Wrap-Cmd losetup -l
Wrap-Cmd rm -v -f /mnt/disk-on-mnt /disk-on-root

exit;

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


