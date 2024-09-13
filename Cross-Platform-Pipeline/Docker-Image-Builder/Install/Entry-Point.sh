#!/bin/bash
set -eu; set -o pipefail;
Say --Reset-Stopwatch
source /Install/VM-Manager.sh
arch="$(cat /Cloud-Image/arch.txt)"
export VM_SSH_PORT=22022
export VM_CPUS="$(nproc)" 
if [[ $VM_CPUS -gt 2 ]]; then VM_CPUS=2; fi
Say "Virtual CPUS: $VM_CPUS"
export VM_MEM="2048M"
Say "LAUNCH-VM [QEMU_IMAGE_ID]"
Launch-VM $arch /Cloud-Image/cloud-config.qcow2 /Cloud-Image
pid=$(cat /Cloud-Image/pid)
Say "VM LAUNCHED. PID is $pid"

export VM_PROVISIA_FOLDER=/app
export HOST_OUTCOME_FOLDER=/app
export VM_POSTBOOT_SCRIPT="$@"
mkdir -p /app
echo "For VM Content" > /app/my-source.txt

pushd /app
tar czf /Cloud-Image/provisia.tar.gz .
popd

echo '
VM_SSH_PORT='$VM_SSH_PORT'
VM_PROVISIA_FOLDER='"'"$VM_PROVISIA_FOLDER"'"'
VM_VARIABLES='"'"${VM_VARIABLES:-}"'"'
VM_USER_NAME='"'"${VM_USER_NAME:-root}"'"'
VM_PREBOOT_SCRIPT='"'"${VM_PREBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_SCRIPT='"'""${VM_POSTBOOT_SCRIPT:-}""'"'
VM_POSTBOOT_ROLE='"'"${VM_POSTBOOT_ROLE:-root}"'"'
VM_OUTCOME_FOLDER='"'"${VM_OUTCOME_FOLDER:-/root}"'"'
' > "/Cloud-Image/variables"

Wait-For-VM /Cloud-Image
