set -eu; set -o pipefail;


if false; then
  [[ -z "$(command -v parallel)" ]] && Run-Remote-Script https://raw.githubusercontent.com/devizer/glist/master/Install-GNU-Parallel.sh
  # linux-bionic-arm64, linux-bionic-x64: are not supported for asp.net core
  export DEFAULT_RID_LIST="osx-x64 osx-arm64 win-x64 win-x86 win-arm64 linux-x64 linux-arm linux-arm64 linux-musl-x64 linux-musl-arm linux-musl-arm64"
  export DISABLE_PARALLEL_PUBLISH=false
  export KEEP_PLAIN_BINARIES=false
  export THE_PROJECT_VERSION="42.7"
  export THE_PROJECT_BINARY_FILE_PATTERN="app1-%s-daily"
  export THE_PROJECT_BUILD_PARAMETERS="-f NET10.0 -p:Version=${THE_PROJECT_VERSION} -p:AssemblyVersion=${THE_PROJECT_VERSION}"
  export THE_PROJECT_HOOK_AFTER_PUBLISH='cp -v ~/licence.txt $THE_PROJECT_BINARIES/'
  export COMPRESSION_LEVEL=9
fi


get_heavy_compression_level() {
  # for 32-bit OS compression level for XZ and 7Z maximum is 6, about 34 Mb ram for extract
  local rid="$1"
  local max_compression_level=9
  if [[ "$rid" == "win-x86" || "$rid" == "linux-arm" || "$rid" == "win-arm" || "$rid" == "a 32-bit" ]]; then max_compression_level=6; fi
  local heavy_compression_level=$COMPRESSION_LEVEL
  if [ "$max_compression_level" -lt "$heavy_compression_level" ]; then
      heavy_compression_level=$max_compression_level
      echo "[Info] Compression Level for RID = '$rid' is reduced from $COMPRESSION_LEVEL to $heavy_compression_level in case of 7z and xz archives" >&2
  fi
  echo "$heavy_compression_level"
}

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

  COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-9}"
  local heavy_compression_level=$(get_heavy_compression_level "$rid")

  Say "#${index}/${count}: Building $archive_name_only binaries [$project_file at '$project_folder_full'] RID=$rid Ver '$project_version' --> [$target_dir_full/${archive_name_only}.*]"
  echo "   project file:          '$project_file'"
  echo "   project folder (full): '$project_folder_full'"
  echo "   plain dir:             '$plain_dir'"
  echo "   plain dir full:        '$plain_dir_full'"
  echo "   release dir:           '$target_dir'"
  echo "   release dir full:      '$target_dir_full'"
  echo "   compression level:     '$COMPRESSION_LEVEL'"
  echo "   dotnet:                '$dotnet_exe'"
  local tmp="${plain_dir_full}/$archive_name_only"
  mkdir -p "$tmp"
  local startAt; local seconds;
  pushd $project_folder_full >/dev/null
    # try-and-retry dotnet restore
    Colorize LightCyan "$dotnet_exe" publish "$project_folder_full/$project_file" --self-contained -r $rid -o "$tmp" -v:q -c Release ${THE_PROJECT_BUILD_PARAMETERS:-}
    local sem=""; [[ "${IN_PARALLEL:-}" == True ]] && sem="parallel --semaphore --fg --jobs 1 --id PUBLISH_LOCK"
    startAt=$(Get-Global-Seconds)
    $sem try-and-retry "$dotnet_exe" publish "$project_folder_full/$project_file" --self-contained -r $rid -o "$tmp" -v:q -p:Version=$project_version -p:AssemblyVersion=$project_version -c Release $(echo ${THE_PROJECT_BUILD_PARAMETERS:-})
    seconds=$(( $(Get-Global-Seconds) - startAt ))
    printf "Self Contained '$rid' binaries are built "; Colorize Green "by $seconds seconds"

    printf $THE_PROJECT_VERSION > "$target_dir_full/VERSION.txt"
    printf $THE_PROJECT_VERSION > "$tmp/VERSION.txt"
    local plain_size="$(Format-Thousand "$(Get-Folder-Size "$tmp")") bytes"
    pushd "$tmp" >/dev/null
        if [[ -n "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}" ]]; then
          export THE_PROJECT_BINARIES="$tmp"
          export THE_PROJECT_RID="$rid"
          echo "Invoking after-publish hook (RID='$rid'; THE_PROJECT_BINARIES='$THE_PROJECT_BINARIES')"
          Colorize LightCyan "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}"
          eval "${THE_PROJECT_HOOK_AFTER_PUBLISH:-}"
        fi
        if [[ "$rid" == "win"* ]]; then
          Compress-Distribution-Folder "zip" "${COMPRESSION_LEVEL}" "$tmp" "$target_dir_full/${archive_name_only}.zip" --low-priority
          Compress-Distribution-Folder "7z" "${heavy_compression_level}" "$tmp" "$target_dir_full/${archive_name_only}.7z" --low-priority
        else
          Compress-Distribution-Folder "tar.gz" "${COMPRESSION_LEVEL}" "$tmp" "$target_dir_full/${archive_name_only}.tar.gz" --low-priority
          Compress-Distribution-Folder "tar.xz" "${heavy_compression_level}" "$tmp" "$target_dir_full/${archive_name_only}.tar.xz" --low-priority
        fi
    popd >/dev/null
    if [[ "$(Is-Microsoft-Hosted-Build-Agent)" == True ]] && [[ "$(To-Boolean "Env Var KEEP_PLAIN_BINARIES" "${KEEP_PLAIN_BINARIES:-}")" == False ]]; then rm -rf "$tmp"; fi

  popd >/dev/null
}

