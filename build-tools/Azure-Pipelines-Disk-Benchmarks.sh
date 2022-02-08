set -eu; set -o pipefail
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash >/dev/null
Say --Reset-Stopwatch

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

Wrap-Cmd sudo lsof >/dev/null

export KEEP_FIO_TEMP_FILES="yes" # non empty string keeps a file between benchmarks
sudo swapoff /mnt/swapfile
sudo rm -f /mnt/swapfile

Say "sudo fdisk -l"
sudo fdisk -l
Say "sudo df -h -T"
sudo df -h -T

Wrap-Cmd sudo lsof >/dev/null


sdb_path="/dev/sdb"
sdb_path="$(sudo df | grep "/mnt" | awk '{print $1}')"
sdb_path="${sdb_path::-1}"
Say "/mnt disk: [$sdb_path]"

function Reset-Sdb-Disk() {
    Say "Reset-Sdb-Disk [$sdb_path]"
    Drop-FS-Cache
    Say "sudo umount /mnt"
    sudo umount /mnt
    Say "Execute fdisk"
    echo "d
n
p
1

+100M
n
p
2


w
" | sudo fdisk "${sdb_path}"

    Say "fdisk -l ${sdb_path}"
    sudo fdisk -l ${sdb_path}
    sleep 5
    sudo mkswap -f "${sdb_path}1" || true # DEBUG ONLY
    sudo swapon -f "${sdb_path}1" || true # DEBUG ONLY
    Say "swapon"
    sudo swapon
    sdb2size="$(sudo fdisk -l ${sdb_path} | grep "${sdb_path}2" | awk '{printf "%5.0f\n", ($3-$2)/2}')"
    Say "sdb2size: [$sdb2size] KB"

}


function Free-Loop-Buffers() {
    return;
    # wrong - volumes are switched into readonly mode cauze of OOM
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
| Volume Benchmark Options                   |    Seq Read   |   Seq Write   |  Random Read  | Random Write  |
| ------------------------------------------ | ------------: | ------------: | ------------: | ------------: |" > "$total_report_file"
    fi
    # 1 - seq read, 2 - seq write, 3 - random read, 4 - random write
    Drop-FS-Cache
    Say "Free-Loop-Buffers"; time Free-Loop-Buffers
    Wrap-Cmd sudo -E File-IO-Benchmark "$@"
    local logFile="$LOG_FILE"
    cat "$logFile" | awk '$1 == "READ:" || $1 == "WRITE:" {print $2}' | awk -F'=' '{print $2}' | tee /tmp/4speed
    info="| $(printf "%-42s" "$1") |"
    for line in {1..4}; do
      local speed="$(cat "/tmp/4speed" | awk -v line="$line" 'NR==line {print $1}')"
      info="${info}$(printf "%14s" "$speed") |"
    done
    echo "$info" | tee -a "$total_report_file" >/dev/null
    cat "$total_report_file"
}

