#!/usr/bin/env bash

Say "Installing armhf packages on aarch64 OS"
#Enable installation of armhf packages
sudo dpkg --add-architecture armhf; 
#Install the ARM32 gcc toolchain
sudo apt update -q;
sudo apt-get install gcc-arm-linux-gnueabihf -y;

#Symlink the armhf ld kernel module (this allows loading ARM32 bins on ARM64 OS and comes with the ARM32 toolchain)
#OR For a persistent version of the above
#Symlink the relevant kernel modules
sudo ln -s /usr/arm-linux-gnueabihf/lib/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3 || true
sudo ln -s /usr/arm-linux-gnueabihf/lib/libdl.so.2 /lib/libdl.so.2
sudo ln -s /usr/arm-linux-gnueabihf/lib/libpthread.so /lib/libpthread.so
sudo ln -s /usr/arm-linux-gnueabihf/lib/libpthread.so.0 /lib/libpthread.so.0
sudo ln -s /usr/arm-linux-gnueabihf/lib/libstdc++.so.6 /lib/libstdc++.so.6
sudo ln -s /usr/arm-linux-gnueabihf/lib/libm.so.6 /lib/libm.so.6
sudo ln -s /usr/arm-linux-gnueabihf/lib/libgcc_s.so.1 /lib/libgcc_s.so.1
sudo ln -s /usr/arm-linux-gnueabihf/lib/libc.so.6 /lib/libc.so.6
sudo ln -s /usr/arm-linux-gnueabihf/lib/librt.so.1 /lib/librt.so.1

# Install armhf version of libcurl and libicu. No, skipping
# Buster
# sudo apt-get install -y libcurl4-openssl-dev:armhf libicu63:armhf
# Bionic
# sudo apt-get install -y libcurl4-openssl-dev:armhf libicu60:armhf

libicu=$(apt-cache search libicu | grep -E '^libicu[0-9]* ' | awk '{print $1}')
echo LIBICU: $libicu
for p in zlib1g libicu55 $libicu liblttng-ust0 liburcu4 libkrb5-3 curl libcurl3 ; do
  Say "Installing agent dependency '$p'"
  sudo apt-get install -y -q ${p}:armhf ${p} || true
done
