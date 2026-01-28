set -eu; set -o pipefail;

Build-Net-Project-Single-RID() {
  set -eu; set -o pipefail;
  local target_dir="$1"
  local plain_dir="${2:-}"
  local dotnet_exe="${3:-dotnet}"
  local project_folder_full="${4}";
  local project_file="${5}"; 
  local project="${project_folder_full}/${project_file}"
  local project_version="$THE_PROJECT_VERSION"
  local rid="$6"
  local index="$7"
  local count="$8"
  local archive_name_only=$(printf "$THE_PROJECT_BINARY_FILE_PATTERN" "$rid")
  mkdir -p "$target_dir" 
  local target_dir_full="$(cd "$target_dir" && pwd -P)"
  mkdir -p "$plain_dir"
  local plain_dir_full="$(cd "$plain_dir" && pwd -P)"

  Say "#${index}/${count}: Building $archive_name_only binaries [$project_file at '$project_folder_full'] RID=$rid Ver '$project_version' --> [$target_dir_full/${archive_name_only}.*]"
  echo "   project folder (full): '$project_folder_full'"
  echo "   project file:          '$project_file'"
  echo "   dotnet:                '$dotnet_exe'"
  echo "   plain dir:             '$plain_dir'"
  echo "   plain dir full:        '$plain_dir_full'"
  echo "   compresses dir full:   '$target_dir_full'"
  echo "   compresses dir:        '$target_dir'"
  echo "   compression level:     '$COMPRESSION_LEVEL'"
  COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-9}"
  local tmp="${plain_dir_full}/$archive_name_only"
  mkdir -p "$tmp"
  pushd $project_folder_full >/dev/null
    # try-and-retry dotnet restore
    Colorize LightCyan "$dotnet_exe" publish "$project_folder_full/$project_file" --self-contained -r $rid -o "$tmp" -v:q -c Release ${THE_PROJECT_BUILD_PARAMETERS:-}
    local sem=""; [[ "${IN_PARALLEL:-}" == True ]] && sem="parallel --semaphore --fg --jobs 1 --id PUBLISH_LOCK"
    $sem try-and-retry "$dotnet_exe" publish "$project_folder_full/$project_file" --self-contained -r $rid -o "$tmp" -v:q -p:Version=$project_version -p:AssemblyVersion=$project_version -c Release ${THE_PROJECT_BUILD_PARAMETERS:-}

    printf $THE_PROJECT_VERSION > "$target_dir_full/VERSION.txt"
    local plain_size="$(Format-Thousand "$(Get-Folder-Size "$tmp")") bytes"
    local packed_size=""
    pushd "$tmp" >/dev/null
        if [[ -n "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}" ]]; then
          export THE_PROJECT_BINARIES="$tmp"
          export THE_PROJECT_RID="$rid"
          echo "Invoking after-publish hook (THE_PROJECT_BINARIES='$rid'; THE_PROJECT_BINARIES='$THE_PROJECT_BINARIES')"
          Colorize LightCyan "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}"
          eval "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}"
        fi
        if [[ "$rid" == "win"* ]]; then
          # zip
          printf "Packing $plain_size as $target_dir_full/${archive_name_only}.zip ... "
          rm -f "$target_dir_full/${archive_name_only}.zip"
          7z a -bso0 -bsp0 -tzip -mx=${COMPRESSION_LEVEL} "$target_dir_full/${archive_name_only}.zip" * | { grep "archive\|bytes" || true; }
          Colorize LightGreen "$(Format-Thousand "$(Get-File-Size "$target_dir_full/${archive_name_only}.zip")") bytes"
          # 7z
          printf "Packing $plain_size as $target_dir_full/${archive_name_only}.7z ... "
          rm -f "$target_dir_full/${archive_name_only}.7z"
          7z a -bso0 -bsp0 -t7z -mx=${COMPRESSION_LEVEL} -ms=on -mqs=on "$target_dir_full/${archive_name_only}.7z" * | { grep "archive\|bytes" || true; }
          Colorize LightGreen "$(Format-Thousand "$(Get-File-Size "$target_dir_full/${archive_name_only}.7z")") bytes"
        else
          # .tar.gz
          printf "Packing $plain_size as $target_dir_full/${archive_name_only}.tar.gz ... "
          tar cf - . | pigz -p $(nproc) -b 128 -${COMPRESSION_LEVEL}  > "$target_dir_full/${archive_name_only}.tar.gz"
          Colorize LightGreen "$(Format-Thousand "$(Get-File-Size "$target_dir_full/${archive_name_only}.tar.gz")") bytes"
          # .tar.xz
          printf "Packing $plain_size as $target_dir_full/${archive_name_only}.tar.xz ... "
          tar cf - . | 7za a dummy -txz -mx=${COMPRESSION_LEVEL} -si -so > "$target_dir_full/${archive_name_only}.tar.xz"
          Colorize LightGreen "$(Format-Thousand "$(Get-File-Size "$target_dir_full/${archive_name_only}.tar.xz")") bytes"
        fi
    popd >/dev/null

  popd >/dev/null
}
export -f Build-Net-Project-Single-RID
# linux-bionic-arm64, linux-bionic-x64: are not supported for asp.net core
export DEFAULT_RID_LIST="osx-x64 osx-arm64 win-x64 win-x86 win-arm64 linux-x64 linux-arm linux-arm64 linux-musl-x64 linux-musl-arm linux-musl-arm64"

