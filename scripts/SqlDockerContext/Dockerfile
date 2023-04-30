ARG TAG
FROM mcr.microsoft.com/windows/servercore:$TAG

COPY . /SQL
WORKDIR /SQL

RUN dir /b /s

CMD BootstrapSqlServer.cmd


