### azure-pipeline-agent-in-docker
azure pipeline agent in docker for armv7, arm64 and x86_64

### Key features
- Preconfigured SystemD for background services testing 
- Preinstalled Docker
- Preinstalled latest .net core, mono, node, nunit & xunit test runners, etc
- Supported 3 architectures: armv7 (native), arm64 and x86_64 (native)
  
### create container and configure azure pipeline agent
```
docker run -d --restart on-failure --privileged \
 --name agent007 \ 
 --hostname agent007 \
 -v /sys/fs/cgroup:/sys/fs/cgroup \
 -v /var/run/docker.sock:/var/run/docker.sock \ 
 devizervlad/devizervlad/crossplatform-azure-pipeline-agent:latest

docker exec -it agent007 '
 export VSTS_URL="https://devizer.visualstudio.com/";
 export VSTS_PAT=<your agent pool token>;
 export VSTS_POOL=armv7-pool;
 export VSTS_AGENT=armv7-agent; 
 export VSTS_WORK=work;
 /pre-configure/config-agent.sh'
```
