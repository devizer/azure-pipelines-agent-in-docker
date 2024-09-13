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

export VM_PROVISIA_FOLDER=/job
export HOST_OUTCOME_FOLDER="${VM_PROVISIA_FOLDER}"
export VM_POSTBOOT_SCRIPT="$@"
mkdir -p "${VM_PROVISIA_FOLDER}"
echo "For VM Content" > "${VM_PROVISIA_FOLDER}"/my-source.txt

pushd "${VM_PROVISIA_FOLDER}" >/dev/null
tar czf /Cloud-Image/provisia.tar.gz .
ls -lah /Cloud-Image/provisia.tar.gz
popd >/dev/null

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
