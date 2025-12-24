@echo off
for %%f in (VM-Manager.sh VM-Initial-Provisioning.sh) DO (
  powershell -c "Write-Host SYNTAX CHECK FOR %%f -ForegroundColor Yellow"
  "C:\Program Files\git\bin\bash" -n %%f
  if errorlevel 1 (powershell -c "Write-Host ERROR %%f -ForegroundColor Red") Else (powershell -c "Write-Host OK %%f -ForegroundColor Green")
)

