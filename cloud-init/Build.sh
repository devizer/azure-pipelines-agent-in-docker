set -ue; set -o pipefail
mkdir -p $SYSTEM_ARTIFACTSDIRECTORY/logs
work=$HOME/build-cloud-init
work=/transient-builds
sudo mkdir -p $work; sudo chown -R $USER $work; cd $work
remotefile="$(basename "$IMAGEURL")"
file=$KEY.img
key=$KEY
Say "Downloading raw image $KEY"
echo "URL is $IMAGEURL"
try-and-retry curl --compressed -ksfSL -o $file "$IMAGEURL" || rm -f $file
ls -lah $file
Say "Extracting kernel from /dev/sda1,2"
mkdir -p $key-MNT $key-BOOTALL $key-BOOT $key-LOGS
sudo virt-filesystems --all --long --uuid -h -a $file | sudo tee $key-LOGS/$key-filesystems.log | tee file-systems.txt
# http://ask.xmodulo.com/mount-qcow2-disk-image-linux.html
sudo guestunmount $key-MNT >/dev/null 2>&1 || true
set +e 
for boot in $(cat file-systems.txt | awk '$1 ~ /dev/ && $1 !~ /sda$/ {print $1}' | sort -u); do
  # export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
  echo ""; Say "TRY BOOT VOLUME $boot"
  sudo guestmount -a $file -m $boot $key-MNT
  sudo ls -la $key-MNT/boot |& tee $SYSTEM_ARTIFACTSDIRECTORY/logs/$key-$(basename $boot)-boot.files.txt
  sudo cp -f -r $key-MNT/boot/* $key-BOOTALL
  # sudo cp -f -L $key-MNT/boot/{initrd.img,vmlinu?} $key-BOOT
  sudo bash -c "cp -f -L $key-MNT/boot/{initrd.img,vmlinu?} $key-BOOT"
  sudo bash -c "cp -f -L $key-MNT/{initrd.img,vmlinu?} $key-BOOT"
  sudo guestunmount $key-MNT
  mv $key-BOOT/vmlinux $key-BOOT/vmlinuz 2>/dev/null
  sudo chown -R $USER $key-BOOT
  if [[ -s $key-BOOT/initrd.img ]] && [[ -s $key-BOOT/vmlinuz ]]; then break; fi
done
set -e
Say "Content of $key-BOOT"
pushd $key-BOOT >/dev/null
ls -lah *
echo "Compressed Content of $key-BOOT"
sudo xz -z -3 *
ls -lah *
popd >/dev/null
sudo chown -R $USER $key-BOOT

Say "Resizing image"
qemu-img create -f qcow2 disk.intermediate.compacting.qcow2 15G
sudo virt-resize --expand /dev/sda1 $file disk.intermediate.compacting.qcow2
qemu-img convert -O qcow2 disk.intermediate.compacting.qcow2 $key.qcow2
rm -f disk.intermediate.compacting.qcow2
sudo virt-filesystems --all --long --uuid -h -a $key.qcow2 | sudo tee $key-LOGS/$key-filesystems.resized.log | tee filesystems.resized.log
root_partition_index=$(cat filesystems.resized.log | awk '$4 ~ /cloudimg-rootfs/ {print $1}' | sed 's/\/dev\/sda//' | sort -u)
printf $root_partition_index > $SYSTEM_ARTIFACTSDIRECTORY/$key.root.partition.index.txt
echo "QCOW2 Size ($key.qcow2)"
ls -lah $key.qcow2
Say "Compressing ($key.qcow2)"
echo "CPU: $(Get-CpuName)"
# cat $key.qcow2 | xz -z -9 -e > $SYSTEM_ARTIFACTSDIRECTORY/$key.qcow2.xz
time 7z a -txz -mx=9 -mmt=$(nproc) $SYSTEM_ARTIFACTSDIRECTORY/$key.qcow2.xz $key.qcow2

ls -lah $SYSTEM_ARTIFACTSDIRECTORY/$key.qcow2.xz

sudo cp -a $key-BOOT/. $SYSTEM_ARTIFACTSDIRECTORY
sudo cp -a $key-BOOTALL $SYSTEM_ARTIFACTSDIRECTORY
sudo cp -a $key-LOGS $SYSTEM_ARTIFACTSDIRECTORY
sudo chown -R $USER $SYSTEM_ARTIFACTSDIRECTORY

Say "Complete ($key.qcow2)"

rundir=/transient-builds/run
sudo mkdir -p $rundir; sudo chown -R $USER $rundir; 
pushd $rundir
cat $SYSTEM_ARTIFACTSDIRECTORY/$key.qcow2.xz | xz -d > disk.qcow2
cat $key-BOOT/initrd.img.xz | xz -d > initrd.img
cat $key-BOOT/vmlinuz.xz | xz -d > vmlinuz.img
ls -lah 
popd
