cd Docker-Image-Builder 
export BASE_IMAGE="${BASE_IMAGE:-ubuntu:20.04}"
export QEMU_IMAGE_ID="${QEMU_IMAGE_ID:-armel-debian-11}"
time docker build \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg QEMU_IMAGE_ID="${QEMU_IMAGE_ID}" \
  -t devizervlad/crossplatform-pipeline:QEMU_IMAGE_ID . 


