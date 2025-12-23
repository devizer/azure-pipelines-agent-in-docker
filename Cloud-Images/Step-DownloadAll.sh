set -eu; set -o pipefail
Say --Reset-Stopwatch
bash Download-CloudImage.sh --show-images

images='
arm64-debian-10
arm64-debian-11
arm64-debian-12
arm64-debian-13
arm64-ubuntu-14.04
arm64-ubuntu-16.04
arm64-ubuntu-18.04
arm64-ubuntu-20.04
arm64-ubuntu-22.04
arm64-ubuntu-24.04
armel-debian-8
armel-debian-9
armel-debian-10
armel-debian-11
armhf-debian-8
armhf-debian-9
armhf-debian-10
armhf-debian-11
armhf-debian-12
armhf-ubuntu-14.04
armhf-ubuntu-16.04
armhf-ubuntu-18.04
armhf-ubuntu-20.04
armhf-ubuntu-22.04
armhf-ubuntu-24.04
i386-debian-10
i386-debian-11
i386-debian-12
x64-debian-10
x64-debian-11
x64-debian-12
x64-debian-13
x64-ubuntu-22.04
x64-ubuntu-24.04
'

sudo chown -R $USER "$THEWORKDIR"
n=0
for image in $images; do
  n=$((n+1))
  Say "${n}) Downloading and extracting Cloud Image [$image]"
  toFolder="$THEWORKDIR/$image"
  # No Any Root
  time bash Download-CloudImage.sh "$image" "$toFolder"
done

Say "COMPLETED"

sz1="$(sudo du -h -d 0 "$THEWORKDIR" | awk '{print $1}')"
Say "Size of ${THEWORKDIR}: $sz1"
command -v compsize && sudo compsize "${THEWORKDIR}"
df -h -T || df -h
