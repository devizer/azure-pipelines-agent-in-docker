$ErrorActionPreference = 'Stop'

$osBuild=[Environment]::OsVersion.Version.Build
Write-Host "OS-Build: $($osBuild)"

echo "Setup SqlServer-Version-Management ..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
$urlSource = 'https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1'; 
foreach($attempt in 1..3) { try { iex ((New-Object System.Net.WebClient).DownloadString($urlSource)); break; } catch {Write-Host "Error downloading $urlSource"; sleep 0.1;} }

echo "Import-Module SqlServer-Version-Management ..."
Import-Module SqlServer-Version-Management

$osName = "$((Select-WMI-Objects Win32_OperatingSystem | Select -First 1).Caption)"
Write-Host "OS Name: $osName"
Say "OS Name: [$osName], Build [$osBuild]"


$ENV:PS1_TROUBLE_SHOOT = "On"
$ENV:SQLSERVERS_MEDIA_FOLDER = "C:\SQL-SETUP\Media"
$ENV:SQLSERVERS_SETUP_FOLDER = "C:\SQL-SETUP\Installer"
$ENV:PS1_REPO_DOWNLOAD_FOLDER = "C:\Temp"

$isOk = Download-File-FailFree-and-Cached "C:\ServiceMonitor.exe" "https://github.com/microsoft/IIS.ServiceMonitor/releases/download/v2.0.1.10/ServiceMonitor.exe"

Say "Installing IIS"
Measure-Action "Installing IIS" { Add-WindowsFeature Web-Server }

$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Write-Host "The current script's directory is: $scriptDirectory"
. "$scriptDirectory\Setup-Net35-On-Windows-Server.ps1"

Say "FINAL FEATURES"
Get-WindowsFeature | ft -autosize | Out-String -Width 1234
