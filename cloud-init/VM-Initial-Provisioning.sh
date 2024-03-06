set -eu; set -o pipefail;

echo Provisioning Script. FOLDER IS $(pwd). USER IS $(whoami). CONTENT IS BELOW; ls -lah;
mkdir -p /root/_logs

Say "APT UPDATE"
echo "Invloke apt-get update"
(time (apt-get --allow-releaseinfo-change update || apt-get update )) |& tee /root/_logs/apt.update.txt
echo "Invloke apt-get install"
(time (apt-get install -y --force-yes debconf-utils jq gawk)) |& tee /root/_logs/apt.install.txt # missing on old distros

Say "Grab debconf-get-selections"
debconf-get-selections --installer |& tee /root/_logs/debconf-get-selections.part1.txt || true
debconf-get-selections             |& tee /root/_logs/debconf-get-selections.part2.txt || true

Say "Query package list"
list-packages > /root/_logs/packages.txt
echo "Total packages: $(cat /root/_logs/packages.txt | wc -l)"

hostname |& tee /root/_logs/hostname.txt
jq --version |& tee /root/_logs/jq.system.version.txt
git --version |& tee /root/_logs/git.version.txt
grep --version | head -1 |& tee /root/_logs/grep.version.txt
awk --version | head -1 |& tee /root/_logs/awk.version.txt
openssl version |& tee /root/_logs/openssl.version.txt
uname -r | tee /root/_logs/kernel.version.txt
pushd /etc
cp -a -L *release /root/_logs
popd

Say "Optinally check jq version"
jq_raw_ver="$(jq --version | head -1)"
need_update_jq=true
if [[ "${jq_raw_ver}" == *"1.6"* ]] || [[ "${jq_raw_ver}" == *"1.7"* ]]; then need_update_jq=false; fi
if [[ "${need_update_jq}" == true ]]; then
  Say "Installing jq 1.6, prev version is [$jq_raw_ver]"
  time (export INSTALL_DIR=/usr/local TOOLS="jq"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
  jq --version |& tee /root/_logs/jq.upgraded.version.txt
fi

cp -a -f /etc/apt /root/_logs

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
Say "Installing MONO"; time (export INSTALL_DIR=/usr/local MONO_VER=6.12.0.199 TOOLS="mono"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing MS BUILD"; time (export MSBUILD_INSTALL_VER=16.6 MSBUILD_INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/msbuild/Install-MSBuild.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash)
Say "Installing .NET Test Runners"; time (url=https://raw.githubusercontent.com/devizer/glist/master/bin/net-test-runners.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -sSL $url) | bash)
time nunit3-console
Say "Test CSC"
echo -e "public class Program {public static void Main() {System.Console.WriteLine(\"Hello World\");}}" > /tmp/hello-world.cs
time csc -out:/tmp/hello-world.exe /tmp/hello-world.cs
Say "Exec /tmp/hello-world.exe"
time mono /tmp/hello-world.exe


Say "Import Mozilla Certificates"
time try-and-retry try-and-retry mozroots --import --sync
Say "Installing Mono Certificates snapshot"
time (script="https://master.dl.sourceforge.net/project/gcc-precompiled/ca-certificates/update-ca-certificates.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash || true)

# oldpwd=$(pwd)
# Say "OPTIONAL Build Universe.CpuUsage"
# net47 error: /usr/local/lib/mono/msbuild/Current/bin/Microsoft.Common.CurrentVersion.targets(2101,5): error MSB3248: Parameter "AssemblyFiles" has invalid value "/usr/local/lib/mono/4.7-api/mscorlib.dll". Could not load file or assembly "System.Reflection.Metadata, Version=1.4.3.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" or one of its dependencies. [/root/provisia/Universe.CpuUsage/Universe.CpuUsage.csproj]
# Reset-Target-Framework -fw '$FW_TEST_VERSION' -l latest
pushd Universe.CpuUsage.Tests
# time msbuild /t:Restore,Build /p:Configuration=Release /v:m |& tee $oldpwd/msbuild.log || Say --Display-As=Error "MSBUILD FAILED on $(hostname)"
Say "TEST Universe.CpuUsage"
export SKIP_POSIXRESOURCESUSAGE_ASSERTS=True
cd bin/Release/'$FW_TEST_VERSION'
time nunit3-console --workers 1 Universe.CpuUsage.Tests.dll
popd

Say "Installing nuget"
url=https://raw.githubusercontent.com/devizer/glist/master/bin/install-nuget-6.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
time nuget 2>&1 >/tmp/nuget.ver; cat /tmp/nuget.ver | head -1
Say "/etc/os-release"
cat "/etc/os-release"
