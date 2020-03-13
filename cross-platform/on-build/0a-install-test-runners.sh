#!/usr/bin/env bash
Say "Starting in '$(pwd)'. Content of cross-platform/bin/opt/* is below"
pushd ../..
ls -la cross-platform/bin/opt/* || true
tree . -h || true
popd
