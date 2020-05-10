#!/usr/bin/env bash
sudo apt-get clean
myclient1=$(apt-cache search default-mysql-client | grep -E '^default-mysql-client ' | awk '{print $1}')
myclient2=$(apt-cache search mysql-client | grep -E '^mysql-client ' | awk '{print $1}')
try-and-retry sudo apt-get install $myclient1 $myclient2 postgresql-client sqlite3 -y
sudo apt-get clean

