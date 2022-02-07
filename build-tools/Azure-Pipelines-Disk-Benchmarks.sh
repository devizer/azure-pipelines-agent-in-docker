set -eu; set -o pipefail

CMD_COUNT=0
function Wrap-Cmd-With-Key() {
    local key="$1"
    CMD_COUNT=$((CMD_COUNT+1))
    local fileName="$SYSTEM_ARTIFACTSDIRECTORY/$(printf "%04u" "$CMD_COUNT") $key"
    shift 
    eval "$@" |& tee "$fileName"
}

function Wrap-Cmd() {
    local cmd="$*"
    cmd="${orig//[\/]/∕}"
    CMD_COUNT=$((CMD_COUNT+1))
    local fileName="$SYSTEM_ARTIFACTSDIRECTORY/$(printf "%04u" "$CMD_COUNT") $cmd"
    eval "$@" |& tee "$fileName"
}

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null
Say --Reset-Stopwatch

Say "apt-get install util-linux fio"
sudo apt-get install util-linux fio tree -y -qq >/dev/null
Wrap-Cmd sudo tree -a -h -u /mnt
Wrap-Cmd sudo swapon
sudo cp -f /mnt/*.txt "$SYSTEM_ARTIFACTSDIRECTORY/"
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

function Setup-Raid0-Prev() {
    local freeSpace="$(Get-Free-Space-For-Directory-in-KB "/mnt")"
    local size=$(((freeSpace-500*1000)/1024))
    size=1000
    Say "Allocate ${size} as /mnt/disk-on-mnt"
    sudo fallocate -l "${size}M" /mnt/disk-on-mnt
    size2=1000
    Say "Allocate ${size2} as /disk-on-root"
    sudo fallocate -l "${size}M" /disk-on-root
    Say "sudo losetup /dev/loop21 /mnt/disk-on-mnt"
    sudo losetup --direct-io 0 /dev/loop21 /mnt/disk-on-mnt
    Say "sudo losetup /dev/loop22 /disk-on-root"
    sudo losetup --direct-io 0 /dev/loop22 /disk-on-root
    Say "sudo losetup -a"
    sudo losetup -a
    Say "sudo losetup -a"
    sudo losetup -a
    Say "mdadm --zero-superblock --verbose --force /dev/loop{21,22}"
    sudo mdadm --zero-superblock --verbose --force /dev/loop{21,22}


    Say "mdadm --create ..."
    # sudo mdadm --create --verbose /dev/md0 --level=raid0  --raid-devices=2 /dev/loop21 /dev/loop22 || true
    yes | sudo mdadm --create /dev/md0 --force --level=0 --raid-devices=2 /dev/loop21 /dev/loop22 || true
    
    Say "sleep 3 seconds"
    sleep 3

    Say "mdadm --detail"
    sudo mdadm --detail /dev/md0 || true

    Say "sudo mkfs.ext2 /dev/md0; and mount"
    sudo mkfs.ext2 /dev/md0
    sudo mkdir -p /raid
    sudo mount -o noatime /dev/md0 /raid 
    sudo chown -R "$(whoami)" /raid
    ls -la /raid

    Say "df -h -T"
    sudo df -h -T

    Say "Setup-Raid0 complete"
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
    sudo losetup --direct-io 0 /dev/loop21 /mnt/disk-on-mnt
    Say "sudo losetup /dev/loop22 /disk-on-root"
    sudo losetup --direct-io 0 /dev/loop22 /disk-on-root
    Say "sudo losetup -a"
    sudo losetup -a
    Say "sudo losetup -a"
    sudo losetup -a
    Say "mdadm --zero-superblock --verbose --force /dev/loop{21,22}"
    sudo mdadm --zero-superblock --verbose --force /dev/loop{21,22}


    Say "mdadm --create ..."
    # sudo mdadm --create --verbose /dev/md0 --level=raid0  --raid-devices=2 /dev/loop21 /dev/loop22 || true
    yes | sudo mdadm --create /dev/md0 --force --level=0 --raid-devices=2 /dev/loop21 /dev/loop22 || true
    
    Say "sleep 3 seconds"
    sleep 3

    Say "mdadm --detail"
    sudo mdadm --detail /dev/md0 || true

    Say "sudo mkfs.ext2 /dev/md0; and mount"
    sudo mkfs.ext2 /dev/md0
    sudo mkdir -p /raid
    sudo mount -o noatime /dev/md0 /raid 
    sudo chown -R "$(whoami)" /raid
    ls -la /raid

    Say "df -h -T"
    sudo df -h -T

    Say "Setup-Raid0 complete"
}


Wrap-Cmd sudo cat /etc/mdadm/mdadm.conf

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


