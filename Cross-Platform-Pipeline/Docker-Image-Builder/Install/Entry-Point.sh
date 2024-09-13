#!/bin/bash
set -eu; set -o pipefail
source /Install/VM-Manager.sh
pushd 
arch="$(cat /Cloud-Image/arch.txt)"
export VM_SSH_PORT=22022
export VM_CPUS="$(nproc)" 
export VM_MEM="2048M"
Launch-VM $arch /Cloud-Image/cloud-config.qcow2 /Cloud-Image
pid=$(cat /Cloud-Image/pid)
Say "VM LAUNCHED. PID is $pid"
