set -eu; set -o pipefail
sudo="$(command -v sudo || true)"
Say "apt-get update"
time $sudo apt-get update -qq 
Say "apt-get install build-essential perl"
time $sudo apt-get install sudo build-essential perl wget -y -qq | { grep --line-buffered "Setting\|Prepar" || true; }

Benchmark-OpenSSL()
{
    local openssl_executable="$1"
    openssl_version="$("$openssl_executable" version | head -1 | awk '{print $2}')"
    report="openssl-$openssl_version"
    # 7th column on last line
    Say "Benchmark Handshake: $report"
    (echo "$openssl_version Handshake RSA2048 Benchmark"; "$openssl_executable" speed -seconds 3 rsa2048 2>&1) | tee "$report.handshake.RSA2048.report"
    (echo "$openssl_version Handshake ECDSA256 Benchmark"; "$openssl_executable" speed -seconds 3 ecdsap256 2>&1) | tee "$report.handshake.ECDSA256.report"
    for bytes in 128 16384; do
    for key_size in 128 256; do
        Say "Benchmark transfer AES-${key_size} ${bytes} bytes: $report"
        # 2nd column on last line
        (echo "$openssl_version Transfer rate AES$key_size $bytes bytes Benchmark"; "$openssl_executable" speed -evp aes-$key_size-gcm -aead -bytes $bytes 2>&1 | tee "$report.transfer.AES$key_size.${bytes}bytes.report")
        transfer=$(tail -1 "$report.transfer.AES${key_size}.${bytes}bytes.report" | awk '{print $2}')
        var_transfer="transfer_AES${key_size}_${bytes}bytes"
        echo "[Debug] Set variable '$var_transfer': [$var_transfer='$transfer']"
        eval "$var_transfer='$transfer'"
    done
    done

    ls -1 "$report"*"report" | sort
    handshake_rsa2048=$(tail -1 "$report.handshake.RSA2048.report" | awk '{print $(NF-1)}')
    handshake_ecdsa256=$(tail -1 "$report.handshake.ECDSA256.report" | awk '{print $(NF-1)}')
    transfer_aes128_128b="$transfer_AES128_128bytes"
    transfer_aes128_16k="$transfer_AES128_16384bytes"
    transfer_aes256_128b="$transfer_AES256_16384bytes"
    transfer_aes256_16k="$transfer_AES256_16384bytes"

    mkdir -p "${LOG_NAME}.RAW.Benchmarks"
    cp -v "$report."*".report" "${LOG_NAME}.RAW.Benchmarks"/
    
    summary_file="${LOG_NAME}.Benchmark.Summary.txt"
    printf "" > "$summary_file"
    printf "%-8s" "$openssl_version" >> "$summary_file"
    printf "%-12s" "$(Get-NET-RID)" >> "$summary_file"
    for var_name in handshake_rsa2048 handshake_ecdsa256 transfer_aes128_128b transfer_aes128_16k transfer_aes256_128b transfer_aes256_16k; do
      var="${!var_name}";
      var_formatted="$(Format-Thousand "$var")"
      printf "%16s" $var_formatted >> "$summary_file"
    done
    echo "" >> "$summary_file"
    Say "BENCHMARK SUMMARY"
    cat "$summary_file"
}

if [[ "$(hostname)" == *"container"* ]]; then
  url=https://raw.githubusercontent.com/devizer/glist/master/Install-Fake-UName.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
  Say "Final UNAME MACHINE: $(uname -m)"
else
  Say " Install-Fake-UName.sh skipped. HOSTNAME '$(hostname)' does not contain 'container'."
fi

