#!/bin/bash
set -eu;

totalMemory="$(free -m | awk '/^Mem/{print $2}')"
if [ "$totalMemory" -lt 2000 ]; then
  echo "Total Memory is $totalMemory MB, below 2000 MB. Injecting mute for minimum memory policies"
  LD_PRELOAD=/opt/mssql-memorypolicy-muter/wrapper.so;
  export LD_PRELOAD;
fi

# 2. Handling IGNORE_SYNC (eatmydata)
if [[ "${IGNORE_SYNC:-}" == "True" || "${IGNORE_SYNC:-}" == "1" ]]; then
  EATMYDATA_LIB="/usr/lib/x86_64-linux-gnu/libeatmydata.so"
  if [[ -f "$EATMYDATA_LIB" ]]; then
      echo "'IGNORE_SYNC' parameter is enabled. Injecting eatmydata wrapper"
      
      # Append if LD_PRELOAD already exists, otherwise just set it
      if [ -z "${LD_PRELOAD:-}" ]; then
        export LD_PRELOAD="$EATMYDATA_LIB"
      else
        export LD_PRELOAD="$EATMYDATA_LIB:$LD_PRELOAD"
      fi
  else
      echo "WARNING! 'IGNORE_SYNC' is enabled. But 'eatmydata' package and '$EATMYDATA_LIB' are missing. Skipping eatmydata wrapper"
  fi
fi

cd /opt/mssql/bin
/opt/mssql/bin/sqlservr
