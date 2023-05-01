& net stop mssqlserver

$tag="ltsc2019"
$imageTag=$tag
$image="devizervlad/sqlserver-archive"
pushd SqlDockerContext 

Copy-Item -Path "C:\SQL\*" -Destination . -Recurse

$sqlfull=(Get-ChildItem -Path C:\SQL -Filter sqlservr.exe -Recurse -ErrorAction SilentlyContinue -Force)[0].FullName
$mdf=(Get-ChildItem -Path C:\SQL -Filter master.mdf -Recurse -ErrorAction SilentlyContinue -Force)[0].FullName
$ldf=(Get-ChildItem -Path C:\SQL -Filter mastlog.ldf -Recurse -ErrorAction SilentlyContinue -Force)[0].FullName
$sqlpath=[System.IO.Path]::GetDirectoryName($sqlfull)
$sqlexe=[System.IO.Path]::GetFileName($sqlfull)
echo "FULL: [$sqlfull]"
echo "PATH: [$sqlpath]"
echo "EXE:  [$sqlexe]"
echo "master mdf: [$mdf]"
echo "master ldf: [$ldf]"


echo "Starting SQL Server..." >> BootstrapSqlServer.cmd
echo "cd $sqlpath"            >> BootstrapSqlServer.cmd
echo "$sqlexe -d $mdf -l $ldf -e C:\SQL\ERRORLOG" >> BootstrapSqlServer.cmd
echo "dir /b /s"              >> BootstrapSqlServer.cmd

echo "BootstrapSqlServer.cmd CONTENT IS"
cat BootstrapSqlServer.cmd

& docker build --build-arg TAG=$tag -t "$($image):$($imageTag)" .
& docker run -t "$($image):$($imageTag)"

popd