# HASH SUMS
function build_all_known_hash_sums() {
  local dir="$1"
  local startAt=$(Get-Global-Seconds)
  local output="hash-sums.txt"
  pushd "$dir" >/dev/null
  rm -f "$output"
  local index=0;
  for file in *; do
    if [[ "$file" == "$output" ]]; then continue; fi
    index=$((index+1))
    echo "HASH for '$file' in [$(pwd -P)]"
    for alg in md5 sha1 sha224 sha256 sha384 sha512; do
      local hash=$(Get-Hash-Of-File "$alg" "$file")
      if [[ -n "$hash" ]]; then
        echo "$file|$alg|$hash" >> "$output"
      else
        echo "Warning! Hash Sum ${alg} app is missing"
      fi
    done
  done
  popd >/dev/null
  local now=$(Get-Global-Seconds)
  local seconds=$((now-startAt))
  Say "Hash sums for $index files at '$dir' built in $seconds second(s)"
}

Build-Net-Project-as-RID-Matrix() {
  local target_dir="$1"
  local plain_dir="${2:-}"
  local dotnet_exe="${3:-dotnet}"
  local project="${4}"
  local rid_list="${5:-$DEFAULT_RID_LIST}"
  
  local project_file=""; local project_folder="";
  if [[ -d "$project" ]]; then
    project_folder="$project"
    local ext
    for ext in csproj fsproj vbproj; do
      [[ -z "${project_file:-}" ]] && project_file=$(cd "$project_folder" 2>/dev/null && ls -1 *".$ext" 2>/dev/null | head -1)
    done
  elif [[ -f "$project" ]]; then
    project_file=$(basename "$project")
    project_folder=$(dirname "$project")
  else
    Say --Display-As=Error "Abort. Project '$project' not found. Either folder or csproj or fsproj or vbproj file should be specified"
    return 1;
  fi
  project_folder_full="$(cd "$project_folder" && pwd -P)"
  Say "Exclusive Restore for $project_folder_full/$project_file"
  try-and-retry dotnet restore "$project_folder_full/$project_file"
  local index=0
  local count=$(echo $rid_list | wc -w)
  export IN_PARALLEL=False
  if [[ -n "$(command -v parallel)" ]] && [[ "$(To-Boolean "Env Var DISABLE_PARALLEL_PUBLISH" "${DISABLE_PARALLEL_PUBLISH:-}")" == False ]] ; then
      echo "PARALLEL PUBLISH"
      local job_log=$(mktemp)
      # --halt soon,fail=1 means do not start new jobs if one failed
      export IN_PARALLEL=True
      local nproc=$(nproc)
      nproc=$((nproc+1))
      parallel --joblog "$job_log" --jobs $nproc Build-Net-Project-Single-RID \
          "$target_dir" \
          "$plain_dir" \
          "$dotnet_exe" \
          "$project_folder_full" \
          "$project_file" \
          {} \
          {#} \
          "$count" ::: $rid_list || { 
            Say --Display-As=Error "At least one build failed. Exit Code $?";
            awk '$7 != 0 {print "RID: " $(NF-2) " | ExitCode: " $7}' "$job_log" | column -t
            return 1; 
         }
  else
      echo "SERIALIZED PUBLISH"
      for rid in $(echo $rid_list); do
        index=$((index+1))
        Build-Net-Project-Single-RID "$target_dir" "$plain_dir" "$dotnet_exe" "$project_folder_full" "$project_file" "$rid" $index $count
      done
  fi
  build_all_known_hash_sums "$target_dir"
}

Test-Build-Matrix() {
  rm -rf ~/.nuget/packages/*
  rm -rf ~/.local/share/NuGet/http-cache
  Run-Remote-Script --runner "$(Get-Sudo-Command) bash" https://dot.net/v1/dotnet-install.sh --channel 10.0 -i "/tmp/dotnet10"
  Say --Reset-Stopwatch;
  export PATH="/tmp/dotnet10:$PATH"
  build=$(date +%s)
  build=$(($build % 10000))
  export THE_PROJECT_VERSION="42.$build"
  export THE_PROJECT_BINARY_FILE_PATTERN="app1-%s-daily"
  export THE_PROJECT_BUILD_PARAMETERS="-f NET10.0 -p:Version=${THE_PROJECT_VERSION} -p:AssemblyVersion=${THE_PROJECT_VERSION}"
  mkdir -p /tmp/MATRIX/testasp1
  rm -rf /tmp/MATRIX/testasp1/*
  dotnet new mvc -o /tmp/MATRIX/testasp1/
  export COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-9}"
  export THE_PROJECT_HOOK_AFTER_PUBLISH='x=77; echo Hello from hook for rid=$THE_PROJECT_RID\; binaries are located at "$THE_PROJECT_BINARIES"; df -h -T'

  rm -rf /tmp/MATRIX/testasp1-Release*
  # TEST1: full file path
  pushd ~ >/dev/null
  Build-Net-Project-as-RID-Matrix "/tmp/MATRIX/testasp1-Release-v1" "/tmp/MATRIX/testasp1/bin/v1" "dotnet" "/tmp/MATRIX/testasp1" "$DEFAULT_RID_LIST"
  popd >/dev/null

  # TEST2: relative file path
  pushd /tmp/MATRIX >/dev/null
  export COMPRESSION_LEVEL=1
  Build-Net-Project-as-RID-Matrix "./testasp1-Release-v2" "testasp1/bin/v2" "dotnet" "testasp1" "$DEFAULT_RID_LIST"
  popd >/dev/null

}

# Test-Build-Matrix; Say "Done: All the tests"
