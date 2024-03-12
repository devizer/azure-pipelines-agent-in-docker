set -eu; set -o pipefail;

echo Provisioning Script. FOLDER IS $(pwd). USER IS $(whoami). CONTENT IS BELOW; ls -lah;
mkdir -p /root/_logs

Say "PATH"
echo $PATH |& tee /root/_logs/PATH.txt

Say "BUILD_SOURCEVERSION = [$BUILD_SOURCEVERSION]"
Say "FORTY_TWO = [$FORTY_TWO]"

set +e
Say "Adjusting os repo"
cat /etc/apt/sources.list
utils=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/build-gcc-utilities.sh
try-and-retry curl -kfSL -o /tmp/build-gcc-utilities.sh $utils
source /tmp/build-gcc-utilities.sh
export SKIP_REPO_UPDATE=true
adjust_os_repo
  
    # on azure jessie/non-free and jessie/contrib are not available
  test -f /etc/os-release && source /etc/os-release
  os_ver="${ID:-}:${VERSION_ID:-}"
  if [[ "${os_ver}" == "debian:8" ]]; then
    echo '
deb http://archive.debian.org/debian/ jessie main
deb http://archive.debian.org/debian-security jessie/updates main non-free contrib
deb http://archive.debian.org/debian jessie-backports main non-free contrib
' > /etc/apt/sources.list
  fi

Say "Adjusted os repo"
cat /etc/apt/sources.list
set -e

echo STOP UNATTENDED-UPGRADES
systemctl stop unattended-upgrades || echo "Can't stop unattended-upgrades. It's ok."

dpkg_arch="$(dpkg --print-architecture)"
if [[ "$dpkg_arch" == armel ]]; then
  Say "Installing 7z 16.02 for armel"
  (time (export INSTALL_DIR=/usr/local TOOLS="7z"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)) |& tee /root/_logs/7z-16.02.install.txt
else
  Say "Installing 7z 23.01"
  (time (export INSTALL_DIR=/usr/local/bin LINK_AS_7Z=/usr/local/bin/7z; script="https://raw.githubusercontent.com/devizer/azure-pipelines-agent-in-docker/master/build-tools/install-7zz%20(direct%20from%207-zip.org).sh"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)) |& tee /root/_logs/7zz2301.install.txt
fi
time 7z b -mmt=1 -md=18


Say "APT UPDATE"
echo "Invloke apt-get update"
# TODO: Remove non-free
(time (apt-get --allow-releaseinfo-change update -q || apt-get update -q)) |& tee /root/_logs/apt.update.txt

Say "Install .NET Dependencies"
url=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-dependencies.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash && echo "Successfully installed .NET Core Dependencies"

if [[ "$dpkg_arch" == armel ]]; then
  Say Display-As=Error "Temporary Skipping Lib SSL 1.1 for armel"
else
  Say "Optional Lib SSL 1.1"
  export INSTALL_DIR=/usr/local/libssl-1.1
  mkdir -p $INSTALL_DIR
  printf "\n$INSTALL_DIR\n" >> /etc/ld.so.conf || true
  url=https://raw.githubusercontent.com/devizer/glist/master/install-libssl-1.1.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
  ldconfig || true
  ldconfig -p | grep "libssl\|libcrypto" |& tee /root/_logs/libssl.version.txt
  export INSTALL_DIR=
fi


export APT_PACKAGES="debconf-utils jq gawk git sshpass sshfs rsync"
Say "Invloke apt-get install [$APT_PACKAGES]"
# --force-yes is deprecated, but works on Debian 13 and Ubuntu 24.04
(time (apt-get install -y --force-yes $APT_PACKAGES || { for pack in $APT_PACKAGES; do Say "Installing one-by-one: $pack"; apt-get install -y -q $pack; done; })) |& tee /root/_logs/apt.install.txt # missing on old distros
mkdir -p ~/.ssh; printf "Host *\n   StrictHostKeyChecking no\n   UserKnownHostsFile=/dev/null" > ~/.ssh/config

Say "Grab debconf-get-selections"
debconf-get-selections --installer |& tee /root/_logs/debconf-get-selections.part1.txt 2>/dev/null 1>&2 || true
debconf-get-selections             |& tee /root/_logs/debconf-get-selections.part2.txt 2>/dev/null 1>&2 || true

Say "Query package list"
list-packages > /root/_logs/packages.txt
echo "Total packages: $(cat /root/_logs/packages.txt | wc -l)"

