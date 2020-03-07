# work=$HOME/build/azure-pipeline-agent-in-docker; mkdir -p $(dirname $work); cd $(dirname $work); git clone https://github.com/devizer/azure-pipeline-agent-in-docker || true; cd azure-pipeline-agent-in-docker; git pull; time bash test.sh

docker image rm devizervlad/azpa
cd armv7
docker build -t devizervlad/azpa:1 .

