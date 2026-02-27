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

find find $tests_folder_base -maxdepth 1 -type d | while IFS= read -r net_ver; do
  Say "Testing .NET $net_ver on $(Get-Linux-OS-Architecture) $(Get-Linux-OS-ID), RID='$(Get-NET-RID)'"
  exe=$net_ver/Test-OpenSSL
  ls -la "$exe" || true
done

