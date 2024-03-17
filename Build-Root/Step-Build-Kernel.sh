set -eu; set -o pipefail
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
Say "TARGET FOLDER: [$target]"
flags="-mcpu=armv4t -march=armv4t -mlittle-endian"
     make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=arm-none-eabi- O=$target versatile_defconfig
time make CFLAGS="$flags" CPPFLAGS="$flags" CXXFLAGS="$flags" ARCH=arm CROSS_COMPILE=arm-none-eabi- O=$target -j V=1 |& tee my.log

