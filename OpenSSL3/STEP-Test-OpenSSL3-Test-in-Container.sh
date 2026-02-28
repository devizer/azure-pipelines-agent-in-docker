set -eu; set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

Say "Get-NET-RID = [$(Get-NET-RID)]";
Say "Get-Linux-OS-ID = [$(Get-Linux-OS-ID)]";
Say "Get-Linux-OS-Architecture = [$(Get-Linux-OS-Architecture)]";
Say "Get-Glibc-Version = [$(Get-Glibc-Version)]";
Say "ARTIFACT_NAME = [$ARTIFACT_NAME]";
Say "FOLDER: $(pwd -P)";


tests_folder_base="./OpenSSL-Tests/$(Get-NET-RID)"

cp -v /install-dotnet-dependencies.log $SYSTEM_ARTIFACTSDIRECTORY/
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

SYSTEM_OPENSSL_VERSION=$(openssl version | awk '{print $2}' || true)
summary_report_file="$SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.$(Get-NET-RID).TXT"
find $tests_folder_base -maxdepth 1 -type d | sort -V | while IFS= read -r folder; do
  net_ver="$(basename $folder)"
  if [[ ! $net_ver =~ ^[1-9] ]]; then continue; fi
  Say "Starting Testing .NET=[$net_ver] on arch=[$(Get-Linux-OS-Architecture)] OS=[$(Get-Linux-OS-ID)], RID='$(Get-NET-RID)' ..."
  JSON_REPORT_FILE="$SYSTEM_ARTIFACTSDIRECTORY/REPORT.NET-$net_ver.JSON"
  Set-Json-File-Property "$JSON_REPORT_FILE" "NET" "$net_ver"
  Set-Json-File-Property "$JSON_REPORT_FILE" "RID" "$(Get-NET-RID)"
  Set-Json-File-Property "$JSON_REPORT_FILE" "OS_ARCH" "$(Get-Linux-OS-Architecture)"
  Set-Json-File-Property "$JSON_REPORT_FILE" "OS_ID" "$(Get-Linux-OS-ID)"
  Set-Json-File-Property "$JSON_REPORT_FILE" "IMAGE" "$IMAGE"
  Set-Json-File-Property "$JSON_REPORT_FILE" "IMAGE_PLATFORM" "$IMAGE_PLATFORM"
  Set-Json-File-Property "$JSON_REPORT_FILE" "SYSTEM_OPENSSL_VERSION" "$SYSTEM_OPENSSL_VERSION"

  exe=$folder/Test-OpenSSL
  test_title="NET=${net_ver} ARCH=$(Get-Linux-OS-Architecture) RID=$(Get-NET-RID) OSID=$(Get-Linux-OS-ID) $ARTIFACT_NAME"
  log_name="$(Get-Safe-File-Name "$test_title")"
  # DEBUG
  Say-Definition "exe is" "$exe"
  ls -la "$exe" || true
  echo "test_title = [$test_title], log_name = [$log_name]"
  if [[ -n "$(command -v file)" ]]; then file "$exe" || true; fi
  if [[ -n "$(command -v file)" && -f $folder/libhostfxr.so ]]; then file "$folder/libhostfxr.so" || true; fi
  # End DEBUG
  LOG_FULL_NAME="$SYSTEM_ARTIFACTSDIRECTORY/$log_name"
  Colorize Magenta "STARTING TEST WITH DEFAULT OPENSSL: $test_title ... "
  pushd "$(dirname "$exe")" >/dev/null
  status_title="OK"
  if ! (echo "$test_title"; "./$(basename "$exe")") 2>&1 | tee -a "$LOG_FULL_NAME.Deafult.OpenSSL.log"; then
      Say --Display-As=Error "FAIL: $log_name"
      status_title="FAIL"
  fi
  popd >/dev/null
  echo "$(printf "%4s" "$status_title"): $test_title" | tee -a $summary_report_file
  Set-Json-File-Property "$JSON_REPORT_FILE" "STATUS" "$status_title"
  echo " "
done

find $SYSTEM_ARTIFACTSDIRECTORY -name 'REPORT.*.JSON' | sort -V | xargs jq -s '.' > $SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.REPORT.JSON

