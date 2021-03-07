#!/usr/bin/env bash
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
