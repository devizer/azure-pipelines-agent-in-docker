set -eu; set -o pipefail
Say "Perform smoke test job"
(
  echo "HOST: $(hostname)"; echo "KERNEL: $(uname -r)"; 
  printf "\nMEMORY\n"; Drop-FS-Cache; free -m; 
  printf "\nSTORAGE\n"; df -h -T; 
  echo ""; url=https://raw.githubusercontent.com/devizer/glist/master/Benchmark-net40.exe; try-and-retry curl -ksfSL -o /tmp/Benchmark-net40.exe "$url"; time mono /tmp/Benchmark-net40.exe; 
  printf "\nOS RELEASE\n"; cat /etc/os-release; cat /etc/debian_version 2>/dev/null
) | tee results.txt

echo $(uname -r) > kernel.txt

rm -rf /var/lib/apt/* /var/cacheb/apt/* || true
printf "\nONLINE APT\n";
time apt-get update | grep -v "Reading" 2>/dev/null | tee -a results.txt

