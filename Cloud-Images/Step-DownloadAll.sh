set -eu; set -o pipefail
Say --Reset-Stopwatch

images='
  armhf-ubuntu-14.04   armhf-ubuntu-16.04   armhf-ubuntu-18.04   armhf-ubuntu-20.04  
  armhf-ubuntu-22.04   armhf-ubuntu-23.10   armhf-ubuntu-24.04                       
  arm64-ubuntu-14.04   arm64-ubuntu-16.04   arm64-ubuntu-18.04   arm64-ubuntu-20.04  
  arm64-ubuntu-22.04   arm64-ubuntu-23.10   arm64-ubuntu-24.04                       
  armhf-debian-8       armhf-debian-9       armhf-debian-10      armhf-debian-11     
  armhf-debian-12
  arm64-debian-10      arm64-debian-11      arm64-debian-12      arm64-debian-13
'
for image in $images; do
  Say "Downloading and extracting Cloud Image [$image]"
  toFolder="$THEWORKDIR/$image"
  bash Download-CloudImage.sh "$image" "$toFolder"
done

Say "COMPLETED"

df -h -T
