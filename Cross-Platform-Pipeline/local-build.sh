cd Docker-Image-Builder 
export BASE_IMAGE="${BASE_IMAGE:-ubuntu:24.04}"
export QEMU_IMAGE_ID="${QEMU_IMAGE_ID:-arm64-debian-10}"
time docker build \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg QEMU_IMAGE_ID="${QEMU_IMAGE_ID}" \
  -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} . 

Say "Crossplatform Pipeline Images"
docker image ls | grep "devizervlad/crossplatform-pipeline"
