#!/bin/bash
set -eu; set -o pipefail;
Say --Reset-Stopwatch
source /Install/VM-Manager.sh
arch="$(cat /Cloud-Image/arch.txt)"
export VM_SSH_PORT=22022
if [[ -z "${VM_CPUS:-}" ]]; then
  VM_CPUS="$(nproc)" 
  if [[ $VM_CPUS -gt 2 ]]; then VM_CPUS=2; fi
fi
export VM_CPUS
export VM_MEM="${VM_MEM:-2048M}"
if [[ "$QEMU_IMAGE_ID" == armel* ]]; then export VM_MEM="256M"; fi
Say "Virtual CPUS: $VM_CPUS, MEMORY: $VM_MEM"
Say "LAUNCH-VM [$QEMU_IMAGE_ID]. TGC acceleration is \"${QEMU_TCG_ACCELERATOR:-}\""
Launch-VM $arch /Cloud-Image/cloud-config.qcow2 /Cloud-Image
pid=$(cat /Cloud-Image/pid)
Say "VM LAUNCHED. PID is $pid"

export VM_PROVISIA_FOLDER=/job
export HOST_OUTCOME_FOLDER="${VM_PROVISIA_FOLDER}"
export VM_OUTCOME_FOLDER="${VM_PROVISIA_FOLDER}"
export VM_POSTBOOT_SCRIPT="$@"
mkdir -p "${VM_PROVISIA_FOLDER}"
# echo "For VM Content" > "${VM_PROVISIA_FOLDER}"/my-source.txt

# -o allow_other
mkdir -p ~/.ssh; printf "Host *\n   StrictHostKeyChecking no\n   UserKnownHostsFile=/dev/null" > ~/.ssh/config
if [[ -z "$(grep user_allow_other /etc/fuse.conf)" ]]; then
  printf "\nuser_allow_other\n" | sudo tee -a /etc/fuse.conf
fi


pushd "${VM_PROVISIA_FOLDER}" >/dev/null
tar czf /Cloud-Image/provisia.tar.gz .
# ls -lah /Cloud-Image/provisia.tar.gz
popd >/dev/null

echo '
VM_SSH_PORT='$VM_SSH_PORT'
VM_PROVISIA_FOLDER='"'"$VM_PROVISIA_FOLDER"'"'
VM_VARIABLES='"'"${VM_VARIABLES:-}"'"'
VM_USER_NAME='"'"${VM_USER_NAME:-root}"'"'
VM_PREBOOT_SCRIPT='"'"${VM_PREBOOT_SCRIPT:-}"'"'
VM_POSTBOOT_SCRIPT='"'""${VM_POSTBOOT_SCRIPT:-}""'"'
VM_POSTBOOT_ROLE='"'"${VM_POSTBOOT_ROLE:-root}"'"'
VM_OUTCOME_FOLDER='"'"${VM_OUTCOME_FOLDER:-/job}"'"'
' > "/Cloud-Image/variables"

echo "${VM_VARIABLES:-}" | awk -FFS=";" 'BEGIN{FS=";"}{for(i=1;i<=NF;i++){print $i}}' | while IFS= read -r var; do
  echo "PASS VAR '$var' into"
  echo "$var='${!var}'" | tee -a "/Cloud-Image/variables"
  echo "export $var" | tee -a "/Cloud-Image/variables"
done

Wait-For-VM /Cloud-Image
