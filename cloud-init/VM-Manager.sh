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
  else
    Say "Resizing image up to $size"
    qemu-img create -f qcow2 disk.intermediate.compacting.qcow2 $size
    sudo virt-resize --expand /dev/sda1 $file disk.intermediate.compacting.qcow2
    # qemu-img convert -O qcow2 disk.intermediate.compacting.qcow2 $key.qcow2
    mv disk.intermediate.compacting.qcow2 $key.qcow2 # faster!
    rm -f disk.intermediate.compacting.qcow2
  fi
  sudo virt-filesystems --all --long --uuid -h -a $key.qcow2 | tee "${to_folder}"/_logs/filesystems.resized.txt
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
VM_PROVISIA_FOLDER='"'"$VM_PROVISIA_FOLDER"'"'
VM_VARIABLES='"'"${VM_VARIABLES:-}"'"'
VM_USER_NAME='"'"${VM_USER_NAME:-user}"'"'
VM_PREBOOT_SCRIPT='"'"${VM_PREBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_SCRIPT='"'""${VM_POSTBOOT_SCRIPT:-}""'"'
VM_POSTBOOT_ROLE='"'"${VM_POSTBOOT_ROLE:-root}"'"'
VM_OUTCOME_FOLDER='"'"${VM_OUTCOME_FOLDER:-/root}"'"'
' > "$lauch_options/variables"

pushd "$HOST_PROVISIA_FOLDER" >/dev/null
tar --owner=0 --group=0 -czf "$lauch_options/provisia.tar.gz" .
popd >/dev/null

echo '
#cloud-config
# debug: false
# disable_root: false
ssh_pwauth: true
# ssh_deletekeys: False

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
  if [[ "$arch" == "arm" ]]; then
      qemu-system-arm -name arm32vm \
          -smp $VM_CPUS -m $VM_MEM -M virt -cpu cortex-a15 \
          -kernel "$location/vmlinuz" -initrd "$location/initrd.img" \
          \
          -global virtio-blk-device.scsi=off \
          -device virtio-scsi-device,id=scsi \
          -drive file="$location/disk.qcow2",id=root,if=none -device scsi-hd,drive=root \
          -blockdev driver=file,node-name=f0,filename="$cloud_config" -device floppy,drive=f0 \
          \
          -netdev user,id=net0,hostfwd=tcp::$VM_SSH_PORT-:22 \
          -device virtio-net-device,netdev=net0 \
          -append "console=ttyAMA0 root=/dev/sda${root_partition_index:-1}" \
          -nographic &
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
          -blockdev driver=file,node-name=f0,filename="$cloud_config" -device floppy,drive=f0 \
          \
          -netdev user,hostfwd=tcp::$VM_SSH_PORT-:22,id=net0 -device virtio-net-device,netdev=net0 \
          -nographic &
  fi

echo '
works well but sda and sdb are randomized
          -drive file="$location/disk.qcow2",id=root,if=none -device scsi-hd,drive=root \
          -drive file="$cloud_config",id=cloudconfig,if=none -device scsi-hd,drive=cloudconfig \
'>/dev/null
}

function As-Base64() { base64 -w 0; }
function File-To-Base64() { cat "$1" | base64 -w 0; }

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
         eval "$VM_POSTBOOT_SCRIPT" || err=111
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
       tar cf /outcome.tar .
       popd
       Say "Bye. Uptime: $(uptime -p)"
' > "$lauch_options/fs/tmp/launcher.sh"
  sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "bash -e /tmp/launcher.sh"
  Say "Grab Outcome folder (at VM) /outcome.tar to $HOST_OUTCOME_FOLDER"
  cp -f -v $lauch_options/fs/outcome.tar /tmp/outcome.tar
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

  VM_POSTBOOT_SCRIPT='
echo IM CUSTOM POST-BOOT. FOLDER IS $(pwd). USER IS $(whoami). CONTENT IS BELOW; ls -lah;

Say "APT UPDATE"
apt-get --allow-releaseinfo-change update -qq || apt-get update -qq
apt-get install -y debconf-utils

