#!/bin/bash
set -eu;
totalMemory="$(free -m | awk '/^Mem/{print $2}')"
if [ "$totalMemory" -lt 2000 ]; then
  echo "Total Memory is $totalMemory MB, below 2000 MB. Injecting mute for minimum memory policies"
  LD_PRELOAD=/opt/mssql-memorypolicy-muter/wrapper.so;
  export LD_PRELOAD;
fi
cd /opt/mssql/bin
/opt/mssql/bin/sqlservr
