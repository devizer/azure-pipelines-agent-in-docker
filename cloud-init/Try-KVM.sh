# https://phoenixnap.com/kb/ubuntu-install-kvm

codename=${1:-bookworm}
arch=x86_64

set -eu
  sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils -y
  sudo systemctl status libvirtd
  sudo adduser $USER libvirt
  sudo adduser $USER kvm
  Say "Validate KVM"
  sudo kvm-ok
set +eu

links_bookworm='
https://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz
https://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
https://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/mini.iso'


# LETS ROCK
Say "Creating cloud image for debian [$codename]"
set_title "[$codename] cloud image"
links=$(eval "echo \$links_$codename")
work=/transient-builds/debian-$codename-$arch
sudo mkdir -p $work
sudo chown -R $USER $work
cd $work

for link in $links; do
  file=$(basename $link)
  try-and-retry curl -kfSL -o $file $link
done

cp -f linux vmlinuz 2>/dev/null

preseed=$(pwd)/preseed.cfg
Say "Preseed.cfg into $(pwd)/initrd.gz"
gunzip -f initrd.gz
oldpwd="$(pwd)"
pushd "$(dirname $preseed)"
echo preseed.cfg | cpio -H newc -o -A -F $oldpwd/initrd
popd
gzip initrd
mkdir -p final-initrd; pushd final-initrd; rm -rf *
zcat ../initrd.gz | cpio -idm
popd


qemu-img create -f qcow2 disk.qcow2 16G
sudo qemu-system-x86_64 -name $codename-${arch} -M q35 -enable-kvm \
    -kernel ./vmlinuz -initrd ./initrd.gz \
    -hda disk.qcow2 -cdrom mini.iso \
  -nographic -m 1400M -smp 2 -append "console=ttyS0" \
  -no-reboot
