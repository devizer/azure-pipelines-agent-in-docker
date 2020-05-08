libcurl3=$(apt-cache search libcurl3 | grep -E '^libcurl3 ' | awk '{print $1}'); 
source /etc/os-release
if [[ "$VERSION_CODENAME" == "xenial" ]]; then packages="curl $libcurl3"; else packages="curl"; fi 
echo "libcurl packages: $packages"
apt-get install -yq $packages
