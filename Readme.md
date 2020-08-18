### azure-pipeline-agent-in-docker
Azure pipelines agent in docker for _**armv7**_, _**arm64**_, and _**x86_64**_

### Key features
- Preconfigured SystemD. Intended for background services testing. 
- Azure pipelines agent configured as SystemD service. Self-update is fully supported.
- Pre-installed latest docker-compose and Docker CE client with experimental features such as buildx.
- Pre-installed latest .Net core, Mono, Node LTS, NUnit & xUnit test runners, git, etc.
- Supported 3 architectures: armv7, arm64 and x86_64.
- Preconfigured `en_US.UTF8` as LC_ALL and LANG.

| Image Tags | Base Image | SSL Ver | 
|------------|------------|---------|
|focal, **latest**| Ubuntu 20.04 LTS, Focal Fossa|1.1.1f|
|bionic |Ubuntu 18.04.5 LTS, Bionic Beaver|1.1.1|
|xenial |Ubuntu 16.04.6 LTS, Xenial Xerus|1.0.2g|
|buster|Debian 10.3, Buster|1.1.1d|
|stretch|Debian 9.12, Stretch|1.1.0l, 1.0.2u|
|jessie|Debian 8.11, Jessie|1.0.1t|

### Pre-installed software

Here is preinstalled soft for focal base image. Packages marked by asterisk are distribution independent for debian derivatives 
```
  Build date:     2020-08-18 12:05:05 UTC
  Base Image:     ubuntu:focal
* dotnet sdk:     2.1.809, 2.2.402, 3.0.103, 3.1.401
* pwsh:           PowerShell 6.2.4
* mono:           Mono JIT compiler version 6.10.0.104 (tarball Fri Jun 26 19:44:58 UTC 2020)
* msbuild:        16.6.0.32601
* nuget:          NuGet Version: 5.5.0.6382
* paket:          Paket version 5.249.2
* libgdiplus:     6.0.5-0xamarin1+ubuntu2004b1
* xunit.console:  xUnit.net Console Runner v2.4.1 (64-bit Desktop .NET 4.7.2, runtime: 4.0.30319.42000)
* nunit3-console: NUnit Console Runner 3.11.1 (.NET 2.0)
* node:           v12.18.3
* npm:            6.14.8
* yarn:           1.22.4
  openssl:        OpenSSL 1.1.1f  31 Mar 2020
  libssl:         libssl1.1
* git:            git version 2.28.0
* git lfs:        git-lfs/2.11.0 (GitHub; linux arm64; go 1.14.3; git 48b28d97)
* docker:         Docker version 19.03.12, build 48a6621
* docker-compose: docker-compose version 1.26.2, build unknown, OpenSSL version: OpenSSL 1.1.1f  31 Mar 2020
* go:             go version go1.14.3 linux/arm64
  python3:        Python 3.8.2
  pip3:           pip 20.2.2 from /usr/local/lib/python3.8/dist-packages/pip (python 3.8)
  pip:            pip 20.2.2 from /usr/local/lib/python3.8/dist-packages/pip (python 3.8)
  bash:           5.0.17(1)-release
* sqlite3 shell:  3.33.0, 2020-08-14 13:23:32
  mysql client:   /usr/bin/mysql  Ver 8.0.21-0ubuntu0.20.04.4 for Linux on aarch64 ((Ubuntu))
  psql client:    psql (PostgreSQL) 12.2 (Ubuntu 12.2-4)
  ruby:           ruby 2.7.0p0 (2019-12-25 revision 647ee6f091) [aarch64-linux-gnu]
  gem:            3.1.2
* deploy tools:   dpl (1.10.15), dpl-bintray (1.10.15), dpl-releases (1.10.15)

```  
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

