# escape=`
ARG BASE_IMAGE
FROM $BASE_IMAGE

ENV COMPLUS_NGenProtectedProcess_FeatureEnabled=0

COPY . C:\Windows\Temp\

RUN powershell -f C:\Windows\Temp\Setup-Container.ps1

EXPOSE 80

# ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]
ENTRYPOINT ["C:\\LogMonitor\\LogMonitor.exe", "C:\\ServiceMonitor.exe", "w3svc", "DefaultAppPool", "-st", "100", "-at", "100"]

