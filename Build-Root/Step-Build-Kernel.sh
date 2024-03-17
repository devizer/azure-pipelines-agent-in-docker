set -eu; set -o pipefail
nohup bash Anti-Freeze.sh &

source install-linaro-arm32.sh 
Say "Apt install"
sudo apt-get update -qq
sudo apt-get install bc build-essential gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi git unzip libncurses5-dev bison flex libssl-dev | grep "Setting\|Unpack"

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
KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.310.tar.xz}"
Say "Download Kernel"
echo "URL IS $KERNEL_URL"
time try-and-retry curl -ksfSL -o kernel.tar.xz "$KERNEL_URL"
time tar xJf kernel.tar.xz
cd linux*

target=$HOME/kernel-outcome
mkdir -p "$target"
Say "TARGET FOLDER: [$target]"
flags="-mcpu=armv4t -march=armv4t -mlittle-endian"
flags=""
     make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target versatile_defconfig

Say "make all"
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=1 all |& tee $target/my.log

Say "make bzImage"
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=1 bzImage |& tee $target/bzImage.log || Say --Display-As=Error "Can't make bzImage. It's ok"

Say "make vmlinux"
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=${CROZ_PREFIX} O=$target -j1 V=1 vmlinux |& tee $target/bzImage.log || Say --Display-As=Error "Can't make vmlinux. It's ok"
