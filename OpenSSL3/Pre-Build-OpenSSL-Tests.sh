set -eu; set -o pipefail

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"

Run-Remote-Script https://devizer.github.io/devops-library/install-libssl-1.1.1.sh --target-folder /opt/libssl-1.1.1 --register --first

Pre-Build-OpenSSL-Tests() {
  local net_ver="$1"
  dotnet_folder=$base_folder/dotnet/$net_ver
  Say "STEP 0: Downloading [.NET $net_ver] into '$dotnet_folder'"
  Run-Remote-Script https://devizer.github.io/devops-library/install-dotnet.sh $net_ver --skip-linking --target-folder "$dotnet_folder" --skip-dependencies
  export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
  export PATH="$dotnet_folder:$PATH"
  sudo chown -R $(whoami) $base_folder

  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
  export SSL_CERT_DIR=/etc/ssl/certs
  export CLR_OPENSSL_VERSION_OVERRIDE="1.1"
  export DOTNET_OPENSSL_VERSION_OVERRIDE="1.1"
  
  test_source_folder=$base_folder/source/$net_ver/Test-OpenSSL
  mkdir -p "$test_source_folder"
  # sudo chown -R $(whoami) "$test_source_folder"
  rm -rf "$test_source_folder"/* || true
  # export LD_LIBRARY_PATH=/opt/libssl-1.1.1
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
    bin_dir=$base_folder/bin/$rid/$net_ver
    public_dir="$SYSTEM_ARTIFACTSDIRECTORY/$rid/$net_ver"
    try-and-retry $dotnet_folder/dotnet publish -c Release --self-contained -r $rid -o $bin_dir && { 
        success_list="$success_list $rid";
        mkdir -p $public_dir;
        cp -av "$bin_dir/." $public_dir;
        echo "SUCCESS: NET $net_ver for $rid" | tee $public_dir/Success.Log;
        Say "$(file $bin_dir/Test-OpenSSL || true)"
    } || Say --Display-As=Error "RID $rid is not supported by .NET $net_ver"
  done
  success_list=$(echo "$success_list" | sed 's/^[[:space:]]*//')
  Say ".NET $net_ver Built $(echo $success_list | wc -w) runtimes for OpenSSL Tests: $success_list"
  popd
}

export -f Pre-Build-OpenSSL-Tests

export base_folder=$HOME/openssl-tests

parallel --group --halt 0 -j 1 "Pre-Build-OpenSSL-Tests {} 2>&1" ::: 2.1 2.2 3.0 3.1 5.0 6.0 7.0 8.0 9.0 10.0

Say "Parallel Prebuild Complete"
find $SYSTEM_ARTIFACTSDIRECTORY -name Success.Log | sort | while IFS= read -r line; do cat $line | tee -a $SYSTEM_ARTIFACTSDIRECTORY/TOTAL.SUCCESS.LOG; done
