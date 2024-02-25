set -ue; set -o pipefail
work=$HOME/build-cloud-init
mkdir -p $work; cd $work
remotefile=$(basename $URL)
file=$KEY.img
key=$KEY
try-and-retry curl -ksfSL -o $file "$IMAGEURL" || rm -f $file
mkdir -p $key-MNT $key-BOOTALL $key-BOOT $key-LOGS
sudo virt-filesystems --all --long --uuid -h -a $file | sudo tee $key-LOGS/$key-filesystems.log
# http://ask.xmodulo.com/mount-qcow2-disk-image-linux.html
sudo guestunmount $key-MNT >/dev/null 2>&1 || true
set +e 
for boot in sda1 sda2 sda3 sda4; do
  echo "TRY BOOT VOLUME $boot"
  sudo guestmount -a $file -m /dev/sda1 $key-MNT
  cp -f -r $key-MNT/boot/* $key-BOOTALL
  cp -f -L $key-MNT/boot/{initrd.img,vmlinu?} $key-BOOT
  sudo guestunmount $key-MNT
  mv $key-BOOT/vmlinux $key-BOOT/vmlinuz 2>/dev/null
done
set -e
Say "Content of $key-BOOT"
ls -la $key-BOOT

Say "Resizing image"
qemu-img create -f qcow2 disk.intermediate.compacting.qcow2 15G
sudo virt-resize --expand /dev/sda1 $file disk.intermediate.compacting.qcow2
qemu-img convert -O qcow2 -c -p disk.intermediate.compacting.qcow2 $key.qcow2
rm -f disk.intermediate.compacting.qcow2
sudo virt-filesystems --all --long --uuid -h -a $key.qcow2 | sudo tee $key-LOGS/$key-filesystems.resized.log
echo "QCOW2 Size ($key.qcow2)"
ls -la $key.qcow2
cat $key.qcow2 | xz -z -3 > $key.qcow2.xz
ls -la $key.qcow2*

cp -a $key.qcow2* $SYSTEM_ARTIFACTSDIRECTORY
cp -a $key-BOOT $SYSTEM_ARTIFACTSDIRECTORY