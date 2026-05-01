for v in 2017 2019 2022 2025; do
  docker pull -q mcr.microsoft.com/mssql/server:2019-latest
  Say "SQL on Linux $v"
  echo "SHOW USER $v"
  docker run --rm -t --entrypoint /bin/bash mcr.microsoft.com/mssql/server:$v-latest -c "id"
  echo "TRY eatmydata $v"
  docker run --rm -t -u root --entrypoint /bin/bash mcr.microsoft.com/mssql/server:$v-latest -c "cat /etc/os-release; echo; echo UPDATING APT; apt-get update -qq; apt-get install eatmydata -y -qq; ls -la /usr/lib/x86_64-linux-gnu/libeatmydata.so;"
done