work=$HOME/build/openssl-3.0; mkdir -p "$work"; cd "$work" && rm -rf *
# https://openssl-library.org/source/
ver=3.0.19
ver=3.5.5
ver=3.3.6
ver=3.4.4
ver=3.6.1
ver="${SSL_VERSION:-$ver}"
suffix="${ver%.*}"
url="https://github.com/openssl/openssl/releases/download/openssl-$ver/openssl-$ver.tar.gz"
file="_$(basename "$url")"
Download-File "$url" "$file"
tar xzf "$file"
cd openssl*
prefix=/usr/local/openssl-$suffix
Say "OpenSSL3 $ver Prefix: [$prefix]"
# ./Configure shared --prefix=/usr/local/openssl-$suffix
c99=""; [[ "$ver" == "3.6"* ]] && c99="-std=gnu99"
no_module="no-module" # get rid of ossl-modules/legacy.so
LOG_NAME="$SYSTEM_ARTIFACTSDIRECTORY/OpenSSL-$ver-$(Get-NET-RID)"
echo "LOG_NAME (a prefix) = [$LOG_NAME]"
if [[ "$(uname -m)" == "x86_64" ]]; then
    Say "Tune for SSE2 only with assembler on x64"
    ./Configure linux-x86_64 \
        shared \
        -march=x86-64 \
        $c99 $no_module \
        -mtune=generic \
        -mno-sse3 -mno-ssse3 -mno-sse4 -mno-sse4.1 -mno-sse4.2 \
        -mno-avx -mno-avx2 \
        --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "aarch64" ]]; then
    Say "TUNE ARM64"
    ./Configure linux-aarch64 shared no-asm no-tests -O2 $c99 $no_module --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == i?86 ]]; then
    Say "TUNE i686"
    # -march=pentium3 | -march=i686
    ./Configure linux-elf shared -march=pentium3 -m32 no-asm no-tests no-sse2 -O2 $c99 $no_module --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
elif [[ "$(uname -m)" == "armv7"* ]]; then
    Say "TUNE ARMv7l 32 bit"
    # -D__ARM_MAX_ARCH__=4 \
    # for 3.6 tests: -std=c99
    # AFALG engine is a bridge that allows OpenSSL to offload cryptographic operations to the Linux Kernel Crypto API
    ./Configure linux-armv4 shared \
         $c99 $no_module \
         -marm \
         no-tests \
         -mfloat-abi=hard \
         no-afalgeng \
         --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
else
    Say "Default shared Configuration"
   ./Configure shared $c99 $no_module --prefix=$prefix --openssldir=$prefix 2>&1 | tee ${LOG_NAME}.Configure.txt
fi
perl configdata.pm --dump 2>&1 | tee ${LOG_NAME}.config.data.log || true

time (make -j >/dev/null && { Say "MAKE SUCCESS. Running make install" || true; } && $sudo make install >/dev/null) 2>&1 && printf "%s" $prefix > $prefix/prefix.txt && printf $ver > $prefix/version.txt | tee ${LOG_NAME}.make.install.txt
# time make test
export LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64 
$prefix/bin/openssl version 2>&1 | tee ${LOG_NAME}.SHOW.VERSION.txt
Benchmark-OpenSSL "$prefix/bin/openssl"

export GZIP="-9"
Say "PACK FULL"
cd $prefix
cd ..
time tar czf ${LOG_NAME}.full.tar.gz "$(basename $prefix)"
tar cf - "$(basename $prefix)" | xz -9 > ${LOG_NAME}.full.tar.xz

Say "PACK BINARIES-ONLY"
cd $prefix
mkdir -p ~/only-so
find -name '*.so.3' | while IFD= read -r file; do cp -v "$file" ~/only-so/; done
cd ~/only-so
printf $(Get-NET-RID) | tee rid.txt
printf $ver | tee version.txt
tar czf ${LOG_NAME}.binaries-only.tar.gz *
tar cJf ${LOG_NAME}.binaries-only.tar.xz *

Say "PACK BINARIES-ONLY STRIPPED"
strip *.so*
tar czf ${LOG_NAME}.binaries-only.stripped.tar.gz *
tar cJf ${LOG_NAME}.binaries-only.stripped.tar.xz *


