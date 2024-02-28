set -ue; set -o pipefail
source VM-Manager.sh 

Say "VM-Launcher-Smoke-Test in [$(pwd)]"
VM-Launcher-Smoke-Test
