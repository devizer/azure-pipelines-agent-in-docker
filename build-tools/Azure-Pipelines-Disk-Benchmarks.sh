set -eu; set -o pipefail

export KEEP_FIO_TEMP_FILES="yes" # non empty string keeps a file between benchmarks
sudo swapoff /mnt/swapfile
sudo rm -f /mnt/swapfile

sudo fdisk -l
sudo df -h -T




function Free-Loop-Buffers() {
    return;
    # wrong - volumes are switched into readonly mode
    local cfile="${TMPDIR:-/tmp}/mem-stress"
    rm -f "$cfile"
    cat <<-'MEM_STRESS_C' > "$cfile.c"
    #include <stdlib.h>
    #include <sys/sysinfo.h>
    void main() {
    for(long int i = 1; ; ++i) { const unsigned char *ptr = malloc (1000000); }
    }
MEM_STRESS_C
    gcc -O0 $cfile.c -o $cfile
    $cfile || true
}

CMD_COUNT=0
function Wrap-Cmd() {
    local cmd="$*"
    cmd="${cmd//[\/]/\ ∕}"
    cmd="${cmd//[:]/˸}"
    Say "$cmd"
    CMD_COUNT=$((CMD_COUNT+1))
    local fileName="$SYSTEM_ARTIFACTSDIRECTORY/$(printf "%04u" "$CMD_COUNT") ${cmd}.log"
    eval "$@" |& tee "$fileName"
    LOG_FILE="$fileName"
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

function Smart-Fio() {
    local total_report_file="$SYSTEM_ARTIFACTSDIRECTORY/total-report.md";
    if [[ ! -e "$total_report_file" ]]; then
        echo "
| Volume Benchmark Options                |     Seq Read   |    Seq Write   |   Random Read  |  Random Write  |
| --------------------------------------- | -------------: | -------------: | -------------: | -------------: |" > "$total_report_file"
    fi
    # 1 - seq read, 2 - seq write, 3 - random read, 4 - random write
    Drop-FS-Cache
    Say "Free-Loop-Buffers"; time Free-Loop-Buffers
    Wrap-Cmd sudo -E File-IO-Benchmark "$@"
    local logFile="$LOG_FILE"
    cat "$logFile" | awk '$1 == "READ:" || $1 == "WRITE:" {print $2}' | awk -F'=' '{print $2}' | tee /tmp/4speed
    info="| $(printf "%-40s" "$1") |"
    for line in {1..4}; do
      local speed="$(cat "/tmp/4speed" | awk -v line="$line" 'NR==line {print $1}')"
      info="${info}$(printf "%15s" "$speed") |"
    done
    echo "$info" | tee -a "$total_report_file" >/dev/null
    cat "$total_report_file"
}

function Test-Raid0-on-Loop() {
    local freeSpace="$(Get-Free-Space-For-Directory-in-KB "/mnt")"
    local size=$(((freeSpace-500*1000)/1024))
    size=$((12*1025))
    Wrap-Cmd sudo fallocate -l "${size}M" /mnt/disk-on-mnt
    Wrap-Cmd sudo fallocate -l "${size}M" /disk-on-root
    Wrap-Cmd sudo losetup --direct-io=${LOOP_DIRECT_IO} /dev/loop21 /mnt/disk-on-mnt
    Wrap-Cmd sudo losetup --direct-io=${LOOP_DIRECT_IO} /dev/loop22 /disk-on-root
    Wrap-Cmd sudo losetup -a
    Wrap-Cmd sudo losetup -l
    Wrap-Cmd sudo mdadm --zero-superblock --verbose --force /dev/loop{21,22}

    Say "mdadm --create ..."
    yes | sudo mdadm --create /dev/md0 --force --level=0 --raid-devices=2 /dev/loop21 /dev/loop22 || true
    
    Say "sleep 3 seconds?"
    sleep 3

    Wrap-Cmd sudo mdadm --detail /dev/md0

    Say "sudo mkfs.ext2 /dev/md0; and mount"
    Wrap-Cmd sudo mkdir -p /raid-${LOOP_TYPE}
    # wrap next two lines to parameters
    if [[ "$FS" == EXT2 ]]; then
      Wrap-Cmd sudo mkfs.ext2 /dev/md0
      Wrap-Cmd sudo mount -o noatime,nodiratime /dev/md0 /raid-${LOOP_TYPE}
    elif [[ "$FS" == EXT4 ]]; then
      Wrap-Cmd sudo mkfs.ext4 /dev/md0
      Wrap-Cmd sudo mount -o noatime,nodiratime /dev/md0 /raid-${LOOP_TYPE}
    elif [[ "$FS" == BTRFS ]]; then
      Wrap-Cmd sudo mkfs.btrfs -f -O ^extref,^skinny-metadata /dev/md0
      Wrap-Cmd sudo mount -t btrfs /dev/md0 /raid-${LOOP_TYPE} -o defaults,noatime,nodiratime,commit=1000
    elif [[ "$FS" == BTRFS-Сompressed ]]; then
      Wrap-Cmd sudo mkfs.btrfs -f -O ^extref,^skinny-metadata /dev/md0
      Wrap-Cmd sudo mount -t btrfs /dev/md0 /raid-${LOOP_TYPE} -o defaults,noatime,nodiratime,compress-force=lzo:1,commit=1000
    else
      echo "WRONG FS [$FS]"
      exit 77
    fi
    Say "FREE SPACE AFTER MOUNTING of the RAID"
    Wrap-Cmd sudo df -h -T
    Wrap-Cmd sudo chown -R "$(whoami)" /raid-${LOOP_TYPE}
    Wrap-Cmd ls -la /raid-${LOOP_TYPE}
    Wrap-Cmd sudo df -h -T

    Say "Setup-Raid0 as ${LOOP_TYPE} loop complete"
    
    local size_scale=1024 duration=50  # RELEASE
    # local size_scale=10 duration=3     # DEBUG
    local workingSetList="16 8 5 4 3 2 1"
    for workingSet in $workingSetList; do
      local sz=$((workingSet * size_scale))
      Smart-Fio "RAID-${LOOP_TYPE}-${FS}-${workingSet}Gb"  /raid-${LOOP_TYPE} "${sz}M" ${duration} 0
    done

    Wrap-Cmd sudo cat /proc/mdstat
    Wrap-Cmd sudo lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
    Say "Destory /raid-${LOOP_TYPE}"
    Wrap-Cmd sudo umount /raid-${LOOP_TYPE}
    Wrap-Cmd sudo mdadm --stop /dev/md0
    Wrap-Cmd sudo cat /proc/mdstat
    Say "UnMap loop"
    Wrap-Cmd sudo losetup -d /dev/loop{21,22}
    Wrap-Cmd sudo losetup -a
    Wrap-Cmd sudo losetup -l
    Wrap-Cmd sudo rm -v -f /mnt/disk-on-mnt /disk-on-root
}

Wrap-Cmd sudo cat /etc/mdadm/mdadm.conf

export KEEP_FIO_TEMP_FILES="yes" # non empty string keeps a file between benchmarks
for fs in BTRFS-Сompressed BTRFS EXT4 EXT2; do
  FS=$fs LOOP_TYPE=Buffered LOOP_DIRECT_IO=off Test-Raid0-on-Loop
  FS=$fs LOOP_TYPE=Direct   LOOP_DIRECT_IO=on  Test-Raid0-on-Loop
done

export KEEP_FIO_TEMP_FILES=""
Smart-Fio 'Small-/mnt' /mnt "1G" 15 3
Smart-Fio 'Small-ROOT' / "1G" 15 3


ws="$(Get-Working-Set-for-Directory-in-KB "/mnt")"; ws=$((ws/1024))
Say "LARGE /mnt, WORKING SET: $ws MB"
Smart-Fio "LARGE-/mnt-${ws}MB" /mnt "${ws}M" 60 15

ws="$(Get-Working-Set-for-Directory-in-KB "/")"; ws=$((ws/1024))
Say "LARGE / (the root), WORKING SET: $ws MB"
Smart-Fio "Large-ROOT-${ws}MB" / "${ws}M" 60 15


