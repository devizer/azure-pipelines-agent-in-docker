#!/usr/bin/env bash

Say "Installing PowerShell";
script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s pwsh;

if [[ -n "$(command -v ldconfig)" ]] && [[ -z "$(ldconfig -p | grep libssl.so.1.1)" ]]; then
  Say "openssl 1.1 missing. Installing precompiled 1.1.1m"
  url=https://raw.githubusercontent.com/devizer/glist/master/install-libssl-1.1.sh; 
  (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
else
  echo "Using preinstalled libssl.so.1.1"
fi

Say "Checking Up SSL over PowerShell";
pwsh -c "Invoke-WebRequest https://google.com"

