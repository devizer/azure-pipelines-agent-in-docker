@echo off

if x_%IIS_NET_VERSION% == x_v2.0 (
   echo SETTING DEFAULT APP Pool Runtime .NET v2.0
   %windir%\system32\inetsrv\appcmd.exe set apppool /apppool.name:DefaultAppPool /managedRuntimeVersion:v2.0
) Else (
   echo SETTING DEFAULT APP Pool Runtime .NET v4.0
   %windir%\system32\inetsrv\appcmd.exe set apppool /apppool.name:DefaultAppPool /managedRuntimeVersion:v4.0
)

if Exist C:\Config\On-Start-Once.cmd (
  if not Exist C:\ProgramData\Run-Once-Complete (
    cd /d C:\Config
    echo INVOKING On-Start-Once.cmd
    call On-Start-Once.cmd
    echo "Complete" > C:\ProgramData\Run-Once-Complete
  )
)

if Exist C:\Config\On-Start.cmd (
    cd /d C:\Config
    echo INVOKING On-Start.cmd
    call On-Start.cmd
)

reg query "HKLM\SYSTEM\CurrentControlSet\Services\vmsvc" >nul 2>&1
if %errorlevel% equ 0 (
    echo Starting VMSVC Service.
    net start wmsvc
) else (
    echo Starting VMSVC Service is not installed.
)
net start w3svc

REM REMINDER docker run -p 80:80 -p 8172:8172 ...

"C:\LogMonitor\LogMonitor.exe" "C:\LogMonitor\ServiceMonitor.exe" "w3svc" "DefaultAppPool" "-st" "100" "-at" "100"
