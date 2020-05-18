#!/usr/bin/env bash
set -e
Say "Content /proc/sys/fs/binfmt_misc/qemu-arm"
cat /proc/sys/fs/binfmt_misc/qemu-arm
Say "Content /proc/sys/fs/binfmt_misc/qemu-aarch64"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

Say "Turning on apt sources"
sudo sed -i 's/# deb-src /deb-src  /g' /etc/apt/sources.list
Say "Tuned /etc/apt/sources.list"
cat -n /etc/apt/sources.list
Say "apt-get update"
sudo apt-get update

Say "Installing qemu build dependencies"
sudo apt-get build-dep qemu -y

QEMU_VER=5.0.0 # 5.0.0 | 4.2.0 | 4.1.1
Say "Building qemu ${QEMU_VER}"
work=$HOME/build/qemu-user-static-src
mkdir -p $work
pushd $work
rm -rf *
url=https://download.qemu.org/qemu-${QEMU_VER}.tar.bz2
file=$(basename $url)
wget --no-check-certificate -O _$file $url || curl -ksSL -o _$file $url
tar xjf _$file
rm _$file
cd qemu*
# git clone git://git.qemu.org/qemu.git
# cd qemu
# git submodule update --init --recursive
# --prefix=$(cd ..; pwd)/qemu-user-static \
#    --static \
#
    # --target-list=arm-linux-user,aarch64-linux-user \

prefix=/usr/local/qemu-${QEMU_VER}
./configure --target-list=arm-linux-user,aarch64-linux-user \
    --prefix=${prefix} \
    --disable-system \
    --disable-avx2 \
    --disable-gtk \
    --static \
    --enable-linux-user

time make -j8
sudo make install
sudo ln -s -f $prefix/bin/qemu-arm /usr/bin/qemu-arm-static
sudo ln -s -f $prefix/bin/qemu-aarch64 /usr/bin/qemu-aarch64-static

popd
rm -rf $work

Say "qemu-arm-static: $(qemu-arm-static --version | head -1)"
Say "qemu-aarch64-static: $(qemu-aarch64-static --version | head -1)"

