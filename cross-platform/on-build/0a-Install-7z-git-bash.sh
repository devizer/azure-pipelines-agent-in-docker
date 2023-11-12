#!/usr/bin/env bash
set -eu
test -f /etc/os-release && source /etc/os-release
OS_VER="${ID:-}:${VERSION_ID:-}"
TOOLS="bash git jq 7z nano"
if [[ "${OS_VER:-}" == "debian:12" || "${OS_VER:-}" == "ubuntu:22"* || "${OS_VER:-}" == "ubuntu:23"* || "${OS_VER:-}" == "ubuntu:24"* ]]; then
  TOOLS="bash jq 7z nano"
fi
export TOOLS

export INSTALL_DIR=/usr/local; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
