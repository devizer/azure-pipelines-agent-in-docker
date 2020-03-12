#!/usr/bin/env bash

cd /pre-configure
printenv | grep VSTS_ > /tmp/args; 
chown user /tmp/args; 
su -c "source /tmp/args; source env.sh; bash install-apa.sh" user; 
rm -f /tmp/args;
touch "/home/user/azure-pipelines-agent/.welldone"

./wait-for-systemd.sh

echo '[Unit]
Description=Azure Pipelines Agent

[Service]
# WorkingDirectory=/home/user/azure-pipelines-agent
# ExecStart=/home/user/azure-pipelines-agent/run.sh
WorkingDirectory=/pre-configure
ExecStart=/pre-configure/run-agent.sh
# Restart=always
Restart=on-failure
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=azure-pipelines-agent
User=user
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
DEBIAN_FRONTEND=noninteractive
Environment=DOTNET_ROOT=/usr/share/dotnet
Environment=DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
Environment=DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
Environment=DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1
Environment=container=docker
Environment=LC_ALL=en_US.UTF8
Environment=LANG=en_US.UTF8

[Install]
WantedBy=multi-user.target
' >/etc/systemd/system/azure-pipelines-agent.service

systemctl daemon-reload
systemctl enable azure-pipelines-agent.service
systemctl start azure-pipelines-agent.service
