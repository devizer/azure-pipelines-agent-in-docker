Say "Adding Web-Mgmt-Service: IIS Management Service"
$res = Add-WindowsFeature Web-Mgmt-Service
$res | ft -autosize | Out-String -width 1234
if (-not $res.Success) { throw "Error Installing IIS Management Service. See Error Above" }

Say "Enable REMOTE Management and activating WMSVC"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WebManagement\Server" -Name "EnableRemoteManagement" -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WebManagement\Server" -Name "WindowsAuthenticationEnabled" -Value 1
Set-Service -Name WMSVC -StartupType Automatic
Restart-Service -Name WMSVC

Say "Done: IIS Remote Management setup completed"
