#!/usr/bin/env bash
work=$HOME/azure-pipelines-agent
mkdir -p $work
cd $work
Say "Azure Pipelines Agent path: [$(pwd)]"
# printenv | sort
suffix=linux-arm
system="$(uname -m)"
if [[ "$system" == "x86_64" ]]; then suffix=linux-x64; fi
if [[ "$system" == "aarch64" ]]; then suffix=linux-arm64; fi
# url=https://vstsagentpackage.azureedge.net/agent/2.165.2/vsts-agent-${suffix}-2.165.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.168.2/vsts-agent-${suffix}-2.168.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.173.0/vsts-agent-${suffix}-2.173.0.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.174.1/vsts-agent-${suffix}-2.174.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.174.2/vsts-agent-${suffix}-2.174.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.174.3/vsts-agent-${suffix}-2.174.3.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.175.2/vsts-agent-${suffix}-2.175.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.177.1/vsts-agent-${suffix}-2.177.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.179.0/vsts-agent-${suffix}-2.179.0.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.181.1/vsts-agent-${suffix}-2.181.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.182.1/vsts-agent-${suffix}-2.182.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.183.1/vsts-agent-${suffix}-2.183.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.184.2/vsts-agent-${suffix}-2.184.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.185.1/vsts-agent-${suffix}-2.185.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.186.1/vsts-agent-${suffix}-2.186.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.187.2/vsts-agent-${suffix}-2.187.2.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.188.4/vsts-agent-${suffix}-2.188.4.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.202.1/vsts-agent-${suffix}-2.202.1.tar.gz
url=https://vstsagentpackage.azureedge.net/agent/2.220.0/vsts-agent-${suffix}-2.220.0.tar.gz
filename=$(basename $url)
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.173.0/vsts-agent-linux-arm64-2.173.0.tar.gz

try-and-retry wget --no-check-certificate --progress=bar:force:noscroll -O "$filename" $url
Say "Extracting $filename"
if [[ "$(command -v pv)" != "" ]]; then
    pv "$filename" | tar xzf -
else
    tar xzf "$filename"
fi 
rm -f "$filename"
source /etc/os-release
Say "Checking .NET Core dependencies"
if false && [[ "$UBUNTU_CODENAME" == "xenial" ]]; then
    sudo bash ./bin/installdependencies.sh || true
else
    url=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-dependencies.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | UPDATE_REPOS=true bash -e && echo "Successfully installed .NET Core Dependencies" || true
fi
Say "Configuraring Azure Pipelines Agent for the '${VSTS_POOL:-Default}' pool"
agent_work_folder="${VSTS_WORK:-$HOME/work}"
mkdir -p "$agent_work_folder"
./config.sh --unattended \
  --agent "${VSTS_AGENT:-$(hostname)}" \
  --url "${VSTS_URL}" \
  --work "$agent_work_folder" \
  --auth pat --token "$VSTS_PAT" --pool "${VSTS_POOL:-Default}" --replace & wait $!
  
Say "Configuration log for Azure Pipelines Agent"
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
