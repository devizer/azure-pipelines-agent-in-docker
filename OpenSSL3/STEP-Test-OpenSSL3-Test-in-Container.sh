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

summary_report_file="$SYSTEM_ARTIFACTSDIRECTORY/SUMMARY.$(Get-NET-RID).TXT"
find $tests_folder_base -maxdepth 1 -type d | sort -V | while IFS= read -r folder; do
  net_ver="$(basename $folder)"
  if [[ ! $net_ver =~ ^[1-9] ]]; then continue; fi
  Say "Starting Testing .NET=[$net_ver] on arch=[$(Get-Linux-OS-Architecture)] OS=[$(Get-Linux-OS-ID)], RID='$(Get-NET-RID)' ..."
  exe=$folder/Test-OpenSSL
  Say-Definition "exe is" "$exe"
  if [[ -n "$(command -v file)" ]]; then file "$exe" || true; fi
  ls -la "$exe" || true
  test_title="NET=${net_ver} ARCH=$(Get-Linux-OS-Architecture) RID=$(Get-NET-RID) OSID=$(Get-Linux-OS-ID) $ARTIFACT_NAME"
  log_name="$(Get-Safe-File-Name "$test_title")"
  echo "log_name = [$log_name], test_title = [$test_title]"
  LOG_FULL_NAME="$SYSTEM_ARTIFACTSDIRECTORY/$log_name"
  Colorize Magenta "STARTING TEST WITH DEFAULT OPENSSL: $test_title ... "
  pushd "$(dirname "$exe")" >/dev/null
  status_title="  OK"
  (echo $test_title; "./$(basename "$exe")") 2>&1 | tee -a "$LOG_FULL_NAME.Deafult.OpenSSL.log" || (Say --Display-As=Error "FAIL: $log_name"; status_title=FAIL;)
  popd
  echo "$status_title: $test_title" | tee -a $summary_report_file
  echo " "
done

