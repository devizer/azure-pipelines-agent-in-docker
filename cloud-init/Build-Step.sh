set -ue; set -o pipefail
source VM-Manager.sh 

DEFAULT_NEWSIZE="${DEFAULT_NEWSIZE:-16G}"
Prepare-VM-Image "$IMAGEURL" $THEWORKDIR/run "${NEWSIZE:-$DEFAULT_NEWSIZE}"

Say "Copy VM ($THEWORKDIR/run) to Artifacts ($SYSTEM_ARTIFACTSDIRECTORY)"
# later we will compress it
pushd $THEWORKDIR/run
cp -a -f -v . $SYSTEM_ARTIFACTSDIRECTORY
popd

