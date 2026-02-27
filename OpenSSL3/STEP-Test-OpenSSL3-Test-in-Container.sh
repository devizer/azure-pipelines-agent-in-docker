SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"


find find ./OpenSSL-Tests -maxdepth 1 -type d | while IFS= read -r net_ver; do
  Say "Testing .NET $net_ver on $(Get-Linux-OS-Architecture) $(Get-Linux-OS-ID), RID='$(Get-NET-RID)'"
  exe=$net_ver/Test-OpenSSL
  ls -la "$exe" || true
done

