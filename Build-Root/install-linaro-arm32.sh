Say "Installing arm32 linaro toolchain to /opt/linaro-arm/bin"

sudo mkdir -p /opt/linaro-arm
pushd /opt/linaro-arm

# armv5
export CROZ_PREFIX=arm-none-eabi-
url="https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-arm-none-eabi.tar.xz?rev=325890dc39394ec49a112e5a661f6497&hash=2BF5AF893AEBA55524D3E0F6A010ACE8"

export CROZ_PREFIX=arm-none-linux-gnueabihf-
url="https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf.tar.xz?rev=302e8e98351048d18b6f5b45d472f406&hash=95ED9EEB24EAEEA5C1B11BBA864519B2"

echo "URL IS $url"
Say "CROZ_PREFIX: [$CROZ_PREFIX]"
try-and-retry sudo curl -ksfSL -o gcc.tar.xz "$url"
sudo tar xJf gcc.tar.xz
sudo rm -f gcc.tar.xz
cd gcc*
sudo mv * ..
ls -lh /opt/linaro-arm/bin
export PATH="/opt/linaro-arm/bin:$PATH"
${CROZ_PREFIX}gcc --version
popd
