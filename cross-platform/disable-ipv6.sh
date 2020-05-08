#!/usr/bin/env bash
echo '
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
' | sudo tee -a /etc/sysctl.conf || true
sudo sysctl -p || true

