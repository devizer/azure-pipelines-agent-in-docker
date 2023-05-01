echo "PATH: [$($ENV:PATH)]"
& net stop mssqlserver

$tag="ltsc2019"
$imageTag=$tag
$image="devizervlad/sqlserver-archive"
pushd SqlDockerContext 

# regedit /i /s C:\shared\settings.reg
& regedit /e /s C:\SQL\SqlServer-32.reg "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\MSSQLServer"
& regedit /e /s C:\SQL\SqlServer-64.reg "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer"

# & regedit 
Copy-Item -Path "C:\SQL\*" -Destination . -Recurse

$sqlfull=(Get-ChildItem -Path C:\SQL -Filter sqlservr.exe -Recurse -ErrorAction SilentlyContinue -Force)[0].FullName
$mdf=(Get-ChildItem -Path C:\SQL -Filter master.mdf -Recurse -ErrorAction SilentlyContinue -Force | Where { -not ($_.FullName -like "*Template*") } )[0].FullName
$ldf=(Get-ChildItem -Path C:\SQL -Filter mastlog.ldf -Recurse -ErrorAction SilentlyContinue -Force | Where { -not ($_.FullName -like "*Template*") } )[0].FullName
$errlog=(Get-ChildItem -Path C:\SQL -Filter ERRORLOG -Recurse -ErrorAction SilentlyContinue -Force | Where { -not ($_.FullName -like "*Template*") } )[0].FullName
$sqlpath=[System.IO.Path]::GetDirectoryName($sqlfull)
$sqlexe=[System.IO.Path]::GetFileName($sqlfull)
echo "FULL: [$sqlfull]"
echo "PATH: [$sqlpath]"
echo "EXE:  [$sqlexe]"
echo "master mdf: [$mdf]"
echo "master ldf: [$ldf]"
echo "ERRORLOG: [$errlog]"


echo "Echo Starting SQL Server..." >> BootstrapSqlServer.cmd
echo "regedit /i /s C:\SQL\SqlServer-32.reg" >> BootstrapSqlServer.cmd
echo "regedit /i /s C:\SQL\SqlServer-64.reg" >> BootstrapSqlServer.cmd
echo "cd $sqlpath"            >> BootstrapSqlServer.cmd
echo "del $errlog"            >> BootstrapSqlServer.cmd
# NO SPACES: https://learn.microsoft.com/en-us/sql/tools/sqlservr-application?view=sql-server-ver16
echo "$sqlexe -c -n -d$mdf -l$ldf -e$errlog" >> BootstrapSqlServer.cmd
echo "type $errlog"
# echo "dir /b /s"              >> BootstrapSqlServer.cmd

echo "BootstrapSqlServer.cmd CONTENT IS"
cat BootstrapSqlServer.cmd

& 7z a -mx=4 "$($ENV:SYSTEM_ARTIFACTSDIRECTORY)\\SQL.7z" C:\SQL

& docker build --build-arg TAG=$tag -t "$($image):$($imageTag)" .
& docker run -t "$($image):$($imageTag)"

popd