function Test-Raid0-on-Loop() {
    local freeSpace="$(Get-Free-Space-For-Directory-in-KB "/mnt")"
    local size=$(((freeSpace-500*1000)/1024))
    size=$((12*1025))
    if [[ "$SECOND_DISK_MODE" == "LOOP" ]]; then
      Wrap-Cmd sudo fallocate -l "${size}M" /mnt/disk-on-mnt
      Wrap-Cmd sudo losetup --direct-io=${LOOP_DIRECT_IO} /dev/loop21 /mnt/disk-on-mnt
      second_raid_disk="/dev/loop21"
    else
      second_raid_disk="${sdb_path}2"
    fi
    Wrap-Cmd sudo fallocate -l "${size}M" /disk-on-root
    Wrap-Cmd sudo losetup --direct-io=${LOOP_DIRECT_IO} /dev/loop22 /disk-on-root
    Wrap-Cmd sudo losetup -a
    Wrap-Cmd sudo losetup -l
    # Wrap-Cmd sudo mdadm --zero-superblock --verbose --force /dev/loop{21,22}

    Say "mdadm --create ..."
    yes | sudo mdadm --create /dev/md0 --force --level=0 --raid-devices=2 "$second_raid_disk" /dev/loop22 || true
    sleep 1
    Wrap-Cmd sudo mdadm --detail /dev/md0

    Say "sudo mkfs.ext2 /dev/md0; and mount"
    Wrap-Cmd sudo mkdir -p /raid-${LOOP_TYPE}
    # wrap next two lines to parameters
    if [[ "$FS" == EXT2 ]]; then
      Wrap-Cmd sudo mkfs.ext2 /dev/md0
      Wrap-Cmd sudo mount -o defaults,noatime,nodiratime /dev/md0 /raid-${LOOP_TYPE}
    elif [[ "$FS" == EXT4 ]]; then
      Wrap-Cmd sudo mkfs.ext4 /dev/md0
      Wrap-Cmd sudo mount -o defaults,noatime,nodiratime,commit=1000,barrier=0 /dev/md0 /raid-${LOOP_TYPE}
    elif [[ "$FS" == BTRFS ]]; then
      Wrap-Cmd sudo mkfs.btrfs -m single -d single -f -O ^extref,^skinny-metadata /dev/md0
      Wrap-Cmd sudo mount -t btrfs /dev/md0 /raid-${LOOP_TYPE} -o defaults,noatime,nodiratime,commit=2000,nodiscard,nobarrier
    elif [[ "$FS" == BTRFS-Сompressed ]]; then
      Wrap-Cmd sudo mkfs.btrfs -m single -d single -f -O ^extref,^skinny-metadata /dev/md0
      Wrap-Cmd sudo mount -t btrfs /dev/md0 /raid-${LOOP_TYPE} -o defaults,noatime,nodiratime,compress-force=lzo:1,commit=2000,nodiscard,nobarrier
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
    
    Smart-Fio "RAID-${LOOP_TYPE}-${SECOND_DISK_MODE}-${FS}-${WORKING_SET_SIZE_TITLE}Gb"  /raid-${LOOP_TYPE} "${WORKING_SET_REAL_SIZE}M" ${DURATION} 0

    Wrap-Cmd sudo cat /proc/mdstat
    Wrap-Cmd sudo lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT

    Drop-FS-Cache
    Say "Destory /raid-${LOOP_TYPE}"
    Wrap-Cmd sudo umount /raid-${LOOP_TYPE}
    Drop-FS-Cache; sleep 9; Drop-FS-Cache;
    Wrap-Cmd sudo try-and-retry mdadm --stop /dev/md0 # SOMETIMES FAILS 1/17th (ext4 for example)
    Wrap-Cmd sudo cat /proc/mdstat
    Say "UnMap loop"
    Wrap-Cmd sudo losetup -d /dev/loop22
    if [[ "$SECOND_DISK_MODE" == "LOOP" ]]; then Wrap-Cmd sudo losetup -d /dev/loop21; fi
    Wrap-Cmd sudo losetup -a
    Wrap-Cmd sudo losetup -l
    Wrap-Cmd sudo rm -v -f /disk-on-root
    if [[ "$SECOND_DISK_MODE" == "LOOP" ]]; then Wrap-Cmd sudo rm -v -f /mnt/disk-on-mnt; fi

}

Wrap-Cmd sudo cat /etc/mdadm/mdadm.conf



for SECOND_DISK_MODE in LOOP; do #order matters: LOOP and later BLOCK
    if [[ "$SECOND_DISK_MODE" == "BLOCK" ]]; then
      Reset-Sdb-Disk
    fi
    export KEEP_FIO_TEMP_FILES="yes" # non empty string keeps a file between benchmarks
    for LOOP_DIRECT_IO in off on; do
        LOOP_TYPE=Buffered; [[ "$LOOP_DIRECT_IO" == on ]] && LOOP_TYPE=Direct
        for fs in BTRFS-Сompressed BTRFS EXT4 EXT2; do
            size_scale=1024 DURATION=50  # RELEASE
            # size_scale=10 DURATION=3     # DEBUG
            workingSetList="1 2 3 4 5 8 16"
            for workingSet in $workingSetList; do
                WORKING_SET_SIZE_TITLE="$workingSet"
                WORKING_SET_REAL_SIZE="$((workingSet * size_scale))"
                # On each benchmark we recreate file system so all the buffers are flushed
                FS=$fs Test-Raid0-on-Loop
            done
        done
    done
done

exit; # DEBUG, but already gathered
# BEFORE Reset-Sdb-Disk
export KEEP_FIO_TEMP_FILES=""
Smart-Fio 'Small-ROOT' / "1G" 15 3
Smart-Fio 'Small-/mnt' /mnt "1G" 15 3

ws="$(Get-Working-Set-for-Directory-in-KB "/mnt")"; ws=$((ws/1024))
Say "LARGE /mnt, WORKING SET: $ws MB"
Smart-Fio "LARGE-/mnt-${ws}MB" /mnt "${ws}M" 60 15

ws="$(Get-Working-Set-for-Directory-in-KB "/")"; ws=$((ws/1024))
Say "LARGE / (the root), WORKING SET: $ws MB"
Smart-Fio "Large-ROOT-${ws}MB" / "${ws}M" 60 15


