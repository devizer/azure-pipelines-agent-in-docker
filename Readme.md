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

Here is preinstalled soft for buster base image. Packages marked by asterisk are distribution independent for debian derivatives 
```
  Build date:     2020-05-19 15:47:53 UTC
  Base Image:     debian:buster
* dotnet sdk:     2.1.804, 2.2.402, 3.0.103, 3.1.202
* pwsh:           PowerShell 6.2.4
* mono:           Mono JIT compiler version 6.8.0.123 (tarball Tue May 12 15:16:23 UTC 2020)
* msbuild:        16.5.0.26101
* nuget:          NuGet Version: 5.5.0.6382
* paket:          Paket version 5.245.1
* xunit.console:  xUnit.net Console Runner v2.4.1 (32-bit Desktop .NET 4.7.2, runtime: 4.0.30319.42000)
* nunit3-console: NUnit Console Runner 3.11.1 (.NET 2.0)
* node:           v12.16.3
* npm:            6.14.5
* yarn:           1.22.4
  openssl:        OpenSSL 1.1.1d  10 Sep 2019
  libssl:         libssl1.1
* git:            git version 2.26.2
* git lfs:        git-lfs/2.11.0 (GitHub; linux arm; go 1.14.3; git 48b28d97)
* docker:         Docker version 19.03.9, build 9d98839
* docker-compose: docker-compose version 1.25.4, build unknown, OpenSSL version: OpenSSL 1.1.1d  10 Sep 2019
* go:             go version go1.14.3 linux/arm
  python3:        Python 3.7.3
  pip3:           pip 20.1 from /usr/local/lib/python3.7/dist-packages/pip (python 3.7)
  pip:            pip 20.1 from /usr/local/lib/python3.7/dist-packages/pip (python 3.7)
  bash:           5.0.3(1)-release
* sqlite3 shell:  3.31.1, 2020-01-27 19:55:54
  mysql client:   mysql  Ver 15.1 Distrib 10.3.22-MariaDB, for debian-linux-gnueabihf (armv8l) using readline 5.2
  psql client:    psql (PostgreSQL) 11.7 (Debian 11.7-0+deb10u1)
  ruby:           ruby 2.5.5p157 (2019-03-15 revision 67260) [arm-linux-gnueabihf]
  gem:            2.7.6.2
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

