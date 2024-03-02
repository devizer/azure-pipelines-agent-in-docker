set -ue; set -o pipefail
source VM-Manager.sh 

Prepare-VM-Image "$IMAGEURL" $THEWORKDIR/run "${NEWSIZE:-16G}"

Say "Copy VM ($THEWORKDIR/run) to Artifacts ($SYSTEM_ARTIFACTSDIRECTORY)"
# later we will compress it
pushd $THEWORKDIR/run
cp -a -f -v . $SYSTEM_ARTIFACTSDIRECTORY
popd

