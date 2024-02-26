
function Build-Cloud-Config() {
variables="$(mktemp)"
echo '
VM_PROVISIA_FOLDER='"'"$VM_PROVISIA_FOLDER"'"'
VM_VARIABLES='"'"${VM_VARIABLES:-}"'"'
VM_USER_NAME='"'"${VM_USER_NAME:-user}"'"'
VM_PREBOOT_SCRIPT='"'"${VM_PREBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_SCRIPT='"'"${VM_POSTBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_ROLE='"'"${VM_POSTBOOT_ROLE:-root}"'"'
VM_OUTCOME_FOLDER='"'"${VM_OUTCOME_FOLDER:-/root}"'"'
' > "$variables"

provisia="$(mktemp)"
pushd "$HOST_PROVISIA_FOLDER" >/dev/null
tar czf "$provisia" .
popd >/dev/null

echo '
#cloud-config
debug: false
disable_root: false
ssh_pwauth: true
ssh_deletekeys: False

write_files:
- encoding: base64
  content: '$(File-To-Base64 "$variables")'
  owner: root:root
  path: /etc/.variables
  permissions: '0644'
- encoding: base64
  content: '$(File-To-Base64 "$provisia")'
  owner: root:root
  path: /tmp/.provisia
  permissions: '0644'
  
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
        
        header "UnLock root and create the \"$user\" user"
        user='$VM_USER_NAME'
        useradd -m -s /bin/bash -p pass $user
        pass=p1ssw0rd
        printf "$pass\n$pass\n" | sudo passwd root
        sudo passwd -u root
        printf "$pass\n$pass\n" | sudo passwd $user
        sudo passwd -u user

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

runcmd:
  - |
     echo "I am [$(whoami)] running from runcmd section"
     export HOME=/root USER=root DOTNET_CLI_HOME=/usr/share/dotnet DOTNET_ROOT=/usr/share/dotnet DOTNET_HOME=/usr/share/dotnet
     cd $HOME
     script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash

     echo "PROCESSING VM_POSTBOOT_SCRIPT"
     uptime
     source /etc/.variables
     cd "$VM_PROVISIA_FOLDER"
     bash -e -c "$VM_POSTBOOT_SCRIPT"

' > /tmp/cloud-config.txt

Say "cloud-localds verbose output"
cloud-localds -v --disk-format qcow2 "$1" /tmp/cloud-config.txt
echo DONE
# qemu-img convert -O qcow2 -c -p cloud-config.img cloud-config.qcow2
  
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

function VM-Launcher-Smoke-Test() {
  mkdir -p /tmp/cloud-init-smoke-test-provisia
  git clone https://github.com/devizer/Universe.CpuUsage /tmp/cloud-init-smoke-test-provisia
  VM_SSH_PORT=2345
  VM_CPUS=2
  VM_MEM=2048M
  HOST_PROVISIA_FOLDER=/tmp/cloud-init-smoke-test-provisia
  VM_PROVISIA_FOLDER=/root/provisia
  VM_USER_NAME=user
  VM_PREBOOT_SCRIPT='echo IM CUSTOM PRE-BOOT'
  VM_POSTBOOT_SCRIPT='echo IM CUSTOM POST-BOOT. FOLDER IS $(pwd). CONTENT IS BELOW; ls -lah'
  VM_POSTBOOT_ROLE='root'
  VM_OUTCOME_FOLDER='/root'
  Build-Cloud-Config "/tmp/cloud-config.qcow2"
  ls -la "/tmp/cloud-config.qcow2"
  Say "THEARCH: $THEARCH"
  Launch-VM $THEARCH "/tmp/cloud-config.qcow2" /transient-builds/run
  sleep 1300
}