hostname |& tee /root/_logs/hostname.txt 
jq --version    |& tee /root/_logs/jq.system.version.txt || true
git --version   |& tee /root/_logs/git.version.txt || true
grep --version  | head -1 |& tee /root/_logs/grep.version.txt || true
awk --version   | head -1 |& tee /root/_logs/awk.version.txt || true
openssl version |& tee /root/_logs/openssl.version.txt || true
uname -r |& tee /root/_logs/kernel.version.txt
pushd /etc
cp -a -L *release /root/_logs
popd
sshpass -V | head -1 |& tee /root/_logs/sshpass.version.txt || true
sshfs --version      |& tee /root/_logs/sshfs.version.txt || true
rsync --version      |& tee /root/_logs/rsync.version.txt || true
Say 'LOCLALES.GEN'
cat /etc/locale.gen | grep -v -E '\#' | grep -v -E '^$' |& tee /root/_logs/locale.gen.txt || true

jq_raw_ver="$(jq --version 2>&1 | head -1)"
Say "Optinally check jq version, $jq_raw_ver"
need_update_jq=true
if [[ "${jq_raw_ver}" == *"1.6"* ]] || [[ "${jq_raw_ver}" == *"1.7"* ]]; then need_update_jq=false; fi
if [[ "${need_update_jq}" == true ]]; then
  Say "Installing jq 1.6, prev version is [$jq_raw_ver]"
  time (export INSTALL_DIR=/usr/local TOOLS="jq"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
  jq --version |& tee /root/_logs/jq.upgraded.version.txt
fi

cp -a -f -L /etc/apt /root/_logs

# Say "RAM DISK for /tmp"
# mount -t tmpfs -o mode=1777 tmpfs /tmp
# Say "RAM DISK for /var/tmp"
# mount -t tmpfs -o mode=1777 tmpfs /var/tmp
# Say "RAM DISK for /var/lib/apt"
# mount -t tmpfs tmpfs /var/lib/apt
# Say "RAM DISK for /var/cache/apt"
# mount -t tmpfs tmpfs /var/cache/apt
Say "Mounts"
df -h -T

Say "FREE MEMORY"; free -m;
echo "FREE SPACE"; df -h -T;
Say "OS IS"; cat /etc/*release;
Say "Time Zone Is"; cat /etc/timezone
Say "Locales are"; locale --all
Say "Current Locale"; locale
export GCC_FORCE_GZIP_PRIORITY=true
# 6.12.0.199 with jemalloc does not work on debian 13 arm64
Say "Installing MONO"; time (export INSTALL_DIR=/usr/local MONO_VER=6.12.0.199 TOOLS="mono"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing MS BUILD"; time (export MSBUILD_INSTALL_VER=16.6 MSBUILD_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/msbuild/Install-MSBuild.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)

Say "Installing .NET Test Runners"; time (url=https://raw.githubusercontent.com/devizer/glist/master/bin/net-test-runners.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -sSL $url) | bash)
time nunit3-console 2>&1 >/tmp/nunit3-console; 
nunit_ver="$(cat /tmp/nunit3-console | head -1)";
echo $nunit_ver |& tee /root/_logs/nunit3-console.version.txt

Say "Test CSC"
echo -e "public class Program {public static void Main() {System.Console.WriteLine(\"Hello World\");}}" > /tmp/hello-world.cs
time csc -out:/tmp/hello-world.exe /tmp/hello-world.cs
Say "Exec /tmp/hello-world.exe"
time mono /tmp/hello-world.exe


Say "Import Mozilla Certificates (OPTIONALLY)"
time mozroots --import --sync || true
Say "Installing Certificates snapshot"
time (script="https://master.dl.sourceforge.net/project/gcc-precompiled/ca-certificates/update-ca-certificates.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash || true)

pushd Universe.CpuUsage.Tests
Say "TEST Universe.CpuUsage"
export SKIP_POSIXRESOURCESUSAGE_ASSERTS=True
cd bin/Release/$FW_TEST_VERSION
time nunit3-console --workers 1 Universe.CpuUsage.Tests.dll
popd

Say "Installing nuget"
url=https://raw.githubusercontent.com/devizer/glist/master/bin/install-nuget-6.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
time nuget 2>&1 >/tmp/nuget.ver; cat /tmp/nuget.ver | head -1
Say "/etc/os-release"
cat "/etc/os-release"

if [[ "$(command -v systemctl)" != "" ]]; then
  for s in unattended-upgrades apt-daily-upgrade.timer apt-daily.timer unattended-upgrades apt-daily-upgrade.timer apt-daily.timer; do
    Say "Disable $s"
    systemctl disable $s || Say --Display-As=Error "Can't disable $s. It's ok."
  done
fi
