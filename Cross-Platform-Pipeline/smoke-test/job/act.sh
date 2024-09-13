Say "Perform smoke test job"
(echo "HOST: $(hostname)"; echo "KERNEL: $(uname -r)"; printf "\n\nMEMORY\n"; Drop-FS-Cache; free -m; printf "\n\nSTORAGE\n"; df -h -T; printf "\n\nBENCHMARK\n"; openssl speed -evp md5; printf "\n\nOS RELEASE\n"; cat /etc/os-release) | tee results.txt
echo $(uname -r) > kernel.txt
time apt-get update | grep -v "Reading" 2>/dev/null | tee "apt update.log"

