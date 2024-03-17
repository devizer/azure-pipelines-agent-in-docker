Say "Installing arm32 linaro toolchain to /opt/linaro-arm/bin"
pushd /opt
sudo mkdir -p /opt/linaro-arm
url=""https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-arm-none-eabi.tar.xz?rev=325890dc39394ec49a112e5a661f6497&hash=2BF5AF893AEBA55524D3E0F6A010ACE8""
echo "URL IS $url"
try-and-retry sudo curl -ksfSL -o gcc.tar.xz "$url"
sudo tar xJf gcc.tar.xz
sudo rm -f gcc.tar.xz
cd gcc*
sudo mv * ..
ls -lh /opt/linaro-arm/bin
export PATH="/opt/linaro-arm/bin:$PATH"
arm-none-eabi-gcc --version
popd
