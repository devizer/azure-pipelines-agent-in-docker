# https://github.com/nmilosev/termux-fedora/blob/master/termux-fedora.sh
# image="debian:8"
# image="multiarch/debian-debootstrap:arm64-jessie"
# image="arm64v8/debian:8"
# KEY=rootfs-debian-8-arm64
# [[ "$(command -v jq)" == "" ]] && apt-get install jq -y
set -e; set -u; set -o pipefail

SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"
export LC_ALL=en_US.utf8

sudo apt-get install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash > /dev/null
Say --Reset-Stopwatch
smart-apt-install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null

Say "Registering binary formats for qemu-user-static"
docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
# docker buildx imagetools inspect --raw "$image" | jq

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done


src=$(pwd)
work=/transient-builds/temp-armv6
mkdir -p $work
rm -rf $work/*
cd $work
cp $src/Raspbian-Images/Dockerfile .
Say "Downloading [$IMAGE_URL]"
file="$(basename "$IMAGE_URL")"
try-and-retry curl -kSL -o "$file" "$IMAGE_URL"
Say "Extracting [$file]"
7z x -y "$file"
ls -lah
rm -f "$file"
imgfile="$(ls -1 *.img)"
Say "Image file: [$imgfile]"
fdisk -l "$imgfile" | tee /tmp/partitions
offset=$(cat /tmp/partitions | awk 'END{print $2}')
Say "Offset: [$offset]"

Say "Mounting [$imgfile]"
mkdir -p /mnt/arm-image
mount -o loop,offset=$((offset*512)) "$imgfile" /mnt/arm-image
ls -la /mnt/arm-image
Say "Extracting [$imgfile]"
mkdir -p files
time cp -av /mnt/arm-image/. ./files/. > $SYSTEM_ARTIFACTSDIRECTORY/copy-files.log

Say "Unmounting ..."
umount /mnt/arm-image
rm -f "$imgfile"
du -h --max-depth 2

Say "Tuning 1: add qemu-arm-static"
cp /usr/bin/qemu-arm-static ./files/usr/bin/qemu-arm-static

Say "Tuning 2: add build tools bundle"
export TARGET_DIR=./files/usr/bin
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash >/dev/null
cp -v /tmp/build-gcc-utilities.sh files/tmp/.

Say "Tuning 3: apt sources validation"
cat files/etc/os-release
echo '
Acquire::AllowReleaseInfoChange::Suite "true";
Acquire::Check-Valid-Until "0";
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "1";
Acquire::AllowDowngradeToInsecureRepositories "1";
' | tee ./files/etc/apt/apt.conf.d/98_Z_Custom

Say "Tuning 4: store existing apt sources"
pushd files/etc/apt >/dev/null
tar czf $SYSTEM_ARTIFACTSDIRECTORY/apt-sources.tgz .
for f in $(find . -name '*.list'); do
  echo "# $f"
  cat $f
  echo ""
done | tee $SYSTEM_ARTIFACTSDIRECTORY/apt-sources.txt
popd >/dev/null


Say "Building docker image"
cmd="docker build $TAGS ."
echo "$cmd"
time eval "$cmd"

Say "Done"
docker image ls | grep devizervlad
