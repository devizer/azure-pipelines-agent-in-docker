#!/usr/bin/env bash
work=$HOME/azure-pipelines-agent
mkdir -p $work
cd $work
Say "azure pipeline agent path: [$(pwd)]"
# printenv | sort
suffix=linux-arm
system="$(uname -m)"
if [[ "$system" == "x86_64" ]]; then suffix=linux-x64; fi
if [[ "$system" == "aarch64" ]]; then suffix=linux-arm64; fi
# url=https://vstsagentpackage.azureedge.net/agent/2.165.2/vsts-agent-${suffix}-2.165.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.168.2/vsts-agent-${suffix}-2.168.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.173.0/vsts-agent-${suffix}-2.173.0.tar.gz
filename=$(basename $url)
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.173.0/vsts-agent-linux-arm64-2.173.0.tar.gz

try-and-retry wget --no-check-certificate --progress=bar:force:noscroll -O "$filename" $url
tar xzf "$filename"
rm -f "$filename"
source /etc/os-release
if false && [[ "$UBUNTU_CODENAME" == "xenial" ]]; then
    sudo bash ./bin/installdependencies.sh || true
else
    url=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-dependencies.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | UPDATE_REPOS=true bash -e && echo "Successfully installed .NET Core Dependencies" || true
fi
mkdir -p $HOME/work
./config.sh --unattended \
  --agent "${VSTS_AGENT:-$(hostname)}" \
  --url "${VSTS_URL}" \
  --work "${VSTS_WORK:-$HOME/work}" \
  --auth pat --token "$VSTS_PAT" --pool "${VSTS_POOL:-Default}" --replace & wait $!
  
cat _diag/*.log || true

function _ignore_() {
./bin/Agent.Listener configure --unattended \
  --agent "${VSTS_AGENT:-$(hostname)}" \
  --url "https://$VSTS_ACCOUNT.visualstudio.com" \
  --auth PAT \
  --token $(cat "$VSTS_TOKEN_FILE") \
  --pool "${VSTS_POOL:-Default}" \
  --work "${VSTS_WORK:-_work}" \
  --replace & wait $!
}
