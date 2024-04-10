
function get_openssl_system_version() {
  local ret="$(openssl version 2>/dev/null | awk '{print $2}')"; ret=""
  if [[ -z "$ret" ]]; then
    if [[ -n "$(command -v apt-get)" ]]; then
      ret="$(apt-cache show openssl | grep -E '^Version:' | awk '{print $2}' | sort -V -r)"
    fi
    if [[ -n "$(command -v dnf)" ]]; then
      ret="$(dnf list openssl | grep -E '^openssl' | awk '{print $2}' | awk -F":" 'NR==1 {print $NF}')"
    elif [[ -n "$(command -v yum)" ]]; then
      ret="$(yum list openssl | grep -E '^openssl' | awk '{print $2}' | awk -F":" 'NR==1 {print $NF}')"
    fi
    if [[ -n "$(command -v zypper)" ]]; then
      ret="$(zypper info openssl | grep -E '^Version(\ *):' | awk -F':' '{v=$2; gsub(/ /,"", v); print v}' | sort -V -r)"
    fi
  fi
  echo $ret
}

function install_optional_open_ssl_11() {
  sslver=$(get_openssl_system_version)
  Say "SYSTEM OPENSSL VERSION: [$sslver]"
  if [[ "$sslver" == 3* ]]; then 
      Say "Downloading openssl 1.1.1m"
      # libssl 1.1.1m side-by-side binaries with ld.so.conf registration
      # Special for Ubuntu 22.04, Fedora 36+, and other linux without libssl 1.1
      # Supported Arch: x86_64, i386, arm, aarch64
      export INSTALL_DIR=/opt/curl-temp TOOLS="curl"; 
      script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash

      tmp="$(mktemp)"
      sudo cat /etc/ld.so.conf >> "$tmp"; 
      echo "" >> "$tmp"; 
      test -d /opt/networking/lib64 && echo /opt/networking/lib64 >> "$tmp"
      test -d /opt/networking/lib && echo /opt/networking/lib >> "$tmp"
      sudo mv -f "$tmp" /etc/ld.so.conf
      sudo ldconfig
      sudo rm -rf /opt/curl-temp
      
      ldconfig -p | grep libssl
  fi
}
