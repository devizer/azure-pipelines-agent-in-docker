set -eu; set -o pipefail
cp -v -f ../cloud-init/VM-Manager.sh ./Docker-Image-Builder/Install/
chmod +x ./Docker-Image-Builder/Install/*.sh
cd Docker-Image-Builder 
export BASE_IMAGE="${BASE_IMAGE:-ubuntu:24.04}"
export QEMU_IMAGE_ID="${QEMU_IMAGE_ID:-armel-debian-8}"
time docker build \
  --progress plain \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg QEMU_IMAGE_ID="${QEMU_IMAGE_ID}" \
  -t devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} . 

Say "Crossplatform Pipeline Images"
docker image ls | grep "devizervlad/crossplatform-pipeline"

docker run -it devizervlad/crossplatform-pipeline:${QEMU_IMAGE_ID} bash -c "uname -a; free -m; df -h -T"

