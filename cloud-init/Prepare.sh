set -eu; set -o pipefail;

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
  if [[ "$url" == *".xz" ]]; then echo "Extracting $file.xz"; mv $file $file.xz; cat $file.xz | time xz -d > $file; rm -f $file.xz; fi
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
    sudo guestmount -a $file -m $boot $key-MNT
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

  Say "Resizing image up to $size"
  qemu-img create -f qcow2 disk.intermediate.compacting.qcow2 $size
  sudo virt-resize --expand /dev/sda1 $file disk.intermediate.compacting.qcow2
  # qemu-img convert -O qcow2 disk.intermediate.compacting.qcow2 $key.qcow2
  mv disk.intermediate.compacting.qcow2 $key.qcow2 # faster!
  rm -f disk.intermediate.compacting.qcow2
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

sudo rm -rf /trusty/* /ubuntu24/*
Say --Reset-Stopwatch
Prepare-VM-Image "https://cloud-images.ubuntu.com/daily/server/noble/current/noble-server-cloudimg-armhf.img" /ubuntu24 9G
# Prepare-VM-Image "https://cloud-images.ubuntu.com/releases/trusty/release/ubuntu-14.04-server-cloudimg-arm64-disk1.img" /trusty 13G
