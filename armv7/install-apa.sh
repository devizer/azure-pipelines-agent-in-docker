work=$HOME/pipeline-agent
mkdir -p $work
cd $work
Say "azure pipeline agent path: [$(pwd)]"
printenv | sort
wget --progress=bar:force:noscroll -O linux-agent.tar.gz https://vstsagentpackage.azureedge.net/agent/2.165.0/vsts-agent-linux-arm-2.165.0.tar.gz
tar xzf linux-agent.tar.gz
# ./bin/Agent.Listener configure --unattended \
bash ./bin/installdependencies.sh
./config.sh --unattended \
  --url "${VSTS_URL}" \
  --work "${VSTS_WORK:-_work}" \
  --auth pat --token "$VSTS_PAT" --pool "${VSTS_POOL:-Default}" --replace & wait $!

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
