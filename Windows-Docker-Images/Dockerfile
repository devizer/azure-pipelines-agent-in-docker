# escape=`
ARG BASE_IMAGE
FROM $BASE_IMAGE

COPY . C:\Windows\Temp\

RUN powershell -f C:\Windows\Temp\Setup-Container.ps1

EXPOSE 80

ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc"]
