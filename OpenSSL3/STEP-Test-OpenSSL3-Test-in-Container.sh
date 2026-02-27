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

find $tests_folder_base -maxdepth 1 -type d | while IFS= read -r folder; do
  net_ver="$(basename $folder)"
  Say "Testing .NET $net_ver on $(Get-Linux-OS-Architecture) $(Get-Linux-OS-ID), RID='$(Get-NET-RID)'"
  exe=$folder/Test-OpenSSL
  ls -la "$exe" || true
  log_name="$(Get-NET-RID)-$net_ver-$(Get-Linux-OS-ID)-$(Get-Linux-OS-Architecture)-$ARTIFACT_NAME"
  log_name="${log_name//:/-}"
  log_name="${log_name//\//-}"
  Colorize Magenta "log_name = [$log_name]"
  LOG_FULL_NAME="$SYSTEM_ARTIFACTSDIRECTORY/$log_name"
  Say "$log_name DEFAULT OPENSSL"
  $exe 2>&1 | tee "$LOG_FULL_NAME.Deafult.OpenSSL.log" || Say --Display-As=Error "FAIL: $log_name"
done