Say "Grab debconf-get-selections"
debconf-get-selections --installer |& tee /root/debconf-get-selections.part1.txt || true
debconf-get-selections             |& tee /root/debconf-get-selections.part2.txt || true

Say "Query package list"
list-packages > /root/packages.txt
echo "Total packages: $(cat /root/packages.txt | wc -l)"

Say "RAM DISK for /tmp"
mount -t tmpfs -o mode=1777 tmpfs /tmp
Say "RAM DISK for /var/tmp"
mount -t tmpfs -o mode=1777 tmpfs /var/tmp
Say "RAM DISK for /var/lib/apt"
mount -t tmpfs tmpfs /var/lib/apt
Say "RAM DISK for /var/cache/apt"
mount -t tmpfs tmpfs /var/cache/apt
Say "Mounts"
df -h -T

Say "FREE MEMORY"; free -m;
echo "FREE SPACE"; df -h -T;
Say "OS IS"; cat /etc/*release;
Say "Time Zone Is"; cat /etc/timezone
Say "Locales are"; locale --all
Say "Current Locale"; locale
export GCC_FORCE_GZIP_PRIORITY=true
Say "Installing MONO"; time (export INSTALL_DIR=/usr/local TOOLS="mono"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing MS BUILD"; time (export MSBUILD_INSTALL_VER=16.6 MSBUILD_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/msbuild/Install-MSBuild.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing .NET Test Runners"; time (url=https://raw.githubusercontent.com/devizer/glist/master/bin/net-test-runners.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -sSL $url) | bash)
time nunit3-console
Say "Test CSC"
echo -e "public class Program {public static void Main() {System.Console.WriteLine(\"Hello World\");}}" > /tmp/hello-world.cs
time csc -out:/tmp/hello-world.exe /tmp/hello-world.cs
Say "Exec /tmp/hello-world.exe"
time mono /tmp/hello-world.exe


Say "Import Mozilla Certificates"
time try-and-retry try-and-retry mozroots --import --sync
Say "Installing Mono Certificates snapshot"
time (script="https://master.dl.sourceforge.net/project/gcc-precompiled/ca-certificates/update-ca-certificates.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash || true)

# oldpwd=$(pwd)
# Say "OPTIONAL Build Universe.CpuUsage"
# net47 error: /usr/local/lib/mono/msbuild/Current/bin/Microsoft.Common.CurrentVersion.targets(2101,5): error MSB3248: Parameter "AssemblyFiles" has invalid value "/usr/local/lib/mono/4.7-api/mscorlib.dll". Could not load file or assembly "System.Reflection.Metadata, Version=1.4.3.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" or one of its dependencies. [/root/provisia/Universe.CpuUsage/Universe.CpuUsage.csproj]
# Reset-Target-Framework -fw '$FW_TEST_VERSION' -l latest
pushd Universe.CpuUsage.Tests
# time msbuild /t:Restore,Build /p:Configuration=Release /v:m |& tee $oldpwd/msbuild.log || Say --Display-As=Error "MSBUILD FAILED on $(hostname)"
Say "TEST Universe.CpuUsage"
export SKIP_POSIXRESOURCESUSAGE_ASSERTS=True
cd bin/Release/'$FW_TEST_VERSION'
time nunit3-console --workers 1 Universe.CpuUsage.Tests.dll
popd

Say "Installing nuget"
url=https://raw.githubusercontent.com/devizer/glist/master/bin/install-nuget-6.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
time nuget 2>&1 >/tmp/nuget.ver; cat /tmp/nuget.ver | head -1
Say "/etc/os-release"
cat "/etc/os-release"
'
  VM_POSTBOOT_ROLE='root'
  VM_OUTCOME_FOLDER='/root'
  HOST_OUTCOME_FOLDER=$SYSTEM_ARTIFACTSDIRECTORY/_outcome
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
  Say "(2nd) Mapping finished. Exit code $VM_SSHFS_MAP_ERROR";
  sleep 1 # sleep 30
  echo "FS AS SUDO: $(sudo ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  echo "FS AS USER: $(ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  Say "VM-Launcher-Smoke-Test() COMPLETED."
}
