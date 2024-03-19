set -eu; set -o pipefail

source install-linaro-arm32.sh 
function Short-Apt() { grep "Unpack\|Setting" || true; }
Say "Apt install"
sudo apt-get update -qq
sudo apt-get install bc build-essential gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi git unzip libncurses5-dev bison flex libssl-dev | Short-Apt

for p in libmpc-dev libmpc3; do
  sudo apt-get install -y -qq $p | Short-Apt
done

echo '
https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.310.tar.xz
https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.272.tar.xz
https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.213.tar.xz

https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.1.tar.xz
https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.22.tar.xz
https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.82.tar.xz
https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.152.tar.xz
' >/dev/null

work=$HOME/build/kernel
mkdir -p $work
pushd $work
KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.22.tar.xz}"
Say "Download Kernel"
echo "URL IS $KERNEL_URL"
time try-and-retry curl -ksfSL -o kernel.tar.xz "$KERNEL_URL"
time tar xJf kernel.tar.xz
cd linux*

nohup bash Anti-Freeze.sh &

target=$HOME/kernel-outcome
mkdir -p "$target"
Say "TARGET FOLDER: [$target]"
flags="-mcpu=armv4t -march=armv4t -mlittle-endian"
flags=""
# https://vccolombo.github.io/cybersecurity/linux-kernel-qemu-setup/
     Say "defconfig"
     make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target versatile_defconfig # defconfig
     Say "kvmconfig or kvm_guest.config"
     make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target kvmconfig || make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target kvm_guest.config


# ./scripts/config --file $target/.config --set-val CONFIG_ARCH_MULTI_V5 y 
./scripts/config --file $target/.config --set-val CONFIG_HAVE_PCI y
./scripts/config --file $target/.config --set-val CONFIG_PCI y
./scripts/config --file $target/.config --set-val CONFIG_VIRTIO_PCI y
./scripts/config --file $target/.config --set-val CONFIG_PCI_HOST_GENERIC y

sed -i 's/=m$/=y/g'  $target/.config

     make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target olddefconfig


Say "make all"
make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=0 all |& tee $target/my.all.log

# -Wall -Wundef -Werror=strict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -fshort-wchar -fno-PIE -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Wno-format-security -std=gnu11 -fno-dwarf2-cfi-asm -mno-fdpic -fno-ipa-sra -mabi=aapcs-linux -mfpu=vfp -funwind-tables -marm -Wa,-mno-warn-deprecated -D__LINUX_ARM_ARCH__=5 -march=armv5te -mtune=arm9tdmi -msoft-float -Uarm -fno-delete-null-pointer-checks -Wno-frame-address -Wno-format-truncation -Wno-format-overflow -Wno-address-of-packed-member -O2 -fno-allow-store-data-races -Wframe-larger-than=1024 -fstack-protector-strong -Wno-main -Wno-unused-but-set-variable -Wno-unused-const-variable -fomit-frame-pointer -fno-stack-clash-protection -Wvla -Wno-pointer-sign -Wcast-function-type -Wno-stringop-truncation -Wno-stringop-overflow -Wno-restrict -Wno-maybe-uninitialized -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -fno-strict-overflow -fno-stack-check -fconserve-stack -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wno-packed-not-aligned
Say "make bzImage"
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=0 bzImage |& tee $target/my.bzImage.log || Say --Display-As=Error "Can't make bzImage. It's ok"

Say "make vmlinux"
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=0 vmlinux |& tee $target/my.vmlinux.log || Say --Display-As=Error "Can't make vmlinux. It's ok"
popd
