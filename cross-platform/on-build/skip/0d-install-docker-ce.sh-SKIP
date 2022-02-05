#!/usr/bin/env bash

script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/Install-DOCKER.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash || true
Say "Restarting docker"
sudo systemctl start docker || true
Say "Docker Version is below"
docker version || true

