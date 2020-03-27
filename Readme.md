### azure-pipeline-agent-in-docker
Azure pipelines agent in docker for armv7, arm64, and x86_64

### Key features
- Preconfigured SystemD. Intended for background services testing. 
- Azure pipelines agent configured as SystemD service. Self-update is fully supported.
- Pre-installed latest docker-compose and docker client with experimental features such as buildx.
- Preconfigured `en_US.UTF8` as LC_ALL and LANG.
- Pre-installed latest .Net core, Mono, Node, NUnit & xUnit test runners, git, etc.
- Supported 3 architectures: armv7 (native), arm64 (arm32 binaries with armhf dependencies) and x86_64 (native).
  
### Create container and Configure azure pipelines agent
```
# Create container and make it start on boot
docker run -d --restart on-failure --privileged \
 --name agent007 \
 --hostname agent007 \
 -v /sys/fs/cgroup:/sys/fs/cgroup \
 -v /var/run/docker.sock:/var/run/docker.sock \
 devizervlad/crossplatform-azure-pipelines-agent:latest

# Configure azure pipelines agent 
HOST_DOCKER_GROUP_ID=$(getent group docker | awk -F: '{printf $3}')
docker exec -it agent007 bash -c '
 export HOST_DOCKER_GROUP_ID='$HOST_DOCKER_GROUP_ID';
 export VSTS_URL="https://devizer.visualstudio.com/";
 export VSTS_PAT=<your agent pool token>;
 export VSTS_POOL=my-pool;
 export VSTS_AGENT=my-agent-007; 
 export VSTS_WORK=work;
 /pre-configure/config-agent.sh'
```

### Troubleshooting
```
systemctl status azure-pipelines-agent
journalctl -u azure-pipelines-agent
cat /home/user/azure-pipelines-agent/_diag/*.log
```