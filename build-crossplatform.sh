#!/usr/bin/env bash
# work=$HOME/build/azure-pipeline-agent-in-docker; mkdir -p $(dirname $work); cd $(dirname $work); git clone https://github.com/devizer/azure-pipeline-agent-in-docker || true; cd azure-pipeline-agent-in-docker; git pull; time bash build-crossplatform.sh

docker image rm -f devizervlad/crossplatform-azure-pipelines-agent:latest
# docker image rm -f $(docker image ls -aq)
cd cross-platform
time docker build --build-arg BASE_IMAGE=fccal -t devizervlad/crossplatform-azure-pipelines-agent:latest .
# docker run --restart on-failure --name agent007 --privileged --hostname agent007 -it devizervlad/azpa:latest 
