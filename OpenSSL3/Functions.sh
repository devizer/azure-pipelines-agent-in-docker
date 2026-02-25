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

    mkdir -p "${LOG_NAME}.RAW.Benchmarks"
    cp -v "$report."*".report" "${LOG_NAME}.RAW.Benchmarks"/
    
    summary_file="${LOG_NAME}.Benchmark.Summary.txt"
    printf "" > "$summary_file"
    printf "%-8s" "$openssl_version" >> "$summary_file"
    printf "%-19s" "$(Get-NET-RID)" >> "$summary_file"
    printf "%-15s" "${COLUMN_TYPE:-}" >> "$summary_file"
    for var_name in handshake_rsa2048 handshake_ecdsa256 transfer_AES128_128bytes transfer_AES128_16384bytes transfer_AES256_128bytes transfer_AES256_16384bytes; do
      var="${!var_name}";
      var_formatted="$(Format-Thousand "$var")"
      format="%16s"; [[ "$var_name" == *"handshake"* ]] && format="%12s"
      printf "$format" $var_formatted >> "$summary_file"
    done
    echo "" >> "$summary_file"
    Say "BENCHMARK SUMMARY"
    cat "$summary_file"
}

Build-LIB-Atomic() {
   $sudo apt-get install build-essential perl xz-utils -y -q --force-yes
   local work=$HOME/build/gcc
   mkdir -p $work
   pushd $work
   local gcc_url="https://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz"
   Say "Downloading $gcc_url for $(gcc --version | head -1)"
   local cmd="wget -q -nv --no-check-certificate -O _gcc.tar.gz $gcc_url 2>/dev/null || curl -kfSL -o _gcc.tar.gz $gcc_url"
   eval $cmd || eval $cmd || eval $cmd
   cd $work; rm -rf gcc* || true
   tar xzf _gcc.tar.gz
   cd gcc-*/libatomic
   Say "gcc-*/libatomic folder: $(pwd -P)"
   make distclean || true
   mkdir build-atomic && cd build-atomic
   # ../configure --host=arm-linux-gnueabihf --with-pic CFLAGS="-O2 -fPIC" --enable-dependency-tracking
   ../configure --host=arm-linux-gnueabihf \
       --with-pic \
       CFLAGS="-O2 -fPIC" \
       ASFLAGS="-mfloat-abi=hard --fpic" \
       CPPFLAGS="-DPIC"

   time make -j$(nproc) install V=0
   nm .libs/libatomic.a | grep "_GLOBAL_OFFSET_TABLE_" || true
   Say "MAKE INSTALL LIB ATOMIC COMPLETE. Below is "
   objdump -r .libs/libatomic.a | grep -E "ABS|GOT|REL" | head -n 25 || true
   popd
}
