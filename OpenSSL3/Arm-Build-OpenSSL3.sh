# work=$HOME/build/openssl3; mkdir -p $work; cd $work; git clone https://github.com:/devizer/azure-pipelines-agent-in-docker; cd azure-pipelines-agent-in-docker; git pull; time bash OpenSSL3/Arm-Build-OpenSSL3.sh
# export SYSTEM_ARTIFACTSDIRECTORY="/OpenSSL3/Current/System"; bash -eu -o pipefail OpenSSL3/Benchmark-Builtin-OpenSSL.sh
set -eu; set -o pipefail
Arm-Build-OpenSSL3() {
  export SSL_VERSION="$1"
  export IMAGE="$2"
  tag=$(echo "$IMAGE" | awk -F":" '{print $2}')
  export ARTIFACT_NAME="$SSL_VERSION on $tag"
  export SYSTEM_ARTIFACTSDIRECTORY="/OpenSSL3/Current/OpenSSL3-$SSL_VERSION-$tag"
  mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"
  Say "STORE TO [$SYSTEM_ARTIFACTSDIRECTORY]"
  bash -eu OpenSSL3/STEP-Run-Container.sh
}


index=0;
for ssl_version in "3.5.5" "3.0.19" "3.3.6" "3.4.4" "3.6.1"; do
images_debian="multiarch/debian-debootstrap:arm64-jessie multiarch/debian-debootstrap:armhf-jessie"
images_alpine="multiarch/alpine:armhf-v3.7 multiarch/alpine:aarch64-v3.7"
images="$images_alpine $images_debian"
for image in $images; do
  index=$((index+1))
  title="[$index of 10] Building $ssl_version on $image"
  printf "\033]0;%s\007" "$title"
  Say "$title"
  time Arm-Build-OpenSSL3 $ssl_version "$image"
done 
done

# Arm-Build-OpenSSL3 3.6.1 multiarch/debian-debootstrap:arm64-jessie
