& net stop mssqlserver

$tag="ltsc2019"
$imageTag=$tag
$image="devizervlad/sqlserver-archive"
pushd SqlDockerContext 

Copy-Item -Path C:\SQL\ -Destination . -Recurse

echo "Starting SQL Server..." >> BootstrapSqlServer.cmd
echo "dir /b /s"              >> BootstrapSqlServer.cmd

& docker build --build-arg TAG=$tag -t "$($image):$($imageTag)" .
& docker run -t "$($image):$($imageTag)"

popd

