#!/usr/bin/env bash
# work=$HOME/build/azure-pipeline-agent-in-docker; mkdir -p $(dirname $work); cd $(dirname $work); git clone https://github.com/devizer/azure-pipeline-agent-in-docker || true; cd azure-pipeline-agent-in-docker; git pull; time bash test.sh

docker image rm devizervlad/azpa
cd armv7
time docker build --build-arg VSTS_URL --build-arg VSTS_POOL --build-arg VSTS_AGENT --build-arg VSTS_PAT --build-arg VSTS_WORK -t devizervlad/azpa:1 .
docker run --rm -t devizervlad/azpa:1 

