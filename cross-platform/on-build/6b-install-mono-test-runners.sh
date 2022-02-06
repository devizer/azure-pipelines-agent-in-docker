#!/usr/bin/env bash
url=https://raw.githubusercontent.com/devizer/glist/master/bin/net-test-runners.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -sSL $url) | bash
exit 0;

Say "Starting in '$(pwd)'. Content of cross-platform/bin/opt/* is below"
pushd ..
ls -la cross-platform/bin/opt/* || true
# tree . -h || true
sudo mkdir -p /opt/net-test-runners
cp -r bin/opt/* /opt
# tree /opt -h
pushd /opt/net-test-runners
bash link-unit-test-runners.sh
popd
popd
