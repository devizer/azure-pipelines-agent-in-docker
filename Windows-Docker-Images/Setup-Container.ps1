$ErrorActionPreference = 'Stop'

$osBuild=[Environment]::OsVersion.Version.Build
Write-Host "OS-Build: [$($osBuild)]"
$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Write-Host "The current Setup-Container.ps1 script's directory is: [$scriptDirectory]"

echo "Setup SqlServer-Version-Management ..."
[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true};
$urlSource = 'https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1'; 
foreach($attempt in 1..3) { try { iex ((New-Object System.Net.WebClient).DownloadString($urlSource)); break; } catch {Write-Host "Error downloading $urlSource"; sleep 0.1;} }

# echo "Import-Module SqlServer-Version-Management ..."
# Import-Module SqlServer-Version-Management

# $osName = "$((Select-WMI-Objects Win32_OperatingSystem | Select -First 1).Caption)" - 2019 Known Issue
# NT 4.0+
$osName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
Write-Host "OS Name: $osName"
Say "OS Name: [$osName], Build [$osBuild]"


$ENV:PS1_TROUBLE_SHOOT = "On"
& setx PS1_TROUBLE_SHOOT On
$ENV:SQLSERVERS_MEDIA_FOLDER = "C:\Temp\SQL-SETUP\Media"
& setx SQLSERVERS_MEDIA_FOLDER C:\Temp\SQL-SETUP\Media
$ENV:SQLSERVERS_SETUP_FOLDER = "C:\Temp\SQL-SETUP\Installer"
& setx SQLSERVERS_SETUP_FOLDER C:\Temp\SQL-SETUP\Installer
$ENV:PS1_REPO_DOWNLOAD_FOLDER = "C:\Temp"
& setx PS1_REPO_DOWNLOAD_FOLDER C:\Temp

$monitorFolder="C:\LogMonitor"
Say "Setup Log Monitor and Service Monitor into [$monitorFolder]"
$isOkServiceMonitor = Download-File-FailFree-and-Cached "$monitorFolder\ServiceMonitor.exe" "https://github.com/microsoft/IIS.ServiceMonitor/releases/download/v2.0.1.10/ServiceMonitor.exe"
Write-Host "Service Monitor Download Success: [$isOkServiceMonitor]"

# https://github.com/microsoft/windows-container-tools/blob/main/LogMonitor/README.md
$isOkLogMonitor = Download-File-FailFree-and-Cached "$monitorFolder\LogMonitor.exe" "https://github.com/microsoft/windows-container-tools/releases/download/v2.1.3/LogMonitor.exe"
Write-Host "Log Monitor Download Success: [$isOkLogMonitor]"
Copy-Item -Path "$scriptDirectory\LogMonitorConfig.json" -Destination "$monitorFolder\" -Force

Say "Setup bombardier-windows-amd64.exe v2.0.2 into [C:\Apps\bombardier.exe]"
$isOkBombardier = Download-File-FailFree-and-Cached "C:\Apps\bombardier.exe" "https://github.com/codesenberg/bombardier/releases/download/v2.0.2/bombardier-windows-amd64.exe"
Write-Host "Bombardier Download Success: [$isOkBombardier]"

Say "Deploy Entry Point as C:\Config-Private"
New-Item -Path "C:\Private-Config" -ItemType Directory -Force | out-null
Copy-Item -Path "$scriptDirectory\Private-Config\*" -Destination "C:\Private-Config" -Recurse -Force
ls "C:\Private-Config" | ft -autosize | out-host

############ C:\Apps? ############
Say "Setup C:\Apps"
$appsFolder = "C:\Apps"
New-Item -Path "C:\Apps" -ItemType Directory -Force | out-null
Add-Folder-To-System-Path "C:\Apps"
foreach($exe in (Get-Mini7z-Exe-FullPath-for-Windows), (Get-Aria2c-Exe-FullPath-for-Windows), (Get-Full7z-Exe-FullPath-for-Windows)) {
 $dir = [System.IO.Path]::GetDirectoryName($exe)
 echo "Copy $dir to C:\Apps ..."
 Copy-Item -Path "$($dir)\*" -Destination "C:\Apps\" -Recurse -Force
}
ls "C:\Apps" | ft -autosize | out-host


Say "Installing .NET 3.5"
. "$scriptDirectory\Setup-Net35-On-Windows-Server.ps1"

Say "Installing IIS"
Measure-Action "Installing IIS" { 
  # TODO: Web-Http-Redirect, Web-Basic-Auth, Web-Windows-Auth, Web-ASP, Web-Includes
  # For MMC: Web-Mgmt-Service
  $res = Add-WindowsFeature Web-Server, Web-Asp-Net, Web-Asp-Net45, Web-Scripting-Tools
  $res | ft -autosize | Out-String -width 1234
  if (-not $res.Success) { throw "Error Installing IIS. See Error Above" }
}

echo "Invoking Enable-Remote-IIS-Management.ps1"
. "$scriptDirectory\Enable-Remote-IIS-Management.ps1"

Say "Replacing default landing page"
Remove-Item -Path "C:\Inetpub\wwwroot\*" -Force -Recurse -EA SilentlyContinue
Copy-Item -Path "$scriptDirectory\wwwroot\*" -Destination "C:\Inetpub\wwwroot\" -Recurse -Force

Say "Assign [v4.0] version for [DefaultAppPool]"
& "$env:windir\system32\inetsrv\appcmd.exe" set apppool /apppool.name:DefaultAppPool /managedRuntimeVersion:v4.0
# the same
# Import-Module WebAdministration; Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name managedRuntimeVersion -Value "v4.0"

Write-Host " "
Say "FINAL FEATURES"
Get-WindowsFeature | ft -autosize | Out-String -Width 1234

Write-Host " "
Say "Final NET Frameworks"
. "$scriptDirectory\LIST-NET-Frameworks.ps1"

Say "Installing Choco"
$fileInstallChoco = Combine-Path "$(Get-PS1-Repo-Downloads-Folder)" "Install-Choco.ps1"
$isOkDownloadChoco = Download-File-FailFree-and-Cached "$fileInstallChoco" "https://chocolatey.org/install.ps1"
. "$fileInstallChoco" -ChocolateyVersion "1.4.4"
Say "Choco features: Enable allowGlobalConfirmation, and Disable showDownloadProgress"
& choco feature enable -n allowGlobalConfirmation
& choco feature disable -n showDownloadProgress
Say "Finish: Installed Choco"


Remove-Item -Path "C:\Temp" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$ENV:TEMP" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$ENV:TEMP" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

Say "Bye. Dockerfile done"
