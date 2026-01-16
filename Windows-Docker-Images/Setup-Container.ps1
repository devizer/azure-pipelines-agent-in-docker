$osBuild=[Environment]::OsVersion.Version.Build
Write-Host "OS-Build: $($osBuild)"

# Setup SqlServer-Version-Management.ps1
$urlSource = 'https://devizer.github.io/SqlServer-Version-Management/SqlServer-Version-Management.ps1'; 
foreach($attempt in 1..3) { try { iex ((New-Object System.Net.WebClient).DownloadString($urlSource)); break; } catch {sleep 0.1;} }

$osName = "$((Select-WMI-Objects Win32_OperatingSystem | Select -First 1).Caption)"
Write-Host "OS Name: $osName"
Say "OS Name: $osName"


$ENV:PS1_TROUBLE_SHOOT = "On"
$ENV:SQLSERVERS_MEDIA_FOLDER = "C:\SQL-SETUP\Media"
$ENV:SQLSERVERS_SETUP_FOLDER = "C:\SQL-SETUP\Installer"
$ENV:PS1_REPO_DOWNLOAD_FOLDER = "C:\Temp"

Download-File-FailFree-and-Cached "C:\ServiceMonitor.exe" "https://github.com/microsoft/IIS.ServiceMonitor/releases/download/v2.0.1.10/ServiceMonitor.exe"

Say "Installing IIS"
Measure-Action "Installing IIS" { Add-WindowsFeature Web-Server }



