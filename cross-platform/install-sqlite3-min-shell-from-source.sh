#!/usr/bin/env bash
# apt-get install unzip binutils bsdutils build-essential wget -y
set -e
url=https://www.sqlite.org/2020/sqlite-amalgamation-3310100.zip
url=https://www.sqlite.org/2020/sqlite-amalgamation-3330000.zip
work=$HOME/build/sqlite3-src
mkdir -p $work
pushd $work
wget --no-check-certificate -O _sqlite3.src.zip $url || curl -ksSL -o _sqlite3.src.zip $url
unzip -o _sqlite3.src.zip
cd sqlite*
time gcc -O2 shell.c sqlite3.c -lpthread -ldl -o sqlite3
strip sqlite3
echo "sqlite3 version: $(./sqlite3 /tmp/temp-sqllite.db 'select sqlite_version();')"
rm -f /tmp/temp-sqllite.db || true
sudo mv sqlite3 /usr/local/bin/sqlite3 2>/dev/null || mv sqlite3 /usr/local/bin/sqlite3
popd
rm -rf $work
