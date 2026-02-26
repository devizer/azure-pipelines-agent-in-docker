set -eu; set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

Run-Remote-Script https://devizer.github.io/devops-library/install-libssl-1.1.1.sh --target-folder /opt/libssl-1.1.1 --register --first

Pre-Build-OpenSSL-Tests() {
  local net_ver="$1"
  base_folder=$HOME/openssl-tests
  dotnet_folder=$base_folder/dotnet/$net_ver
  Run-Remote-Script https://devizer.github.io/devops-library/install-dotnet.sh $net_ver --skip-linking --target-folder "$dotnet_folder" --skip-dependencies
  export PATH="$dotnet_folder:$PATH"

  test_source_folder=$base_folder/source/$net_ver/Test-OpenSSL
  mkdir -p "$test_source_folder"
  rm -rf "$test_source_folder"/* || true
  try-and-retry bash -e -c "rm -rf $test_source_folder/*; $dotnet_folder/dotnet new console -o $test_source_folder"
  echo "PUSHD $test_source_folder"
  ls -la $test_source_folder || true
  pushd $test_source_folder
  rm -f *.cs || true;
  cp -v $SCRIPT_DIR/Test-OpenSSL.cs ./
  success_list="";
  for rid in linux-x64 linux-arm64 linux-arm linux-musl-x64 linux-musl-arm64 linux-musl-arm; do
    Say "BUILDING .NET $net_ver OpenSSL Tests for $rid"
    df -h -T
    try-and-retry dotnet restore
    bin_dir=$base_folder/bin/$net_ver
    public_dir="$SYSTEM_ARTIFACTSDIRECTORY/$rid/$net_ver"
    try-and-retry dotnet publish -c Release -r $rid -o $bin_dir && { success_list="$success_list $rid"; mdkir -p $public_dir; cp -av "$bin_dir"/* public_dir; } || Say --Display-As=Error "RID $rid is not supported by .NET $net_ver"
  done
  success_list=$(echo "$success_list" | sed 's/^[[:space:]]*//')
  Say ".NET Built $(echo $success_list | wc -w) runtimes: $success_list"
  popd
}

export -f Pre-Build-OpenSSL-Tests

parallel --group --halt 0 "Pre-Build-OpenSSL-Tests {} 2>&1" ::: 2.1 3.0 3.1 5.0 6.0 7.0 8.0 9.0 10.0
