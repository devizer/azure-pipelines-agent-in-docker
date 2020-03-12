#!/usr/bin/env bash
printf 'Wait for systemd on ubuntu '; 
ok=''; 
for i in {1..9}; do 
  pgrep systemd-journal >/dev/null && export ok='true' && echo ' OK' && break || printf '.'; 
  sleep 1;
done; 
[[ -z $ok ]] && echo ' Fail';
