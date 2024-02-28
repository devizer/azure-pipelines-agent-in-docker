set -ue; set -o pipefail
source VM-Manager.sh 
Prepare-VM-Image "$IMAGEURL" $THEWORKDIR/run 16G

Say "Copy to $THEWORKDIR/run to $SYSTEM_ARTIFACTSDIRECTORY"
# later we will compress it
cp -a -f -v $THEWORKDIR/run $SYSTEM_ARTIFACTSDIRECTORY

Say "VM-Launcher-Smoke-Test in [$(pwd)]"
VM-Launcher-Smoke-Test
