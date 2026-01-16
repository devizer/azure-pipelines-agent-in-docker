# escape=`
ARG BASE_IMAGE
FROM $BASE_IMAGE

ENV `
  COMPLUS_NGenProtectedProcess_FeatureEnabled=0 `
  ASPNETCORE_FORWARDEDHEADERS_ENABLED=true `
  DOTNET_RUNNING_IN_CONTAINER=true

COPY . C:\Windows\Temp\

RUN powershell -f C:\Windows\Temp\Setup-Container.ps1
WORKDIR /path/to/dir

EXPOSE 80

# ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]
ENTRYPOINT ["C:\\Container-Monitor\\LogMonitor.exe", "C:\\Container-Monitor\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]

