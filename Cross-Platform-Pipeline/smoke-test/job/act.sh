set -eu; set -o pipefail
Say "Perform smoke test job"
(
  echo "HOST: $(hostname)"; 
  echo "KERNEL: $(uname -r)"; 
  echo "GLIBC: $(getconf GNU_LIBC_VERSION)"; 
  printf "\nMEMORY\n"; Drop-FS-Cache; free -m; 
  printf "\nSTORAGE\n"; df -h -T; 
  echo ""; url=https://raw.githubusercontent.com/devizer/glist/master/Benchmark-net40.exe; try-and-retry curl -ksfSL -o /tmp/Benchmark-net40.exe "$url"; time mono /tmp/Benchmark-net40.exe; 
  printf "\nOS RELEASE\n"; cat /etc/os-release; cat /etc/debian_version 2>/dev/null
) | tee results.txt

echo $(uname -r) > kernel.txt
getconf GNU_LIBC_VERSION > GLIBC-Version.txt
hostname > hostname.txt

rm -rf /var/lib/apt/* /var/cache/apt/* || true
printf "\nONLINE APT\n";
time apt-get update -q | grep --line-buffered -v "Reading" 2>/dev/null | tee -a results.txt


