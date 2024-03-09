set -o pipefail; set -eu

# 1) Download, 2) Extract initrd.img and vmlinuz 3) Resize up to 4) Move to $to_folder as disk.qcow2
function Prepare-VM-Image() {
  local url="$1"
  local to_folder="$2"
  local size="${3:-16G}"

  sudo mkdir -p "${to_folder}"/temp "${to_folder}"/_logs; sudo chown -R $USER "${to_folder}"; 
  rm -rf "${to_folder}"/temp/* || true
  work="${to_folder}"/temp
  pushd $work >/dev/null
  file=original.img
  key=original
  Say "Downloading raw cloud image as $(pwd)/$file"
  echo "URL is $url"
  try-and-retry curl --connect-timeout 30 -ksfSL -o $file "$url" || rm -f $file
  # rpi.img.xz -> rpi.img
  if [[ "$url" == *".xz" ]] || [[ "$url" == *".xz/download" ]]; then echo "Extracting $file.xz"; mv $file $file.xz; cat $file.xz | time xz -d > $file; rm -f $file.xz; fi
  # rpi.zip -> rpi.img
  if [[ "$url" == *".zip" ]]; then echo "Extracting $file.zip"; mv $file $file.zip; 7z x $file.zip; rm -f $file.zip; mv *.img $file; fi
  ls -lah; echo ""
  ls -lah $file
  Say "Extracting kernel from /dev/sda1,2,..."
  mkdir -p $key-MNT $key-BOOTALL $key-BOOT $key-LOGS
  sudo virt-filesystems --all --long --uuid -h -a $file | tee "${to_folder}"/_logs/filesystems.txt
  # http://ask.xmodulo.com/mount-qcow2-disk-image-linux.html
  sudo guestunmount $key-MNT >/dev/null 2>&1 || true
  set +e 
  for boot in $(cat "${to_folder}"/_logs/filesystems.txt | awk '$1 ~ /dev/ && $1 !~ /sda$/ {print $1}' | sort -u); do
    # export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
    echo ""; Say "TRY BOOT VOLUME $boot"
    try-and-retry sudo guestmount -a $file -m $boot $key-MNT
    echo The BOOT content
    sudo ls -la $key-MNT/boot |& tee "${to_folder}"/_logs/$(basename $boot)-boot.files.txt
    echo The ROOT content
    sudo ls -la $key-MNT |& tee "${to_folder}"/_logs/$(basename $boot)-root.files.txt
    sudo cp -f -r $key-MNT/boot/* $key-BOOTALL
    # sudo cp -f -L $key-MNT/boot/{initrd.img,vmlinu?} $key-BOOT
    # ubuntu without any boot volume
    sudo bash -c "cp -f -L $key-MNT/boot/{initrd.img,vmlinu?} $key-BOOT"
    # ubuntu with a boot volume
    sudo bash -c "cp -f -L $key-MNT/{initrd.img,vmlinu?} $key-BOOT"
    # debian
    sudo bash -c "echo 'what about initrd.img?'; ls -lah $key-MNT/initrd.img-*; cp -f -L $key-MNT/initrd.img-* $key-BOOT/initrd.img"
    sudo bash -c "echo 'what about vmlinuz?'; ls -lah $key-MNT/vmlinuz-*; cp -f -L $key-MNT/vmlinuz-* $key-BOOT/vmlinuz"
    sudo bash -c "echo 'what about boot/initrd.img?'; ls -lah $key-MNT/boot/initrd.img-*; cp -f -L $key-MNT/boot/initrd.img-* $key-BOOT/initrd.img"
    sudo bash -c "echo 'what about boot/vmlinuz?'; ls -lah $key-MNT/boot/vmlinuz-*; cp -f -L $key-MNT/boot/vmlinuz-* $key-BOOT/vmlinuz"
    sudo guestunmount $key-MNT
    mv $key-BOOT/vmlinux $key-BOOT/vmlinuz 2>/dev/null
    sudo chown -R $USER $key-BOOT
    if [[ -s $key-BOOT/initrd.img ]] && [[ -s $key-BOOT/vmlinuz ]]; then break; fi
  done
  set -e
  Say "Final Content of Original BOOT"
  sudo chown -R $USER $key-BOOT
  ls -lah $key-BOOT

  if [[ "$size" == "SKIP" ]]; then
    Say "Skip image resizing"
    mv $file $key.qcow2
    cp -f "${to_folder}"/_logs/filesystems.txt "${to_folder}"/_logs/filesystems.resized.txt
  else
    Say "Resizing image up to $size"
    qemu-img create -f qcow2 disk.intermediate.compacting.qcow2 $size
    sudo virt-resize --expand /dev/sda1 $file disk.intermediate.compacting.qcow2
    # qemu-img convert -O qcow2 disk.intermediate.compacting.qcow2 $key.qcow2
    mv disk.intermediate.compacting.qcow2 $key.qcow2 # faster!
    rm -f disk.intermediate.compacting.qcow2
    sudo virt-filesystems --all --long --uuid -h -a $key.qcow2 | tee "${to_folder}"/_logs/filesystems.resized.txt
  fi
  root_partition_index=$(cat "${to_folder}"/_logs/filesystems.resized.txt | awk '$4 ~ /cloudimg-rootfs/ {print $1}' | sed 's/\/dev\/sda//' | sort -u)
  if [[ "${root_partition_index:-}" == "" ]]; then 
    # debian
    root_partition_index=$(cat "${to_folder}"/_logs/filesystems.resized.txt | awk '$3 ~ /ext4/ {print $1}' | sed 's/\/dev\/sda//' | sort -u)
  fi
  mv $key.qcow2 "${to_folder}"/disk.qcow2
  mv $key-BOOT/* "${to_folder}"
  popd >/dev/null
  sudo rm -rf "${to_folder}"/temp
  echo "Completed: " $(ls "${to_folder}" | sort)
  Say "DONE. Root Partition Index is ${root_partition_index:-UNKNOWN}"
  printf $root_partition_index > "${to_folder}"/root.partition.index.txt
}

function Build-Cloud-Config() {
# FOLDER lauch_options:
# ./variables - variables
# ./provisia.tar.gz files
# ./fs - folder with the root file system over sshfs
# ./cloud-config.qcow2
local lauch_options="$1"
mkdir -p "$lauch_options"
echo '
VM_SSH_PORT='$VM_SSH_PORT'
VM_PROVISIA_FOLDER='"'"$VM_PROVISIA_FOLDER"'"'
VM_VARIABLES='"'"${VM_VARIABLES:-}"'"'
VM_USER_NAME='"'"${VM_USER_NAME:-user}"'"'
VM_PREBOOT_SCRIPT='"'"${VM_PREBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_SCRIPT='"'""${VM_POSTBOOT_SCRIPT:-}""'"'
VM_POSTBOOT_ROLE='"'"${VM_POSTBOOT_ROLE:-root}"'"'
VM_OUTCOME_FOLDER='"'"${VM_OUTCOME_FOLDER:-/root}"'"'
' > "$lauch_options/variables"

echo "${VM_VARIABLES:-}" | awk -FFS=";" 'BEGIN{FS=";"}{for(i=1;i<=NF;i++){print $i}}' | while IFS= read -r var; do
  echo "PASS VAR '$var'"
  echo "$var='${!var}'" | tee -a "$lauch_options/variables"
  echo "export $var" | tee -a "$lauch_options/variables"
done

pushd "$HOST_PROVISIA_FOLDER" >/dev/null
tar --owner=0 --group=0 -czf "$lauch_options/provisia.tar.gz" .
popd >/dev/null

echo '
#cloud-config
# debug: false
# disable_root: false
ssh_pwauth: true
ssh_deletekeys: false
preserve_sources_list: true
apt_preserve_sources_list: true
apt:
  preserve_sources_list: true


ssh_keys:
  rsa_private: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    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
    -----END OPENSSH PRIVATE KEY-----

  rsa_public: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNVM1R0R94e/1WIHHJaSPs6oKOXDHzGYfaiwSyz+gr3og0avnNbLEfGfCpybOQB4MYVU0WTy+drwJVTW11BitUXmb1sEvPnATZoAa6rjrAVoC2vqYIktLMoS5q2m9klSy56fh1a31zuI2el9uhJ8wo9C6yXEV8paigZzv6h7jf8Z1TVFpfFORNKSpKKo1DmSVEV487a5f7hxpOjVlfZ3w62LzsmCM7bY+rxrx+rDC4EbixHro4Rxgbb1UC4R+A9Rp/bedzqEU0sniTupGSmgbCt13W0jRjIvLgYXJu80AEHpQH+M7AE5CcosCp3Fxr9f4MG+Tz+qimvUHxLWg1Y+XKhA/gRNFgOtLgkjDt7Tk3+jeQkKBmFvW+ddD5+AU0sL5PCkoSl9m+1OtwhhfczXejclZh/i45zowbOqwk2v55urcxWAiLU2LTEnPGk6xIFMMd9F7lB6s7EomGJdoyn/aQYwuwJngUFgvett+g8ayJjEkm8xoC4ucTVG/dT5q0OcTjRogQK6DsKvIib9q31fL9kFdlFfIU74uUSxJN2hYBG8GhW+n+lUajvbNp2BJzhu+p+oAqldXEGXMUvLnNo9CV5nUdq43oSZGsqWZ+Sy8ODsQLtHNVZ8n/qXjT5qB6gn+JjXFsoRjiZUZt/2Aj1JBgNoIvmMT56WlTUwlITVqDcw== devizer@github.io


bootcmd:
  - |
    header() { printf "  \n----------------\n$1\n"; }

    if [ ! -f /etc/.preboot-completed ]; then
        header "pwd is [$(pwd)]. Environment is"
        echo "BASH_VERSION: $BASH_VERSION"
        printenv | sort

        export USER=root HOME=/root
        header "PROCESSES"
        ps aux
        
        user='$VM_USER_NAME'
        header "UnLock root and create the \"$user\" user"
        useradd -m -s /bin/bash -p pass $user
        pass=p1ssw0rd
        printf "$pass\n$pass\n" | passwd root
        passwd -u root
        printf "$pass\n$pass\n" | passwd $user
        passwd -u $user

        header "Configure SSH Daemon"
        sshd=/etc/ssh/sshd_config
        sed -i "/PasswordAuthentication/d" $sshd
        sed -i "/PermitRoot/d" $sshd
        sed -i "/SetEnv/d" $sshd
        sed -i "/AcceptEnv/d" $sshd
        echo "
           PasswordAuthentication yes
           PermitRootLogin yes
           # pay attention to sudo -E
           AcceptEnv Build_* APPVEYOR* TRAVIS* BUILD_*
        " >> $sshd
        
        header "Change TZ to UTC"
        timedatectl set-timezone UTC
        
        header "Adding user to nopasswd sudoers"
        echo "$user    ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo

        header "Add user to sudo group"
        usermod -aG sudo $user

        header "HOSTNAME configuration"
        if [ -f /etc/os-release ]; then
           . /etc/os-release
           if [ -z "$VERSION_CODENAME" ]; then VERSION_CODENAME=$DISTRIB_CODENAME; fi
           if [ -z "$VERSION_CODENAME" ]; then VERSION_CODENAME=$VERSION_ID; fi
           if [ "$VERSION_CODENAME" = "14.04" ]; then VERSION_CODENAME=trusty; fi
           if [ "$VERSION_CODENAME" = "16.04" ]; then VERSION_CODENAME=xenial; fi
           if [ "$ID-$VERSION_CODENAME" = "debian-8" ]; then VERSION_CODENAME=jessie; fi
        else
           ID=centos
           VERSION_CODENAME=6
        fi
        hostn="$ID-$VERSION_CODENAME-$(uname -m | sed "s/_/\-/g")"
        hostp=$(hostname)
        echo "Changing hostname from [$hostp] to [$hostn]"
        hostname $hostn
        echo "$hostn" > /etc/hostname
        sed -i "/$hostp/d" /etc/hosts
        printf "\n127.0.0.1 $hostn" >> /etc/hosts

        header "FINAL HOSTNAME: [$(hostname)]"

        header "sshd status"
        systemctl status sshd

        # header "REMOVING UNATTENDED-UPGRADES and MAN-DB"
        # time apt-get purge unattended-upgrades man-db vim vim-runtime -y

        # for s in "lvm2-monitor" "blk-availability" "unattended-upgrades" "apt-daily-upgrade.timer" "apt-daily.timer" "logrotate.timer"; do
            # header "Stop and disable [$s]"; time systemctl disable --now $s
        # done

        touch /etc/.preboot-completed
        header "SUCCESSFULLY Finished"
    else
        echo "PREBOOT already completed previously"
    fi
' > /tmp/cloud-config.txt

echo '
runcmd:
  - |
     echo "I am [$(whoami)] running from runcmd section"
     export HOME=/root USER=root DOTNET_CLI_HOME=/usr/share/dotnet DOTNET_ROOT=/usr/share/dotnet DOTNET_HOME=/usr/share/dotnet
     cd $HOME
     script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash

     echo "VALIDATING SYSTEM CLOUD CONFIG"
     cloud-init schema --system

     echo "PROCESSING VM_POSTBOOT_SCRIPT"
     uptime
     source /etc/.variables
     cd "$VM_PROVISIA_FOLDER"
     bash -e -c "$VM_POSTBOOT_SCRIPT"
' >/dev/null

if [[ -n "${SYSTEM_ARTIFACTSDIRECTORY:-}" ]]; then cp -f /tmp/cloud-config.txt $SYSTEM_ARTIFACTSDIRECTORY/_logs || true; fi

Say "cloud-localds verbose output"
cloud-localds -v --disk-format qcow2 "$lauch_options/cloud-config.qcow2" /tmp/cloud-config.txt
echo "DONE: build schema"
Say "VALIDATE CLOUD CONFIG"
sudo cloud-init schema -c /tmp/cloud-config.txt || true
echo "DONE: checkup schema"
}

function Launch-VM() {
  local arch=$1
  local cloud_config=$2
  local location=$3
  if [[ -f $location/root.partition.index.txt ]]; then 
    root_partition_index=$(cat $location/root.partition.index.txt)
  else
    echo "WARNING! Missing $location/root.partition.index.txt. Assuming fiest partition"
  fi

  # https://www.qemu.org/2021/01/19/virtio-blk-scsi-configuration/
  pid=""
  if [[ "$arch" == "arm" ]]; then
      qemu-system-arm -name arm32vm \
          -smp $VM_CPUS -m $VM_MEM -M virt -cpu cortex-a15 \
          -kernel "$location/vmlinuz" -initrd "$location/initrd.img" \
          \
          -global virtio-blk-device.scsi=off \
          -device virtio-scsi-device,id=scsi \
          -drive file="$location/disk.qcow2",id=root,if=none -device scsi-hd,drive=root \
          -drive file="$cloud_config",id=cdrom,if=none,media=cdrom -device virtio-scsi-device -device scsi-cd,drive=cdrom \
          \
          -netdev user,id=net0,hostfwd=tcp::$VM_SSH_PORT-:22 \
          -device virtio-net-device,netdev=net0 \
          -append "console=ttyAMA0 root=/dev/sda${root_partition_index:-1}" \
          -nographic -no-reboot &
        
        pid=$!
  fi

  # $ -blockdev driver=file,node-name=f0,filename=/path/to/floppy.img -device floppy,drive=f0

  if [[ "$arch" == "arm64" ]]; then
      qemu-system-aarch64 -name arm64vm \
          -smp $VM_CPUS -m $VM_MEM -M virt -cpu cortex-a57  \
          -initrd "$location/initrd.img" \
          -kernel "$location/vmlinuz" \
          -append "root=/dev/sda${root_partition_index:-1} console=ttyAMA0" \
          \
          -global virtio-blk-device.scsi=off \
          -device virtio-scsi-device,id=scsi \
          -drive file="$location/disk.qcow2",id=root,if=none -device scsi-hd,drive=root \
          -drive file="$cloud_config",id=cdrom,if=none,media=cdrom -device virtio-scsi-device -device scsi-cd,drive=cdrom \
          \
          -netdev user,hostfwd=tcp::$VM_SSH_PORT-:22,id=net0 -device virtio-net-device,netdev=net0 \
          -nographic -no-reboot &

        pid=$!
  fi

  if [[ -n "$pid" ]]; then
    launch_options="$(dirname "$cloud_config")"
    printf $pid > "$launch_options"/pid
  fi

echo '
works well but sda and sdb are randomized
          -drive file="$location/disk.qcow2",id=root,if=none -device scsi-hd,drive=root \
          -drive file="$cloud_config",id=cloudconfig,if=none -device scsi-hd,drive=cloudconfig \
'>/dev/null
}

function As-Base64() { base64 -w 0; }
function File-To-Base64() { cat "$1" | base64 -w 0; }

# Needs only for Building VM
function Shutdown-VM-and-CleapUP() {
  local lauch_options="$1"
  source "$lauch_options/variables"
  echo '
     set +eu; set -o pipefail
     journalctl --flush --rotate --vacuum-time=1s || journalctl --vacuum-time=1s
     journalctl --user --flush --rotate --vacuum-time=1s || journalctl --user --vacuum-time=1s
     journalctl --vacuum-size=4K
     try-and-retry rm -rf /tmp/* /var/tmp/* /var/cache/apt/* /root/provisia /etc/provisia /root/build
     shutdown -P now || shutdown -H now || shutdown now
     ' > "$lauch_options/shutdown.sh"

  Say "Shutdown VM"
  echo "Content of launch options [$lauch_options]"
  ls -lah "$lauch_options"
  cp -f "$lauch_options/shutdown.sh" "$lauch_options/fs/tmp/shutdown.sh"
  # It normally fails three times because on first ssh server stops
  try-and-retry sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "bash /tmp/shutdown.sh" || true
  sleep 20
  pid="$(cat "$lauch_options/pid")"
  if [[ -z "$pid" ]]; then
    echo "WARNING! Unknown pid. Do not wait"
  else
    echo "VM PID is [$pid]. Waiting for exit"
    wait $pid
  fi

  Say "Shutdown-VM-and-CleapUP() completed."
}

function Wait-For-VM() {
  local lauch_options="$1"

  local n=1
  local startAt="$(get_global_seconds)"
  while [ 1 -eq 1 ]; do
    local current="$(get_global_seconds)"
    elapsed="$((current-startAt))"
    current="$((15*60 - elapsed))"
    if [[ $current -le 0 ]]; then break; fi
    echo "{#$n:$current} Waiting for ssh connection to VM on port $VM_SSH_PORT."
    set +e
    sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "sh -c 'echo; echo WELCOME TO VM; uname -a; uptime'" 2>/dev/null
    local ok=$?;
    set -e
    if [ $ok -eq 0 ]; then break; fi
    sleep 5
    n=$((n+1))
  done
  if [ $ok -ne 0 ]; then
    echo "VM build agent ERROR: VM is not responding via ssh. Elsapsed $elapsed seconds."
    Say --Display-As=Error "VM build agent ERROR: VM is not responding via ssh. Elsapsed $elapsed seconds."
    return 1;
  fi
  local mapto="$lauch_options/fs"
  VM_ROOT_FS="$mapto"
  Say "SSH is ready. Elapsed $elapsed seconds. Mapping root fs to $VM_ROOT_FS"
  sudo mkdir -p "$mapto"; sudo chown -R $USER "$mapto"
  Say "Mapping root fs of the VM to [$mapto] (127.0.0.1) with advanced options v5"
  # -o SSHOPT=StrictHostKeyChecking=no: fuse: unknown option `SSHOPT=StrictHostKeyChecking=no'
  set +e
  # fuse: unknown option(s): `-o defer_permissions'
  # does not work -o reconnect -o Compression=no -o Ciphers=arcfour
  try-and-retry bash -e -c "echo p1ssw0rd | sshfs root@127.0.0.1:/ '$mapto' -p ${VM_SSH_PORT} -o password_stdin -o allow_other"
  # returns mapping error via VM_SSHFS_MAP_ERROR
  VM_SSHFS_MAP_ERROR=$?;
  set -e
  Say "Mapping finished. Exit code $VM_SSHFS_MAP_ERROR";
  if [[ "$VM_SSHFS_MAP_ERROR" != "0" ]]; then exit $VM_SSHFS_MAP_ERROR; fi

  echo Say "SLEEPING?"
  sleep ${SLEEP:-1}


  Say "Provisioning 1) COPYING variables and provisia.tar.gz to VM"
  mkdir -p "$lauch_options/fs/etc/provisia"
  for name in variables provisia.tar.gz; do
    echo "COPYING $name"
    cp -f "$lauch_options/$name" "$lauch_options/fs/etc/$name"
    echo "CH OWNER $lauch_options/fs/etc/$name"
    chown root:root "$lauch_options/fs/etc/$name"
  done 

  Say "Provisioning 2) BUNDLE"
  export TARGET_DIR=$HOME/build/bundle; mkdir -p "$TARGET_DIR"
  script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash >/dev/null
  sudo cp -f "$TARGET_DIR"/* "$lauch_options/fs/usr/local/bin"

  Say "Provisioning 3) EXTRACTING and launching"
  echo '
       set -eu;

       export USER=root HOME=/root
       Say "Welcome to VM host $(hostname)"
       cat /etc/variables
       source /etc/variables
       VM_PROVISIA_FOLDER="${VM_PROVISIA_FOLDER:-$HOME}"
       echo "EXTRACTING provisia.tar.gz to $VM_PROVISIA_FOLDER"
       mkdir -p "${VM_PROVISIA_FOLDER:-$HOME}"
       cd $VM_PROVISIA_FOLDER
       tar xzf /etc/provisia.tar.gz
       err=0
       if [[ -n "${VM_POSTBOOT_SCRIPT:-}" ]]; then
         bash -c "$VM_POSTBOOT_SCRIPT" || err=111
         if [[ $err == 0 ]]; then
           Say "SUCCESS. JOB DONE at VM. Uptime: $(uptime -p)"
         else
           Say --Display-As=Error "JOB FAILED. Uptime: $(uptime -p)"
         fi
       else
         echo "MISSING VM_POSTBOOT_SCRIPT PARAMETER"
       fi
       
       Say "Storing outcome folder [$VM_OUTCOME_FOLDER] as /outcome.tar"
       pushd $VM_OUTCOME_FOLDER
       tar cf /tmp/job-outcome.tar .
       popd
       Say "Bye. Uptime: $(uptime -p). Err=$err"
       exit $err
' > "$lauch_options/fs/tmp/launcher.sh"
  sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "bash -e /tmp/launcher.sh"
  Say "Grab Outcome folder (at VM) /outcome.tar to $HOST_OUTCOME_FOLDER"
  cp -f -v $lauch_options/fs/tmp/job-outcome.tar /tmp/outcome.tar
  Say "Extract outcome.tar to $HOST_OUTCOME_FOLDER"
  sudo mkdir -p $HOST_OUTCOME_FOLDER; sudo chown -R $USER $HOST_OUTCOME_FOLDER
  pushd $HOST_OUTCOME_FOLDER
    tar xf /tmp/outcome.tar
  popd
}

# Copy from Say
function get_global_seconds() {
  theSYSTEM="${theSYSTEM:-$(uname -s)}"
  if [[ ${theSYSTEM} != "Darwin" ]]; then
      # uptime=$(</proc/uptime);                                # 42645.93 240538.58
      uptime="$(cat /proc/uptime 2>/dev/null)";                 # 42645.93 240538.58
      if [[ -z "${uptime:-}" ]]; then
        # secured, use number of seconds since 1970
        echo "$(date +%s)"
        return
      fi
      IFS=' ' read -ra uptime <<< "$uptime";                    # 42645.93 240538.58
      uptime="${uptime[0]}";                                    # 42645.93
      uptime=$(LC_ALL=C LC_NUMERIC=C printf "%.0f\n" "$uptime") # 42645
      echo $uptime
  else 
      # https://stackoverflow.com/questions/15329443/proc-uptime-in-mac-os-x
      boottime=`sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g'`
      unixtime=`date +%s`
      timeAgo=$(($unixtime - $boottime))
      echo $timeAgo
  fi
}


function VM-Launcher-Smoke-Test() {
  FW_TEST_VERSION=net472
  mkdir -p /tmp/cloud-init-smoke-test-provisia
  git clone https://github.com/devizer/Universe.CpuUsage /tmp/cloud-init-smoke-test-provisia
  Say "Build Universe.CpuUsage"
  pushd /tmp/cloud-init-smoke-test-provisia
  Reset-Target-Framework -fw $FW_TEST_VERSION -l latest
  cd Universe.CpuUsage.Tests
  time msbuild /t:Restore,Build /p:Configuration=Release /v:m
  popd
  cp -f VM-Initial-Provisioning.sh /tmp/cloud-init-smoke-test-provisia

  VM_POSTBOOT_SCRIPT='
    export FW_TEST_VERSION='$FW_TEST_VERSION'; 
    bash -eu VM-Initial-Provisioning.sh
'
  VM_POSTBOOT_ROLE='root'
  VM_OUTCOME_FOLDER='/root'
  HOST_OUTCOME_FOLDER=$SYSTEM_ARTIFACTSDIRECTORY/_outcome
  VM_VARIABLES="BUILD_SOURCEVERSION;FORTY_TWO"
  FORTY_TWO=42
  VM_SSH_PORT=2345
  VM_CPUS=2
  VM_MEM=2048M
  HOST_PROVISIA_FOLDER=/tmp/cloud-init-smoke-test-provisia
  VM_PROVISIA_FOLDER=/root/provisia
  VM_USER_NAME=john
  Build-Cloud-Config "/tmp/provisia"
  ls -la "/tmp/provisia/cloud-config.qcow2"
  Say "THEARCH: $THEARCH"
  Launch-VM $THEARCH "/tmp/provisia/cloud-config.qcow2" /transient-builds/run
  sleep 1

  Wait-For-VM "/tmp/provisia"
  pushd $HOST_OUTCOME_FOLDER/_logs; cp -a * $SYSTEM_ARTIFACTSDIRECTORY/_logs; popd
  Say "(2nd) Mapping finished. Exit code $VM_SSHFS_MAP_ERROR";
  sleep 1 # sleep 30
  echo "FS AS SUDO: $(sudo ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  echo "FS AS USER: $(ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  Say "VM-Launcher-Smoke-Test() COMPLETED."

  Shutdown-VM-and-CleapUP "/tmp/provisia"
}
