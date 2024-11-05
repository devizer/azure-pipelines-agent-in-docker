#!/bin/bash
set -eu; set -o pipefail;
if [[ -x /opt/mssql-tools/bin/sqlcmd ]]; then
  /opt/mssql-tools/bin/sqlcmd "$@"
  exit 0
else 
  exe="$(ls -1 /opt/mssql-tools*/bin/sqlcmd 2>/dev/null)"
  if [[ -n "$exe" ]]; then
    "$exe" "$@"
    exit 0
  fi
fi
echo "[sqlcmd shell] Error. Not found '/opt/mssql-tools*/bin/sqlcmd'"
exit 7


