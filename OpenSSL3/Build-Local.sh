set -eu; set -o pipefail

sudo="$(command -v sudo || true)"
if [[ -n "$(command -v apt-get)" ]]; then
    Say "apt-get update"
    time $sudo apt-get update -qq 
    Say "apt-get install build-essential perl"
    time $sudo apt-get install sudo build-essential perl wget -y -qq | { grep --line-buffered "Setting\|Prepar" || true; }
elif [[ -n "$(command -v apk)" ]]; then
    Say "apk update and add"
    time $sudo apk update
    time $sudo apk add build-base perl-utils linux-headers
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

if [[ "$(hostname)" == *"container"* ]]; then
  url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
  Say "Final UNAME MACHINE: $(uname -m)"
else
  Say " Install-Fake-UName.sh skipped. HOSTNAME '$(hostname)' does not contain 'container'."
fi

work=$HOME/build/openssl-3.0; mkdir -p "$work"; cd "$work" && rm -rf * || true
# https://openssl-library.org/source/
ver=3.0.19
ver=3.5.5
ver=3.3.6
ver=3.4.4
ver=3.6.1
ver="${SSL_VERSION:-$ver}"
suffix="${ver%.*}"
export url="https://github.com/openssl/openssl/releases/download/openssl-$ver/openssl-$ver.tar.gz"
export file="_$(basename "$url")"
echo "Download-File '$url' '$file' is starting ..."
try-and-retry bash -e -c 'Download-File "$url" "$file"; gzip -t "$file"'
tar xzf "$file"
cd openssl*
prefix=/usr/local/openssl-$suffix
mkdir -p "$prefix"
rm -rf "$prefix"/*
# EXPERIMENTAL static libatomic (only debian)
config_options="shared no-tests -O3 no-module no-afalgeng"
[[ "$ver" == "3.6"* ]] && config_options="$config_options -std=gnu99"
if [[ "$(Get-NET-RID)" == *musl* ]]; then config_options="$config_options -static-libgcc"; fi; # else $sudo apt-get install libatomic-ops-dev -y -qq; export LDFLAGS="-static-libatomic"; fi

# Special case: libatomic on 32 bit debian
if [[ "$(Get-Linux-OS-Bits)" == 32 && "$(Is-Musl-Linux)" == False ]]; then
  $sudo apt-get install libatomic-ops-dev -y -qq | { grep "Unpack\|Prepar" || true; } || true
  ATOMIC_A=$(find /usr -name "libatomic.a" | head -n 1 || true)
  if [[ -n "$ATOMIC_A" ]]; then
     # 
     # config_options="$config_options -Wl,--whole-archive $ATOMIC_A -Wl,--no-whole-archive -Wl,--exclude-libs,libatomic.a"
     Colorize Green "Warning! libatomic.a found '$ATOMIC_A', it will be STATICALLY linked on 32-bit NON-musl platform $(Get-NET-RID)"
  else
     Colorize Red "Warning! libatomic.a not found at /usr, it will be dynamically linked on 32-bit platform $(Get-NET-RID)"
  fi
fi

Say "OpenSSL3 $ver Prefix: [$prefix], Configure Options: [$config_options]"
LOG_NAME="$SYSTEM_ARTIFACTSDIRECTORY/OpenSSL-$ver-$(Get-NET-RID)"
echo "LOG_NAME (a prefix) = [$LOG_NAME]"
if [[ "$(uname -m)" == "x86_64" ]]; then
    Say "Tune for SSE2 only with assembler on x64"
    ./Configure linux-x86_64 $config_options \
        -march=x86-64 \
        -mtune=generic \
        -mno-sse3 -mno-ssse3 -mno-sse4 -mno-sse4.1 -mno-sse4.2 \
        -mno-avx -mno-avx2 \
        --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == i?86 ]]; then
    Say "TUNE i686"
    # -march=pentium3 | -march=i686
    ./Configure linux-elf $config_options \
         -march=pentium3 -m32 -mno-sse2 \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "aarch64" ]]; then
    Say "TUNE ARM64"
    # TODO: -mavx2
    ./Configure linux-aarch64 $config_options \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "armv7"* || "$(uname -m)" == "armv6"* ]]; then
    Say "TUNE ARMv7l 32 bit"
    # -D__ARM_MAX_ARCH__=4 \
    # for 3.6 tests: -std=c99
    # AFALG engine is a bridge that allows OpenSSL to offload cryptographic operations to the Linux Kernel Crypto API
    # TODO: -march=armv6 or -march=armv7-a, but not a -marm
    #       -D__ARM_MAX_ARCH__=8 (limitation, not a requirement)
    ./Configure linux-armv4 $config_options \
         -marm -march=armv7-a -mfloat-abi=hard \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
else
    Say "Default shared Configuration"
   ./Configure shared $config_options --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
fi
perl configdata.pm --dump 2>&1 | tee ${LOG_NAME}.config.data.log || true
cores=$(nproc); stdout="/dev/null"; if [[ "$(Is-Qemu-Process)" == True ]]; then cores=1; stdout="/dev/stdout"; fi
Colorize Magenta "CPU CORES FOR MAKE: $cores (Is-Qemu-Process = $(Is-Qemu-Process))"
# | tee $stdout >/dev/null
time (
  if [[ "$(Is-Qemu-Process)" == True ]]; then make -j 3; else make -j; fi
  Say "MAKE SUCCESS. Running make install"
  $sudo make install >/dev/null ) 2>&1 | tee ${LOG_NAME}.make.install.txt
Say "make and install sucessfully completed [$(Get-NET-RID)]"

printf "%s" $prefix > $prefix/prefix.txt
printf $ver > $prefix/version.txt
# time make test
export LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64 
$prefix/bin/openssl version 2>&1 | tee ${LOG_NAME}.SHOW.VERSION.txt
export 
COLUMN_TYPE=custom; [[ "$(Is-Qemu-Process)" == True ]] && COLUMN_TYPE="$COLUMN_TYPE (qemu)"
export COLUMN_TYPE
Benchmark-OpenSSL "$prefix/bin/openssl"

export GZIP="-9"
Say "PACK FULL [$(Get-NET-RID)]"
cd $prefix
cd ..
time tar czf ${LOG_NAME}.full.tar.gz "$(basename $prefix)"
tar cf - "$(basename $prefix)" | xz -9 > ${LOG_NAME}.full.tar.xz

Say "PACK BINARIES-ONLY [$(Get-NET-RID)]"
cd $prefix
only_so_folder=$HOME/openssl-only-so/$(Get-NET-RID)
mkdir -p $only_so_folder; rm -rf $only_so_folder/*
dependencies_info_file="${LOG_NAME}.dependencies.info.txt"
rm -f "$dependencies_info_file"
find -name '*.so.3' | sort | while IFS= read -r file; do
  cp -v "$file" $only_so_folder/; 
  Say "DEPENDENCIES for '$file'"
  (echo "DEPENDENCIES for $(Get-NET-RID) $(basename "$file"):"; ldd "$file"; echo "") | tee -a "$dependencies_info_file"
done
cd $only_so_folder
printf $(Get-NET-RID) | tee openssl-rid.txt
printf $ver | tee openssl-version.txt
tar czf ${LOG_NAME}.binaries-only.tar.gz *
tar cf - * | xz -9 > ${LOG_NAME}.binaries-only.tar.xz

Say "PACK BINARIES-ONLY STRIPPED [$(Get-NET-RID)]"
strip *.so*
tar czf ${LOG_NAME}.binaries-only.stripped.tar.gz *
tar cf - * | xz -9 > ${LOG_NAME}.binaries-only.stripped.tar.xz


