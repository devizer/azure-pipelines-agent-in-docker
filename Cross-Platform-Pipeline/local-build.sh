set -eu; set -o pipefail
cp -v -f ../cloud-init/VM-Manager.sh ./Docker-Image-Builder/Install/
chmod +x ./Docker-Image-Builder/Install/*.sh
cd Docker-Image-Builder 
export BASE_IMAGE="${BASE_IMAGE:-ubuntu:22.04}"
export QEMU_IMAGE_ID="${QEMU_IMAGE_ID:-armhf-debian-12}"
docker rm -f qemu-vm-container 2>/dev/null || true
docker rm -f qemu-vm-host 2>/dev/null || true
docker rmi -f devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} 2>/dev/null || true
time docker build \
  --progress plain \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg QEMU_IMAGE_ID="${QEMU_IMAGE_ID}" \
  -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} . 

Say "Crossplatform Pipeline Images"
docker image ls | grep "devizervlad/crossplatform-pipeline"

Say "Smoketest of newly created image for [$QEMU_IMAGE_ID]"
# https://stackoverflow.com/a/49021109 (fuse in container)
docker run --privileged --name qemu-vm-container --hostname qemu-vm-container --device /dev/fuse --cap-add SYS_ADMIN --security-opt apparmor:unconfined -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} bash -c "uname -a; Say \"FOLDER IS [\$(pwd)]\"; free -m; df -h -T; uname -a"
