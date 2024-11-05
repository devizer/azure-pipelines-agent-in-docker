#!/bin/sh
set -eu; set -o pipefail
if [[ -x /opt/mssql-memorypolicy-muter/sqlcmd.sh ]]; then cp -f /usr/local/bin/sqlcmd; fi
LD_PRELOAD=/opt/mssql-memorypolicy-muter/wrapper.so; 
export LD_PRELOAD;
cd /opt/mssql/bin
/opt/mssql/bin/sqlservr
