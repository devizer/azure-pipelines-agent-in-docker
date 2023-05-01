echo Installing choco ...
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
@echo off
for %%v in (vcredist2008 vcredist2005 vcredist2010) DO (
  echo.
  echo Installing %%v
  choco install -my --no-progress %%v
)


