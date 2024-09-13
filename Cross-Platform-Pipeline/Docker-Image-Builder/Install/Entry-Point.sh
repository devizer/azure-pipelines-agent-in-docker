#!/bin/bash
echo ">>> ENTRY-POINT <<<"
set -eu; set -o pipefail;
source /Install/VM-Manager.sh
arch="$(cat /Cloud-Image/arch.txt)"
export VM_SSH_PORT=22022
export VM_CPUS="$(nproc)" 
export VM_MEM="2048M"
Say "LAUNCH-VM in $(pwd)"
Launch-VM $arch /Cloud-Image/cloud-config.qcow2 /Cloud-Image
pid=$(cat /Cloud-Image/pid)
Say "VM LAUNCHED. PID is $pid"

export VM_PROVISIA_FOLDER=/app
export HOST_OUTCOME_FOLDER=/app
mkdir -p /app
echo "For VM Content" > /app/my-source.txt

pushd /app
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