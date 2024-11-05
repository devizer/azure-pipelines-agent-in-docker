#!/bin/sh
set -eu; set -o pipefail

LD_PRELOAD=/opt/mssql-memorypolicy-muter/wrapper.so; 
export LD_PRELOAD;
cd /opt/mssql/bin
/opt/mssql/bin/sqlservr
