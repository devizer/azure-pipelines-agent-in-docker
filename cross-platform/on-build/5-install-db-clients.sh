#!/usr/bin/env bash
Say "Installing mysql-client and postgresql-client"
sudo apt-get clean
myclient1=$(apt-cache search default-mysql-client | grep -E '^default-mysql-client ' | awk '{print $1}')
myclient2=$(apt-cache search mysql-client | grep -E '^mysql-client ' | awk '{print $1}')
try-and-retry sudo apt-get install $myclient1 $myclient2 postgresql-client -y

Say "Install sqlite3 (minimum) shell from source"
bash -e ../install-sqlite3-min-shell-from-source.sh
sudo apt-get clean
