set -o pipefail

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
        printenv | sort

        export USER=root HOME=/root

        header "Custom VARIABLES"
        cat /etc/.variables

        header "Extracting provisia"
        pf='$VM_PROVISIA_FOLDER'
        mkdir -p "$pf"
        ls -lah /tmp/.provisia
        tar xzf /tmp/.provisia -C "$pf"
        ls -lah "$pf"
        
        user='$VM_USER_NAME'
        header "UnLock root and create the \"$user\" user"
        useradd -m -s /bin/bash -p pass $user
        pass=p1ssw0rd
        printf "$pass\n$pass\n" | sudo passwd root
        passwd -u root
        printf "$pass\n$pass\n" | sudo passwd $user
        passwd -u user

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
        echo "user    ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo

        header "Add user to sudo group"
        usermod -aG sudo user

        header "HOSTNAME configuration"
        if [ -f /etc/os-release ]; then
           . /etc/os-release
           if [ -z "$VERSION_CODENAME" ]; then VERSION_CODENAME=$VERSION_ID; fi
        else
           ID=centos
           VERSION_CODENAME=6
        fi
        hostn="$ID-$VERSION_CODENAME-$(uname -m | sed "s/_/\-/g")"
        hostp=$(hostname)
        echo "Changing hostname from [$hostn] to [$hostn]"
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

  if [[ "$arch" == "arm" ]]; then
      qemu-system-arm -name arm32vm \
          -smp $VM_CPUS -m $VM_MEM -M virt -cpu cortex-a15 \
          -kernel "$location/vmlinuz" -initrd "$location/initrd.img" \
          -drive file=$cloud_config,if=none,format=qcow2,id=hd1 \
          -device virtio-blk-device,drive=hd1 \
          -drive file="$location/disk.qcow2",if=none,format=qcow2,id=hd0 \
          -device virtio-blk-device,drive=hd0 \
          -netdev user,id=net0,hostfwd=tcp::$VM_SSH_PORT-:22 \
          -device virtio-net-device,netdev=net0 \
          -append "console=ttyAMA0 root=/dev/vda${root_partition_index:-1}" \
          -nographic &
  fi

  if [[ "$arch" == "arm64" ]]; then
      qemu-system-aarch64 -name arm64vm \
          -smp $VM_CPUS -m $VM_MEM -M virt -cpu cortex-a57  \
          -initrd "$location/initrd.img" \
          -kernel "$location/vmlinuz" \
          -append "root=/dev/vda${root_partition_index:-1} console=ttyAMA0" \
          -drive file=$cloud_config,if=none,format=qcow2,id=hd1 \
          -device virtio-blk-device,drive=hd1 \
          -drive file="$location/disk.qcow2",if=none,format=qcow2,id=hd0 \
          -device virtio-blk-device,drive=hd0 \
          -netdev user,hostfwd=tcp::$VM_SSH_PORT-:22,id=net0 -device virtio-net-device,netdev=net0 \
          -nographic &
  fi
}

function As-Base64() { base64 -w 0; }
function File-To-Base64() { cat "$1" | base64 -w 0; }

function Wait-For-VM() {
  local lauch_options="$1"

  local n=150
  while [ $n -gt 0 ]; do
    echo "$n) Waiting for ssh connection to VM on port $VM_SSH_PORT."
    set +e
    sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "sh -c 'echo; echo WELCOME TO VM; uname -a; uptime'" 2>/dev/null
    local ok=$?;
    set -e
    if [ $ok -eq 0 ]; then break; fi
    sleep 5
    n=$((n-1))
  done
  if [ $ok -ne 0 ]; then
    echo "vm build agent ERROR: VM is not responding via ssh"
    return 1;
  fi
  local mapto="$lauch_options/fs"
  VM_ROOT_FS="$mapto"
  echo "SSH is ready. Mapping root fs to $VM_ROOT_FS"
  sudo mkdir -p "$mapto"; sudo chown -R $USER "$mapto"
  Say "Mapping root fs of the VM to [$mapto] (127.0.0.1) with advanced options v5"
  # -o SSHOPT=StrictHostKeyChecking=no: fuse: unknown option `SSHOPT=StrictHostKeyChecking=no'
  set +e
  # fuse: unknown option(s): `-o defer_permissions'
  # does not work -o reconnect -o Compression=no -o Ciphers=arcfour
  echo "p1ssw0rd" | sshfs root@127.0.0.1:/ "$mapto" -p "${VM_SSH_PORT}" -o password_stdin -o allow_other || echo "p1ssw0rd" | sshfs root@127.0.0.1:/ "$mapto" -p "${VM_SSH_PORT}" -o password_stdin -o allow_other
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
       if [[ -n "${VM_POSTBOOT_SCRIPT:-}" ]]; then
         eval "$VM_POSTBOOT_SCRIPT"
       else
         echo "MISSING VM_POSTBOOT_SCRIPT PARAMETER"
       fi
       echo "DONE at VM"
' > "$lauch_options/fs/tmp/launcher.sh"
  sshpass -p "p1ssw0rd" ssh -o StrictHostKeyChecking=no "root@127.0.0.1" -p "${VM_SSH_PORT}" "bash -e /tmp/launcher.sh"
}

function VM-Launcher-Smoke-Test() {
  mkdir -p /tmp/cloud-init-smoke-test-provisia
  git clone https://github.com/devizer/Universe.CpuUsage /tmp/cloud-init-smoke-test-provisia
  VM_SSH_PORT=2345
  VM_CPUS=2
  VM_MEM=2048M
  HOST_PROVISIA_FOLDER=/tmp/cloud-init-smoke-test-provisia
  VM_PROVISIA_FOLDER=/root/provisia
  VM_USER_NAME=user
  VM_POSTBOOT_SCRIPT='
echo IM CUSTOM POST-BOOT. FOLDER IS $(pwd). USER IS $(whoami). CONTENT IS BELOW; ls -lah;
Say "FREE MEMORY"; free -m;
echo "FREE SPACE"; df -h -T;
echo "OS IS"; cat /etc/*release;
Say "Installing MONO"; time (export INSTALL_DIR=/usr/local TOOLS="mono"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing MS BUILD"; export MSBUILD_INSTALL_VER=16.6 MSBUILD_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/msbuild/Install-MSBuild.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | time bash
Say "Installing .NET Test Runners"; url=https://raw.githubusercontent.com/devizer/glist/master/bin/net-test-runners.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -sSL $url) | time bash
nunit3-console
'
  VM_POSTBOOT_ROLE='root'
  VM_OUTCOME_FOLDER='/root'
  Build-Cloud-Config "/tmp/provisia"
  ls -la "/tmp/provisia/cloud-config.qcow2"
  Say "THEARCH: $THEARCH"
  Launch-VM $THEARCH "/tmp/provisia/cloud-config.qcow2" /transient-builds/run
  sleep 30

  Wait-For-VM "/tmp/provisia"
  Say "(2nd) Mapping finished. Exit code $VM_SSHFS_MAP_ERROR";
  sleep 1 # sleep 30
  echo "FS AS SUDO: $(sudo ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  echo "FS AS USER: $(ls /tmp/provisia/fs 2>/dev/null | wc -l) files and folders"
  Say "VM-Launcher-Smoke-Test() COMPLETED."
}
