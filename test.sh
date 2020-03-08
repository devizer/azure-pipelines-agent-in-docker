#!/usr/bin/env bash
# work=$HOME/build/azure-pipeline-agent-in-docker; mkdir -p $(dirname $work); cd $(dirname $work); git clone https://github.com/devizer/azure-pipeline-agent-in-docker || true; cd azure-pipeline-agent-in-docker; git pull; time bash test.sh

docker image rm -f devizervlad/azpa:latest
# docker image rm -f $(docker image ls -aq)
cd armv7
time docker build --build-arg VSTS_URL --build-arg VSTS_POOL --build-arg VSTS_AGENT --build-arg VSTS_PAT --build-arg VSTS_WORK -t devizervlad/azpa:latest .
docker run --privileged --hostname agent007 --rm -it devizervlad/azpa:latest 

