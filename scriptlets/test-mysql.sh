script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
cat /usr/local/bin/Get-Local-Docker-Ip

export MYSQL_VERSION=5.7 MYSQL_CONTAINER_PORT=3057
MySQL-Container start wait-for exec "SHOW VARIABLES LIKE 'version';"

export MYSQL_VERSION=8.0 MYSQL_CONTAINER_PORT=3080
MySQL-Container delete-image start wait-for exec "SHOW VARIABLES LIKE 'version';"


root@ubuntu-ff ~ $ test 1 -eq 1; echo $?
0
root@ubuntu-ff ~ $ test 1 -eq 2; echo $?
1
root@ubuntu-ff ~ $ if [[ 1 -eq 1 ]]; then echo "OK"; fi
OK
root@ubuntu-ff ~ $ if [[ 1 -eq 2 ]]; then echo "OK"; fi

test -f /etc/mysql/conf.d/my.cnf && printf "\n\n[mysqld]\nbind-address = 0.0.0.0\n" >> /etc/mysql/conf.d/my.cnf