if [[ -z "${ZSH_VERSION:-}" ]]; then
  # parallel mode is available for bash only
  export -f Build-Net-Project-Single-RID
else
  # require zsh 4.3.10 Jun 2009
  setopt SH_WORD_SPLIT # avoid $(echo $var)
  setopt KSH_ARRAYS # base index is 0
  emulate bash
  export DISABLE_PARALLEL_PUBLISH=true
fi

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
  
  mkdir -p "$target_dir" 
  local target_dir_full="$(cd "$target_dir" && pwd -P)"

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

  Say "Exclusive Restore for $project_folder_full/$project_file ..."
  try-and-retry dotnet restore "$project_folder_full/$project_file"

  Say "Publish FX-Dependent binaries ..."
  mkdir -p "$plain_dir"
  local plain_dir_full="$(cd "$plain_dir" && pwd -P)"
  local archive_name_only=$(printf "$THE_PROJECT_BINARY_FILE_PATTERN" "fxdependent")
  startAt=$(Get-Global-Seconds)
  tmp="$plain_dir_full"/"$archive_name_only"
  try-and-retry "$dotnet_exe" publish "$project_folder_full/$project_file" -o "$tmp" -v:q -c Release $(echo ${THE_PROJECT_BUILD_PARAMETERS:-})
  seconds=$(( $(Get-Global-Seconds) - startAt ))
  printf "FX-Dependent binaries built by "; Colorize Green "$seconds seconds"
  printf $THE_PROJECT_VERSION > "$tmp/VERSION.txt"
  pushd "$tmp" >/dev/null
    # rm -f "$target_dir_full/${archive_name_only}."{zip,7z}
    startAt=$(Get-Global-Seconds)
    Compress-Distribution-Folder "zip" "${COMPRESSION_LEVEL}" "$tmp" "$target_dir_full/${archive_name_only}.zip" --normal-priority
    Compress-Distribution-Folder "7z" "$(get_heavy_compression_level "a 32-bit")" "$tmp" "$target_dir_full/${archive_name_only}.7z" --normal-priority
    Compress-Distribution-Folder "tar.gz" "${COMPRESSION_LEVEL}" "$tmp" "$target_dir_full/${archive_name_only}.tar.gz" --normal-priority
    Compress-Distribution-Folder "tar.xz" "$(get_heavy_compression_level "a 32-bit")" "$tmp" "$target_dir_full/${archive_name_only}.tar.xz" --normal-priority
    # tar cf - . | pigz -p $(nproc) -b 128 -${COMPRESSION_LEVEL}  > "$target_dir_full/${archive_name_only}.tar.gz"; 
    # 7z a -bso0 -bsp0 -tzip -mx=${COMPRESSION_LEVEL} "$target_dir_full/${archive_name_only}.zip" * | { grep "archive\|bytes" || true; }; 
    # 7z a -bso0 -bsp0 -t7z -mx=$(get_heavy_compression_level "a 32-bit") -m0=LZMA -ms=on -mqs=on "$target_dir_full/${archive_name_only}.7z" * | { grep "archive\|bytes" || true; }; 
    # tar cf - . | 7z a dummy -txz -mx=$(get_heavy_compression_level "a 32-bit") -si -so > "$target_dir_full/${archive_name_only}.tar.xz";
    # wait
    seconds=$(( $(Get-Global-Seconds) - startAt ))
  popd >/dev/null
  printf "FX-Dependent binaries compressed by "; Colorize Green "$seconds seconds"

  local index=0
  local count=$(echo $rid_list | wc -w)
  export IN_PARALLEL=False
  if [[ -n "$(command -v parallel)" ]] && [[ "$(To-Boolean "Env Var DISABLE_PARALLEL_PUBLISH" "${DISABLE_PARALLEL_PUBLISH:-}")" == False ]] ; then
      echo "Starting PARALLEL PUBLISH .."
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
      echo "Starting SERIALIZED PUBLISH ..."
      for rid in $(echo $rid_list); do
        index=$((index+1))
        Build-Net-Project-Single-RID "$target_dir" "$plain_dir" "$dotnet_exe" "$project_folder_full" "$project_file" "$rid" $index $count
      done
  fi
  build_all_known_hash_sums "$target_dir"
  Say "Final Release folder '$target_dir_full', $(Format-Thousand "$(Get-Folder-Size "$target_dir_full")") bytes"
  ls -lah "$target_dir_full"
}

Test-Build-Matrix() {
  rm -rf ~/.nuget/packages/* || true # zsh workaround
  rm -rf ~/.local/share/NuGet/http-cache || true
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
  export THE_PROJECT_HOOK_AFTER_PUBLISH='x=77; echo Hello from hook for rid=$THE_PROJECT_RID\; binaries are located at "$THE_PROJECT_BINARIES"; df -h -T 2>/dev/null || df -h'

  rm -rf /tmp/MATRIX/testasp1-Release*
  # TEST1: full file path
  pushd ~ >/dev/null
  time Build-Net-Project-as-RID-Matrix "/tmp/MATRIX/testasp1-Release-v1" "/tmp/MATRIX/testasp1/bin/v1" "dotnet" "/tmp/MATRIX/testasp1" "$DEFAULT_RID_LIST"
  popd >/dev/null

  # TEST2: relative file path
  pushd /tmp/MATRIX >/dev/null
  export COMPRESSION_LEVEL=1
  # Build-Net-Project-as-RID-Matrix "./testasp1-Release-v2" "testasp1/bin/v2" "dotnet" "testasp1" "$DEFAULT_RID_LIST"
  popd >/dev/null

}

# Test-Build-Matrix; Say "Done: All the tests"
