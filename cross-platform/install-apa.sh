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
url=https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-${suffix}-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz
# https://vstsagentpackage.azureedge.net/agent/2.168.1/vsts-agent-linux-arm-2.168.1.tar.gz

wget --progress=bar:force:noscroll -O linux-agent.tar.gz $url
tar xzf linux-agent.tar.gz
rm -f linux-agent.tar.gz
# ./bin/Agent.Listener configure --unattended \
sudo bash ./bin/installdependencies.sh || true
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
