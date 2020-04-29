#!/usr/bin/env bash
script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-MONO.sh
(wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; 
sudo apt clean