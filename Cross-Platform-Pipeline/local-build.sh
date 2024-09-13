set -eu; set -o pipefail
cp -v -f ../cloud-init/VM-Manager.sh ./Docker-Image-Builder/Install/
chmod +x ./Docker-Image-Builder/Install/*.sh
cd Docker-Image-Builder 
export BASE_IMAGE="${BASE_IMAGE:-ubuntu:22.04}"
export QEMU_IMAGE_ID="${QEMU_IMAGE_ID:-armhf-debian-12}"
docker rm -f qemu-vm || true
docker rm -f qemu-vm-host || true
docker rmi -f devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} || true
time docker build \
  --progress plain \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg QEMU_IMAGE_ID="${QEMU_IMAGE_ID}" \
  -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} . 

Say "Crossplatform Pipeline Images"
docker image ls | grep "devizervlad/crossplatform-pipeline"

# https://stackoverflow.com/a/49021109 (fuse in container)
docker run --privileged --name qemu-vm-host --hostname qemu-vm-host --device /dev/fuse --cap-add SYS_ADMIN --security-opt apparmor:unconfined -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} bash -c "uname -a; Say \"FOLDER IS [\$(pwd)]\"; free -m; df -h -T; uname -a"

