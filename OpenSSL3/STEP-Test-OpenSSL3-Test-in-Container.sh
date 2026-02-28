set -eu; set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

Say "Get-NET-RID = [$(Get-NET-RID)]";
Say "Get-Linux-OS-ID = [$(Get-Linux-OS-ID)]";
Say "Get-Linux-OS-Architecture = [$(Get-Linux-OS-Architecture)]";
Say "Get-Glibc-Version = [$(Get-Glibc-Version)]";
Say "ARTIFACT_NAME = [$ARTIFACT_NAME]";
Say "FOLDER: $(pwd -P)";

system_ssl_so_file_list="$SYSTEM_ARTIFACTSDIRECTORY/System-Lib-SSL-SO-List.txt"
system_ssl_versions="$(Find-Lib-SSL-SO-Versions "$system_ssl_so_file_list")"
Colorize Cyan "SYSTEM LIBSSL BINARY VERSIONS: [$system_ssl_versions]"

tests_folder_base="./OpenSSL-Tests/$(Get-NET-RID)"

cp -v /install-dotnet-dependencies.log $SYSTEM_ARTIFACTSDIRECTORY/
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

SYSTEM_OPENSSL_VERSION=$(openssl version | awk '{print $2}' || true)
summary_report_file="$SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.$(Get-NET-RID).TXT"
Run-TestSSL-Array-On-NET-Matrix() {
    local test_suffix="$1"
    local exe_arguments="$2"
    local verify_mode="$3"
    local arg_ssl_version="$4"
    find $tests_folder_base -maxdepth 1 -type d | sort -V | while IFS= read -r folder; do
      echo " "
      net_ver="$(basename $folder)"
      if [[ ! $net_ver =~ ^[1-9] ]]; then continue; fi
      Say "Starting Testing .NET=[$net_ver] on arch=[$(Get-Linux-OS-Architecture)] OS=[$(Get-Linux-OS-ID)], RID='$(Get-NET-RID)' ..."
      JSON_REPORT_FILE="$SYSTEM_ARTIFACTSDIRECTORY/REPORT.NET-$net_ver.JSON"
      Set-Json-File-Property "$JSON_REPORT_FILE" "NET" "$net_ver"
      Set-Json-File-Property "$JSON_REPORT_FILE" "RID" "$(Get-NET-RID)"
      Set-Json-File-Property "$JSON_REPORT_FILE" "LIBC" "$(Get-LibC-Name)"
      Set-Json-File-Property "$JSON_REPORT_FILE" "OS_ARCH" "$(Get-Linux-OS-Architecture)"
      Set-Json-File-Property "$JSON_REPORT_FILE" "OS_ID" "$(Get-Linux-OS-ID)"
      Set-Json-File-Property "$JSON_REPORT_FILE" "IMAGE" "$IMAGE"
      Set-Json-File-Property "$JSON_REPORT_FILE" "IMAGE_PLATFORM" "$IMAGE_PLATFORM"
      Set-Json-File-Property "$JSON_REPORT_FILE" "SYSTEM_OPENSSL_VERSION" "$SYSTEM_OPENSSL_VERSION"
      Set-Json-File-Property "$JSON_REPORT_FILE" "SYSTEM_LIBSSL_VERSIONS" "$system_ssl_versions"

      exe=$folder/Test-OpenSSL
      test_title="$test_suffix NET=${net_ver} ARCH=$(Get-Linux-OS-Architecture) RID=$(Get-NET-RID) OSID=$(Get-Linux-OS-ID) $ARTIFACT_NAME"
      log_name="$(Get-Safe-File-Name "$test_title")"
      LOG_FULL_NAME="$SYSTEM_ARTIFACTSDIRECTORY/$log_name.$test_suffix.OpenSSL.log"
      # DEBUG
      Say-Definition "exe is" "$exe"
      ls -la "$exe" || true
      echo "test_title = [$test_title], log_name = [$log_name]"
      (
         echo "$test_title";
         if [[ -n "$(command -v file)" ]]; then file "$exe" || true; fi;
         if [[ -n "$(command -v file)" && -f $folder/libhostfxr.so ]]; then file "$folder/libhostfxr.so" || true; fi;
         echo "";
      ) 2>&1 | tee -a "$LOG_FULL_NAME"
      # End DEBUG
      Colorize Magenta "STARTING TEST WITH DEFAULT OPENSSL: $test_title ... "
      status_title="OK"
      if ! "$exe" $exe_arguments 2>&1 | tee -a "$LOG_FULL_NAME"; then
          Say --Display-As=Error "FAIL: $log_name"
          status_title="FAIL"
      fi
      echo "$(printf "%4s" "$status_title"): $test_title" | tee -a $summary_report_file
      # Set-Json-File-Property "$JSON_REPORT_FILE" "STATUS_DEFAULT" "$status_title"
      Set-Json-File-Test-Report "$JSON_REPORT_FILE" "TEST_${test_suffix}" "$verify_mode" "$arg_ssl_version" "$status_title"
    done
}

Run-TestSSL-Array-On-NET-Matrix "DEFAULTSSL_WITH_VALIDATION" "--validate-certificate" "ON" "DEFAULT"
Run-TestSSL-Array-On-NET-Matrix "DEFAULTSSL_WITHOUT_VALIDATION" "" "OFF" "DEFAULT"
Say "Deleting system libssl files"
cat "$system_ssl_so_file_list" | while IFS= read -r so_file; do
    Colorize Red "SKIP Deleting libssl so file [$so_file]"
    # Colorize Red "Deleting libssl so file [$so_file]"
    # rm -f "$so_file"
done
for ssl_version in $SSL_VERSIONS; do
    export LD_LIBRARY_PATH="$(pwd -P)/openssl-binaries/$(Get-NET-RID)/openssl-$ssl_version"
    Colorize Magenta "Content of LD_LIBRARY_PATH=[$LD_LIBRARY_PATH]"
    ls -la "$LD_LIBRARY_PATH"
    Run-TestSSL-Array-On-NET-Matrix "SSL_${ssl_version}_WITH_VALIDATION" "--validate-certificate" "ON" "$ssl_version"
    Run-TestSSL-Array-On-NET-Matrix "SSL_${ssl_version}_WITHOUT_VALIDATION" "" "OFF" "$ssl_version"
    export LD_LIBRARY_PATH=""
done


find $SYSTEM_ARTIFACTSDIRECTORY -name 'REPORT.*.JSON' | sort -V | xargs jq -s '.' > $SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.REPORT.JSON
Say "FINISH. SUMMARY Report"
# cat $SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.REPORT.JSON
