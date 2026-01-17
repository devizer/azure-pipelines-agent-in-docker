# escape=`
ARG BASE_IMAGE
FROM $BASE_IMAGE

ENV `
  COMPLUS_NGenProtectedProcess_FeatureEnabled=0 `
  ASPNETCORE_FORWARDEDHEADERS_ENABLED=true `
  DOTNET_RUNNING_IN_CONTAINER=true `
  IIS_NET_VERSION=v4.0

COPY . C:\Windows\Temp\

RUN powershell -f C:\Windows\Temp\Setup-Container.ps1
WORKDIR /path/to/dir

EXPOSE 80

# ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]
# ENTRYPOINT ["C:\\LogMonitor\\LogMonitor.exe", "C:\\LogMonitor\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]
ENTRYPOINT ["cmd", "/S", "/C", "C:\\Private-Config\\EntryPoint.cmd"]


