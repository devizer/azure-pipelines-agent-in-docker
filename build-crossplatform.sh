#!/usr/bin/env bash
# work=$HOME/build/azure-pipeline-agent-in-docker; mkdir -p $(dirname $work); cd $(dirname $work); git clone https://github.com/devizer/azure-pipeline-agent-in-docker || true; cd azure-pipeline-agent-in-docker; git pull; time bash build-crossplatform.sh
set -e

docker image rm -f devizervlad/crossplatform-azure-pipelines-agent:latest || true
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
sudo apt-get install qemu-user-static -y

docker buildx inspect --bootstrap
docker buildx ls

# build nunit and xunit test runners
set -e
export XFW_VER=net47 NET_TEST_RUNNERS_INSTALL_DIR=/opt/net-test-runners; 
export XFW_VER=net47 NET_TEST_RUNNERS_INSTALL_DIR=$(pwd)/cross-platform/bin/opt/net-test-runners;
script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/NET-TEST-RUNNERS-build.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | sudo -E bash -e
set +e

# docker image rm -f $(docker image ls -aq)
export OS=Linux
export TAGS="-t devizervlad/crossplatform-azure-pipelines-agent:xenial"
export TAG=xenial
export BASE_IMAGE='ubuntu:xenial'
platform="linux/amd64"
platform="linux/amd64,linux/arm64"
platform="linux/amd64,linux/arm64,linux/arm/v7"
# revert to --push
cd cross-platform
time docker buildx build \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg BUILD_URL="${BUILD_URL}" \
  --build-arg JOB_URL="${JOB_URL}" \
  --build-arg BUILD_SOURCEVERSION="${BUILD_SOURCEVERSION}" \
  --build-arg BUILD_SOURCEBRANCHNAME="${BUILD_SOURCEBRANCHNAME}" \
  --build-arg BUILD_BUILDID="${BUILD_BUILDID}" \
  --platform $platform --load \
  ${TAGS} .

Say "Built with --load only"

# docker run --restart on-failure --name agent007 --privileged --hostname agent007 -it devizervlad/azpa:latest 
