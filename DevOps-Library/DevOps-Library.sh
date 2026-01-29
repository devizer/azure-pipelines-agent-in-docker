#!/usr/bin/env bash
# V1
# file=/usr/local/bin/DevOps-Library.sh; sudo mkdir -p "$(dirname "$file")" 2>/dev/null; url=https://raw.githubusercontent.com/devizer/glist/master/DevOps-Lib.sh; (wget -q -nv --no-check-certificate -O "$file" $url 2>/dev/null || curl -o "$file" -ksSL $url); . $file; printf "\n\ntest -f $file && . $file" >> ~/.bashrc
set -eu; set -o pipefail

# Include Directive: [ ..\Includes\*.sh ]
# Include File: [\Includes\Clean-Up-My-Temp-Folders-and-Files-on-Exit.sh]
# https://share.google/aimode/a99XJQA3NtxMUcjWi

Clean-Up-My-Temp-Folders-and-Files-on-Exit() {
  local template="${1:-clean.up.list.txt}"
  if [[ -z "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}" ]]; then
     # secondary call is ignored, but clean up queue is not lost
    _DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST="$(MkTemp-File-Smarty "$template")"
    trap clean_up_my_temp_folders_and_files_on_exit_implementation EXIT INT TERM PIPE
  fi
}

clean_up_my_temp_folders_and_files_on_exit_implementation() {
  local last_status=$?
  trap - EXIT INT TERM PIPE

  set +e; # case of broken pipe
  local todoFile="${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}"
  _DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST=""
  # Clean up
  if [[ -f "$todoFile" ]]; then
    [[ -n "${DEBUG_CLEAN_UP_MY_TEMP_FOLDERS_AND_FILES_ON_EXIT:-}" ]] && echo "CLENEAN UP using '$todoFile' to-do list"
    cat "$todoFile" | while IFS= read -r line; do
      [[ -n "${DEBUG_CLEAN_UP_MY_TEMP_FOLDERS_AND_FILES_ON_EXIT:-}" ]] && echo "DELETING '$line'"
      if [[ -f "$line" ]]; then rm -f  "$line" 2>/dev/null; fi
      if [[ -d "$line" ]]; then rm -rf "$line" 2>/dev/null; fi
    done
    [[ -n "${DEBUG_CLEAN_UP_MY_TEMP_FOLDERS_AND_FILES_ON_EXIT:-}" ]] && echo "DELETING '$todoFile'"
    rm -f "$todoFile" 2>/dev/null
  fi

  exit "$last_status"
}

# Include File: [\Includes\Colorize.sh]
# say Green|Yellow|Red Hello World without quotes
Colorize() { 
   local str1st="${1:-}"
   str1st="$(To-Lower-Case "$str1st")"
   local newLine="\n"
   if [[ "$str1st" == "--nonewline" ]] || [[ "$str1st" == "-nonewline" ]]; then newLine=""; shift; fi
   
   local NC='\033[0m' Color_White='\033[1;37m' Color_Black='\033[1;30m' \
         Color_Red='\033[1;31m' Color_Green='\033[1;32m' Color_Yellow='\033[1;33m' Color_Blue='\033[1;34m' Color_Magenta='\033[1;35m' Color_Cyan='\033[1;36m' \
         Color_LightRed='\033[0;31m' Color_LightGreen='\033[0;32m' Color_LightYellow='\033[0;33m' Color_LightBlue='\033[0;34m' Color_LightMagenta='\033[0;35m' Color_LightCyan='\033[0;36m' Color_LightWhite='\033[0;37m' \
         Color_Purple='\033[0;35m' Color_LightPurple='\033[1;35m'
   # local var="Color_${1:-}"
   # local color=""; [[ -n ${!var+x} ]] && color="${!var}"
   local color="$(eval "printf '%s' \"\$Color_${1:-}\"" 2>/dev/null)"
   shift || true
   if [[ "$(To-Boolean "Env Var DISABLE_COLOR_OUTPUT" "${DISABLE_COLOR_OUTPUT:-}")" == True ]]; then
     printf "$*${newLine}";
   else
     printf "${color:-}$*${NC}${newLine}";
   fi
}
# say ZZZ the-incorrect-color

# Include File: [\Includes\Compress-Distribution-Folder.sh]
# 1) 7z v9.20 is not supported
# 2) type is 7z|gz|xz|zip
Compress-Distribution-Folder() {
  local type="$1"
  local compression_level="$2"
  local source_folder="$3"
  local target_file="$4"
  local arg_low_priority="$(To-Lower-Case "${5:-}")"
  local is_low_priority=False; [[ "$arg_low_priority" == "--low"* ]] && is_low_priority=True;

  local plain_size="$(Format-Thousand "$(Get-Folder-Size "$source_folder")") bytes"
  local nice_title="";
  local nice=""; [[ "$is_low_priority" == True && "$(command -v nice)" ]] && nice="nice -n 1" && nice_title=" (low priority)"

  if [[ ! -d "$source_folder" ]]; then 
    Say --Display-As=Error "[Compress-Folder] Abort. Source folder '$source_folder' is missing"
    return 1;
  fi

  mkdir -p "$(dirname "$target_file" 2>/dev/null)" 2>/dev/null
  local target_file_full="$(cd "$(dirname "$target_file")"; pwd -P)/$(basename "$target_file")"

  pushd "$source_folder" >/dev/null
      # echo "[DEBUG] target_file_full = '$target_file_full'"
      printf "Packing $source_folder ($plain_size) as ${target_file_full}${nice_title} ... "
      [[ -f "$target_file_full" ]] && rm -f "$target_file_full" || true
      local startAt=$(Get-Global-Seconds)
      if [[ "$type" == "zip" ]]; then
        $nice 7z a -bso0 -bsp0 -tzip -mx=${compression_level} "$target_file_full" * | { grep "archive\|bytes" || true; }
      elif [[ "$type" == "7z" ]]; then
        $nice 7z a -bso0 -bsp0 -t7z -mx=${compression_level} -m0=LZMA -ms=on -mqs=on "$target_file_full" * | { grep "archive\|bytes" || true; }
      elif [[ "$type" == "gzip" || "$type" == "tgz" || "$type" == "tar.gz" ]]; then
        if [[ -n "$(command -v pigz)" ]]; then
          tar cf - . | $nice pigz -p $(nproc) -b 128 -${compression_level} > "$target_file_full"
        else
          tar cf - . | $nice gzip -${compression_level} > "$target_file_full"
        fi
      elif [[ "$type" == "xz" || "$type" == "txz" || "$type" == "tar.xz" ]]; then
        tar cf - . | $nice 7z a dummy -txz -mx=${compression_level} -si -so > "$target_file_full"
      else
        Say --Display-As=Error "Abort. Unknown archive type '$type' for folder '$source_folder'"
      fi
      local seconds=$(( $(Get-Global-Seconds) - startAt ))
      local seconds_string="$seconds seconds"; [[ "$seconds" == "1" ]] && seconds_string="1 second"

      Colorize LightGreen "$(Format-Thousand "$(Get-File-Size "$target_file_full")") bytes (took $seconds_string)"
  popd >/dev/null
}

# Include File: [\Includes\Download-File.sh]
Download-File() {
  local url="$1"
  local file="$2";
  local progress1="" progress2="" progress3="" 
  local download_show_progress="$(To-Boolean "Env Var DOWNLOAD_SHOW_PROGRESS" "${DOWNLOAD_SHOW_PROGRESS:-}")"
  if [[ "${download_show_progress}" != "True" ]] || [[ ! -t 1 ]]; then
    progress1="-q -nv"       # wget
    progress2="-s"           # curl
    progress3="--quiet=true" # aria2c
  fi
  rm -f "$file" 2>/dev/null || rm -f "$file" 2>/dev/null || rm -f "$file"
  mkdir -p "$(dirname "$file" 2>/dev/null)" 2>/dev/null || true
  local try1=""
  if [[ "$(command -v aria2c)" != "" ]]; then
    [[ -n "${try1:-}" ]] && try1="$try1 || "
    try1="aria2c $progress3 --allow-overwrite=true --check-certificate=false -s 9 -x 9 -k 1M -j 9 -d '$(dirname "$file")' -o '$(basename "$file")' '$url'"
  fi
  if [[ "$(command -v curl)" != "" ]]; then
    [[ -n "${try1:-}" ]] && try1="$try1 || "
    try1="${try1:-} curl $progress2 -f -kfSL -o '$file' '$url'"
  fi
  if [[ "$(command -v wget)" != "" ]]; then
    [[ -n "${try1:-}" ]] && try1="$try1 || "
    try1="${try1:-} wget $progress1 --no-check-certificate -O '$file' '$url'"
  fi
  if [[ "${try1:-}" == "" ]]; then
    echo "error: niether curl, wget or aria2c is available" >&2
    return 42;
  fi
  eval $try1 || eval $try1 || eval $try1
  # eval try-and-retry wget $progress1 --no-check-certificate -O '$file' '$url' || eval try-and-retry curl $progress2 -kSL -o '$file' '$url'
}

# Include File: [\Includes\Download-File-Failover.sh]
Download-File-Failover() {
  local file="$1"
  shift
  for url in "$@"; do
    # DEBUG: echo -e "\nTRY: [$url] for [$file]"
    local err=0;
    Download-File "$url" "$file" || err=$?
    # DEBUG: say Green "Download status for [$url] is [$err]"
    if [ "$err" -eq 0 ]; then return; fi
  done
  return 55;
}

# Include File: [\Includes\Extract-Archive.sh]
# archive-file and toFolder support relative paths
Extract-Archive() {
  local file="$1"
  local toFolder="$2"
  local needResetFolder=""
  [[ "$(To-Lower-Case "${3:-}")" =~ ^-[-]?reset ]] && needResetFolder=True
  local fullFilePath="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  
  local sudo="sudo"; [[ -z "$(command -v sudo)" || "$(Get-OS-Platform)" == Windows ]] && sudo=""
  $sudo mkdir -p "$toFolder" 2>/dev/null
  pushd "$toFolder" >/dev/null
  if [[ "$needResetFolder" == True ]]; then $sudo rm -f -r "$toFolder"/*; fi
  local fileLower="$(To-Lower-Case "$file")"
  local cat="cat"; [[ -n "$(command -v pv)" ]] && [[ "$(Get-OS-Platform)" != Windows ]] && cat="pv"
  # echo "[DEBUG] cat is '$cat'"
  local cmdExtract
  if [[ "$fileLower" == *".tar.gz" || "$fileLower" == *".tgz" ]]; then
    # Important: On windows we avoid tar archives
    cmdExtract="gzip -f -d"
    $cat "$fullFilePath" | eval $cmdExtract | $sudo tar xf - 2>&1 | { grep -v "implausibly old time stamp" || true; } | { grep -v "in the future" || true; }
  elif [[ "$fileLower" == *".tar.xz" || "$fileLower" == *".txz" ]]; then
    # Important: On windows we avoid tar archives
    cmdExtract="xz -f -d"
    $cat "$fullFilePath" | eval $cmdExtract | $sudo tar xf - 2>&1 | { grep -v "implausibly old time stamp" || true; } | { grep -v "in the future" || true; }
  elif [[ "$fileLower" == *".zip" ]]; then
    $sudo unzip -q -o "$fullFilePath"
  elif [[ "$fileLower" == *".7z" ]]; then
    # todo: 7z 9.x does not support -bso0 -bsp0
    $sudo 7z x -y -bso0 -bsp0 "$fullFilePath"
  else
    popd >/dev/null
    echo "Unable to extract '$file' based on its extension"
    return 1
  fi

  popd >/dev/null
}

# Include File: [\Includes\Fetch-Distribution-File.sh]
Fetch-Distribution-File() {
  local productId="$1"
  local fileNameOnly="$2"
  local fullFileName="$3"
  local urlHashList="$4"
  local urlFileList="$5"

  local tempRoot="$(MkTemp-Folder-Smarty "$productId Setup Metadata")"
  local hashSumsFile="$(MkTemp-File-Smarty "hash-sums.txt" "$tempRoot")"

  local hashAlg="$(EXISTING_HASH_ALGORITHMS="sha512 sha384 sha256 sha224 sha1 md5" Find-Hash-Algorithm)"
  DEFINITION_COLOR=Default Say-Definition "Hash Algorithm:" "$hashAlg"

  Download-File-Failover "$hashSumsFile" "$urlHashList"
  Validate-File-Is-Not-Empty "$hashSumsFile" "The hash sum downloaded as %s, the size is" "Error! download of hash sums failed"

  local hashValueFile="$(MkTemp-File-Smarty "$productId $hashAlg hash.txt" "$tempRoot")"
  cat "$hashSumsFile" | while IFS="|" read -r file alg hashValue; do
    # echo "$file *** $alg *** $hashValue"
    if [[ "$file" == "$fileNameOnly" ]] && [[ "$alg" == "$hashAlg" ]]; then printf "$hashValue" > "$hashValueFile"; echo "TEMP HASH VALUE = [$hashValue]" >/dev/null; fi
  done
  local targetHash="$(cat "$hashValueFile" 2>/dev/null)"
  DEFINITION_COLOR=Default Say-Definition "Valid  Hash Value:" "$targetHash"

  # split "$urlFileList" into array
  local tmp="$(mktemp)"
  echo "$urlFileList" | awk -F"|" '{for (i=1; i<=NF; i++) print $i}' 2>/dev/null > "$tmp"
  urls=(); while IFS= read -r line; do [[ -n "$line" ]] && urls+=("$line"); done < "$tmp"
  rm -f "$tmp" 2>/dev/null || true
  Download-File-Failover "$fullFileName" "${urls[@]}"
  Validate-File-Is-Not-Empty "$fullFileName" "The binary archive succesfully downloaded as %s, the size is" "Error! download of binary archive failed"

  local actualHash="$(Get-Hash-Of-File "$hashAlg" "$fullFileName")"
  DEFINITION_COLOR=Default Say-Definition "Actual Hash Value:" "$targetHash"

  local toDelete
  for toDelete in "$hashSumsFile" "$hashValueFile"; do
    rm -f "$toDelete" 2>/dev/null || true
    # rm -rf "$(dirname "$toDelete")" 2>/dev/null || true
  done
  
  if [[ "$actualHash" == "$targetHash" ]]; then
    Colorize Green "Hash matches. Download successfully completed"
  else
    Colorize Red "Error! Hash does not match. Download failed"
    return 13
  fi
}

# Include File: [\Includes\Find-7z-For-Unpack.sh]
Print_Standard_Archive_zip() { printf '\x50\x4B\x03\x04\x0A\x00\x00\x00\x00\x00\x6B\x54\x39\x5C\x88\xB0\x24\x32\x02\x00\x00\x00\x02\x00\x00\x00\x06\x00\x00\x00\x61\x63\x74\x75\x61\x6C\x34\x32\x50\x4B\x01\x02\x3F\x00\x0A\x00\x00\x00\x00\x00\x6B\x54\x39\x5C\x88\xB0\x24\x32\x02\x00\x00\x00\x02\x00\x00\x00\x06\x00\x24\x00\x00\x00\x00\x00\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x61\x63\x74\x75\x61\x6C\x0A\x00\x20\x00\x00\x00\x00\x00\x01\x00\x18\x00\x80\x2A\xC5\x8A\xD5\x8D\xDC\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x50\x4B\x05\x06\x00\x00\x00\x00\x01\x00\x01\x00\x58\x00\x00\x00\x26\x00\x00\x00\x00\x00'; }
Print_Standard_Archive_7z() { printf '\x37\x7A\xBC\xAF\x27\x1C\x00\x04\xB3\x31\x1B\x27\x07\x00\x00\x00\x00\x00\x00\x00\x5A\x00\x00\x00\x00\x00\x00\x00\xDB\x6D\x60\xB0\x00\x1A\x0C\x7C\x00\x00\x00\x01\x04\x06\x00\x01\x09\x07\x00\x07\x0B\x01\x00\x01\x23\x03\x01\x01\x05\x5D\x00\x10\x00\x00\x0C\x02\x00\x08\x0A\x01\x88\xB0\x24\x32\x00\x00\x05\x01\x19\x06\x00\x00\x00\x00\x00\x00\x11\x0F\x00\x61\x00\x63\x00\x74\x00\x75\x00\x61\x00\x6C\x00\x00\x00\x19\x04\x00\x00\x00\x00\x14\x0A\x01\x00\x80\x2A\xC5\x8A\xD5\x8D\xDC\x01\x15\x06\x01\x00\x20\x00\x00\x00\x00\x00'; }
Print_Standard_Archive_gz() { printf '\x1F\x8B\x08\x00\x35\xE5\x75\x69\x04\x00\x01\x02\x00\xFD\xFF\x34\x32\x88\xB0\x24\x32\x02\x00\x00\x00'; }
Print_Standard_Archive_xz() { printf '\xFD\x37\x7A\x58\x5A\x00\x00\x01\x69\x22\xDE\x36\x02\x00\x21\x01\x00\x00\x00\x00\x37\x27\x97\xD6\x01\x00\x01\x34\x32\x00\x00\x00\x88\xB0\x24\x32\x00\x01\x16\x02\xD0\x61\x10\xD2\x90\x42\x99\x0D\x01\x00\x00\x00\x00\x01\x59\x5A'; }

Find-7z-For-Unpack() {
  local ext="$(To-Lower-Case "${1:-}")"
  local tempFolder="$(MkTemp-Folder-Smarty "7z-unpack-probe.$ext")"
  local tempFile="$tempFolder/actual.$ext"
  eval Print_Standard_Archive_$ext > "$tempFile" 2>/dev/null
  local candidates="7z 7zz 7zzs 7za 7zr";
  local ret="";
  for candidate in $(echo $candidates); do
    local err=""
    $candidate x -y "$tempFile" -o"$tempFolder/output" >/dev/null 2>&1 || err=err
    if [[ -n "$err" ]]; then continue; fi
    # local outputFile=$(ls -1 "$tempFolder/output/" 2>/dev/null)
    local outputFile=actual
    if [[ -z "$outputFile" ]]; then continue; fi
    local outputFileFull="$tempFolder/output/$outputFile"
    if [[ ! -f "$outputFileFull" ]]; then continue; fi
    local expected42=$(cat "$tempFolder/output/$outputFile")
    if [[ "$expected42" == "42" ]]; then ret="$candidate"; break; fi
  done
  rm -rf "$tempFolder" 2>/dev/null || rm -rf "$tempFolder" 2>/dev/null || true
  echo "$ret"
}

# Include File: [\Includes\Find-Decompressor.sh]
function Find-Decompressor() {
  local COMPRESSOR_EXT=''
  local COMPRESSOR_EXTRACT=''
  local force_fast_compression="$(To-Boolean "Env Var FORCE_FAST_COMPRESSION", "${FORCE_FAST_COMPRESSION:-}")"
  if [[ "$(Get-OS-Platform)" == Windows ]]; then
      if [[ "$force_fast_compression" == True ]]; then
        COMPRESSOR_EXT=zip
      else
        COMPRESSOR_EXT=7z
      fi
      COMPRESSOR_EXTRACT="{ echo $COMPRESSOR_EXT on Windows does not support pipeline; exit 1; }"
  else
     if [[ "$force_fast_compression" == True ]]; then
       if [[ "$(command -v gzip)" != "" ]]; then
         COMPRESSOR_EXT=gz
         COMPRESSOR_EXTRACT="gzip -f -d"
       elif [[ "$(command -v xz)" != "" ]]; then
         COMPRESSOR_EXT=xz
         COMPRESSOR_EXTRACT="xz -f -d"
       fi
     else
       if [[ "$(command -v xz)" != "" ]]; then
         COMPRESSOR_EXT=xz
         COMPRESSOR_EXTRACT="xz -f -d"
       elif [[ "$(command -v gzip)" != "" ]]; then
         COMPRESSOR_EXT=gz
         COMPRESSOR_EXTRACT="gzip -f -d"
       fi
     fi
  fi
  printf "COMPRESSOR_EXT='%s'; COMPRESSOR_EXTRACT='%s';" "$COMPRESSOR_EXT" "$COMPRESSOR_EXTRACT"
}

# Include File: [\Includes\Find-Hash-Algorithm.sh]
function Find-Hash-Algorithm() {
  local alg; local hash
  local algs="${EXISTING_HASH_ALGORITHMS:-sha512 sha384 sha256 sha224 sha1 md5}"
  if [[ "$(Get-OS-Platform)" == MacOS ]]; then
    # local file="$(MkTemp-File-Smarty "hash.probe.txt" "hash.algorithm.validator")"
    local file="$(MkTemp-Folder-Smarty "osx.hash.algorithm.validator")/hash.probe.txt"
    printf "%s" "some content" > "$file"
    # echo "[DEBUG] hash probe fille is '$file'" 1>&2
    local algs="${EXISTING_HASH_ALGORITHMS:-sha512 sha384 sha256 sha224 sha1 md5}"
    for alg in $(echo $algs); do
      hash="$(Get-Hash-Of-File "$alg" "$file")"
      # echo "[DEBUG] hash for '$alg' is [$hash] probe fille is '$file'" 1>&2
      if [[ -n "$hash" ]]; then echo "$alg"; break; fi
    done
    rm -f "$file"
    return;
  fi
  for alg in $(echo $algs); do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      echo $alg
      return;
    fi
  done
}

# returns empty string if $alg is not supported by the os
function Get-Hash-Of-File() {
  local alg="${1:-md5}"
  local file="${2:-}"
  if [[ "$(Get-OS-Platform)" == MacOS ]]; then
    local cmd1; local cmd2;
    [[ "$alg" == sha512 ]] && cmd1="shasum -a 512 -b \"$file\"" && cmd2="openssl dgst -sha512 -r \"$file\""
    [[ "$alg" == sha384 ]] && cmd1="shasum -a 384 -b \"$file\"" && cmd2="openssl dgst -sha384 -r \"$file\""
    [[ "$alg" == sha256 ]] && cmd1="shasum -a 256 -b \"$file\"" && cmd2="openssl dgst -sha256 -r \"$file\""
    [[ "$alg" == sha224 ]] && cmd1="shasum -a 224 -b \"$file\"" && cmd2="openssl dgst -sha224 -r \"$file\""
    [[ "$alg" == sha1 ]] && cmd1="shasum -a 1 -b \"$file\"" && cmd2="openssl dgst -sha1 -r \"$file\""
    [[ "$alg" == md5 ]] && cmd1="md5 -r \"$file\"" && cmd2="openssl dgst -md5 -r \"$file\""
    local ret=""
    for cmd in "$cmd1" "$cmd2"; do
      if [[ -n "$cmd" ]]; then
        ret="$(eval $cmd 2>/dev/null | awk '{print $1}')"
        if [[ -n "$ret" ]]; then echo "$ret"; return; fi
      fi
    done
    # no sha sum
  else
    echo "$("${alg}sum" "$file" 2>/dev/null | awk '{print $1}')"
  fi
}

# Include File: [\Includes\Format-Size.sh]
function Format-Size() {
  local num="$1"
  local fractionalDigits="${2:-1}"
  local measureUnit="${3:-}"
  # echo "[DEBUG] Format_Size ARGS: num=$num measureUnit=$measureUnit fractionalDigits=$fractionalDigits" >&2
  awk -v n="$num" -v measureUnit="$measureUnit" -v fractionalDigits="$fractionalDigits" 'BEGIN { 
    if (n<1999) {
      y=n; s="";
    } else if (n<1999999) {
      y=n/1024.0; s="K";
    } else if (n<1999999999) {
      y=n/1024.0/1024.0; s="M";
    } else if (n<1999999999999) {
      y=n/1024.0/1024.0/1024.0; s="G";
    } else if (n<1999999999999999) {
      y=n/1024.0/1024.0/1024.0/1024.0; s="T";
    } else {
      y=n/1024.0/1024.0/1024.0/1024.0/1024.0; s="P";
    }
    format="%." fractionalDigits "f";
    yFormatted=sprintf(format, y);
    if (length(s)==0) { yFormatted=y; }
    print yFormatted s measureUnit;
  }' 2>/dev/null || echo "$num"
}

# Include File: [\Includes\Format-Thousand.sh]
function Format-Thousand() {
  local num="$1"
  # LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$num" # but it is locale dependent
  # Next is locale independent version for positive integers
  awk -v n="$num" 'BEGIN { len=length(n); res=""; for (i=0;i<=len;i++) { res=substr(n,len-i+1,1) res; if (i > 0 && i < len && i % 3 == 0) { res = "," res } }; print res }' 2>/dev/null || echo "$num"
}

# Include File: [\Includes\Get-File-Size.sh]
# returns size in bytes
Get-File-Size() {
    local file="${1:-}"
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
       local sz
       # Ver 1
       if [ "$(uname)" = "Darwin" ]; then
           sz="$(stat -f %z "$file" 2>/dev/null)"
       else
           sz="$(stat -c %s "$file" 2>/dev/null)"
       fi

       # Ver 2
       if [[ -z "$sz" ]]; then
         sz=$(NO_COLOR=1 ls -1aln "$file" 2>/dev/null | awk '{print $5}')
       fi
       echo "$sz"
    else
      if [[ -n "$file" ]]; then
        echo "Get-File-Size Warning! Missing file '$file'" >&2
      fi
    fi
}
# Include File: [\Includes\Get-Folder-Size.sh]
# returns size in bytes
Get-Folder-Size() {
    local dir="${1:-}"
    if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
       local sz
       if [[ "$(uname -s)" == Darwin ]]; then
         sz="$(unset POSIXLY_CORRECT; $(Get-Sudo-Command) du -k -d 0 "$dir" 2>/dev/null | awk '{print 1024 * $1}' | tail -1 || true)"
       else
         sz="$(unset POSIXLY_CORRECT; ($(Get-Sudo-Command) du -k --max-depth=0 "$dir" 2>/dev/null || $(Get-Sudo-Command) du -k -d 0 "$dir" 2>/dev/null || true) | awk '{print 1024 * $1}' || true)"
       fi
       echo "$sz"
    else
      if [[ -n "$dir" ]]; then
        echo "Get-Folder-Size Warning! Missing folder '$dir'" >&2
      fi
    fi
}
# Include File: [\Includes\Get-GitHub-Latest-Release.sh]
# output the TAG of the latest release of null 
# does not require jq
# limited by 60 queries per hour per ip
function Get-GitHub-Latest-Release() {
    local owner="$1";
    local repo="$2";
    local query="https://api.github.com/repos/$owner/$repo/releases/latest"
    if [[ "$(To-Lower-Case "${3:-}")" == "--pre"* ]]; then query="https://api.github.com/repos/$owner/$repo/releases"; fi
    local header_Accept="Accept: application/vnd.github+json"
    local header_Version="X-GitHub-Api-Version: 2022-11-28"
    local json=$(wget -q --header="$header_Accept" --header="$header_Version" -nv --no-check-certificate -O - $query 2>/dev/null || curl -ksSL $query -H "$header_Accept" -H "$header_Version")
    local tag
    if [[ -n "$(command -v jq)" ]]; then
      tag=$(echo "$json" | jq -r ".tag_name" 2>/dev/null)
    fi
    if [[ -z "${tag:-}" ]]; then
       # V1: OK
       # tag=$(echo "$json" | grep -E '"tag_name": "[a-zA-Z0-9_.-]+"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
       # V2
       # json="$(echo $json | tr '\n' ' ' | tr '\r' ' ')"
       # echo -e "$json\n\n" >&2
       tag=$(echo "$json" | grep -oE '"tag_name": *"[a-zA-Z0-9_.-]+"' | sed 's/.*"tag_name": *"//;s/"//' | head -1)
    fi
    if [[ -n "${tag:-}" && "$tag" != "null" ]]; then 
        echo "${tag:-}" 
    fi;
}
# echo "Tag devizer/Universe.SqlInsights: [$(get_github_latest_release devizer Universe.SqlInsights)]"
# echo "Tag devizer/Universe.SqlInsights (beta): [$(get_github_latest_release devizer Universe.SqlInsights --pre)]"
# echo "Tag powershell/powershell: [$(get_github_latest_release powershell powershell)]"
# echo "Tag powershell/powershell (beta): [$(get_github_latest_release powershell powershell --pre)]"


# Include File: [\Includes\Get-Glibc-Version.sh]
# returns 21900 for debian 8
function Get-Glibc-Version() {
  GLIBC_VERSION=""
  GLIBC_VERSION_STRING="$(ldd --version 2>/dev/null| awk 'NR==1 {print $NF}')"
  # '{a=$1; gsub("[^0-9]", "", a); b=$2; gsub("[^0-9]", "", b); if ((a ~ /^[0-9]+$/) && (b ~ /^[0-9]+$/)) {print a*10000 + b*100}}'
  local toNumber='{if ($1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/) { print $1 * 10000 + $2 * 100 }}'
  GLIBC_VERSION="$(echo "${GLIBC_VERSION_STRING:-}" | awk -F'.' "$toNumber")"

  if [[ -z "${GLIBC_VERSION:-}" ]] && [[ -n "$(command -v gcc)" ]]; then
    local cfile="$HOME/temp_show_glibc_version"
    rm -f "$cfile"
    cat <<-'EOF_SHOW_GLIBC_VERSION' > "$cfile.c"
#include <gnu/libc-version.h>
#include <stdio.h>
int main() { printf("%s\n", gnu_get_libc_version()); }
EOF_SHOW_GLIBC_VERSION
    GLIBC_VERSION_STRING="$(gcc $cfile.c -o $cfile 2>/dev/null && $cfile)"
    rm -f "$cfile"; rm -f "$cfile.c" 
    GLIBC_VERSION="$(echo "${GLIBC_VERSION_STRING:-}" | awk -F'.' "$toNumber")"
  fi
  echo "${GLIBC_VERSION:-}"
}

# Include File: [\Includes\Get-Global-Seconds.sh]
function Get-Global-Seconds() {
  the_SYSTEM2="${the_SYSTEM2:-$(uname -s)}"
  if [[ ${the_SYSTEM2} != "Darwin" ]]; then
      # uptime=$(</proc/uptime);                                # 42645.93 240538.58
      uptime="$(cat /proc/uptime 2>/dev/null || true)";                 # 42645.93 240538.58
      if [[ -z "${uptime:-}" ]]; then
        # secured, use number of seconds since 1970
        echo "$(date +%s || true)"
        return
      fi
      IFS=' ' read -ra uptime <<< "$uptime";                    # 42645.93 240538.58
      uptime="${uptime[0]}";                                    # 42645.93
      uptime=$(LC_ALL=C LC_NUMERIC=C printf "%.0f\n" "$uptime") # 42645
      echo $uptime
  else 
      # https://stackoverflow.com/questions/15329443/proc-uptime-in-mac-os-x
      boottime=`sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g'`
      unixtime=`date +%s`
      timeAgo=$(($unixtime - $boottime))
      echo $timeAgo
  fi
}

# Include File: [\Includes\Get-Linux-OS-Bits.sh]
# Works on Linix, Windows, MacOS
# return 32|64|<empty string>
Get-Linux-OS-Bits() {
  # getconf may be absent
  echo "$(getconf LONG_BIT 2>/dev/null)"
}


# Include File: [\Includes\Get-NET-RID.sh]
function Get-NET-RID() {
  local machine="$(uname -m)"; machine="${machine:-unknown}"
  local rid=unknown
  if [[ "$(Get-OS-Platform)" == Linux ]]; then
     local linux_arm linux_arm64 linux_x64
     if Test-Is-Musl-Linux; then
         linux_arm="linux-musl-arm"; linux_arm64="linux-musl-arm64"; linux_x64="linux-musl-x64"; 
     else
         linux_arm="linux-arm"; linux_arm64="linux-arm64"; linux_x64="linux-x64"
     fi
     if [[ "$machine" == armv7* ]]; then
       rid=$linux_arm;
     elif [[ "$machine" == aarch64 || "$machine" == armv8* || "$machine" == arm64* ]]; then
       rid=$linux_arm64;
       if [[ "$(Get-Linux-OS-Bits)" == "32" ]]; then 
         rid=$linux_arm; 
       fi
     elif [[ "$machine" == x86_64 ]] || [[ "$machine" == amd64 ]] || [[ "$machine" == i?86 ]]; then
       rid=$linux_x64;
       if [[ "$(Get-Linux-OS-Bits)" == "32" ]]; then 
         rid=linux-i386;
         echo "Warning! Linux 32-bit i386 is not supported by .NET Core" >&2
       fi
     fi;
     if [ -e /etc/redhat-release ]; then
       redhatRelease=$(</etc/redhat-release)
       if [[ $redhatRelease == "CentOS release 6."* || $redhatRelease == "Red Hat Enterprise Linux Server release 6."* ]]; then
         rid=rhel.6-x64;
         # echo "Warning! Support for Red Hat 6 in .NET Core ended at the end of 2021" >&2
       fi
     fi
  fi
  if [[ "$(Get-OS-Platform)" == MacOS ]]; then
       rid=osx-unknown;
       local osx_machine="$(sysctl -n hw.machine 2>/dev/null)"
       if [[ -z "$osx_machine" ]]; then osx_machine="$machine"; fi
       [[ "$osx_machine" == x86_64 ]] && rid="osx-x64"
       [[ "$osx_machine" == arm64 ]] && rid="osx-arm64"
       [[ "$osx_machine" == i?86 ]] && rid="osx-i386" && echo "Warning! OSX 32-bit i386 is not supported by .NET Core" >&2
       local osx_version="$(SYSTEM_VERSION_COMPAT=0 sw_vers -productVersion)"
       [[ "$osx_version" == 10.10.* ]] && rid="osx.10.10-x64"
       [[ "$osx_version" == 10.11.* ]] && rid="osx.10.11-x64"
  fi
  if [[ "$(Get-OS-Platform)" == Windows ]]; then
       rid="win-unknown"
       local win_arch="$(Get-Windows-OS-Architecture)"
       [[ "$win_arch" == x64 ]] && rid="win-x64"
       [[ "$win_arch" == arm ]] && rid="win-arm"
       [[ "$win_arch" == arm64 ]] && rid="win-arm64"
       [[ "$win_arch" == x86 ]] && rid="win"
       # workaround if powershell.exe is missing
       [[ "$win_arch" == i?86 ]] && rid="win" 
       [[ "$win_arch" == x86_64 ]] && rid="win-x64" 
       [[ "$win_arch" == arm64* || "$win_arch" == aarch64* ]] && rid="win-arm64"
  fi
  echo "$rid"
}

# x86|x64|arm|arm64
function Get-Windows-OS-Architecture() {
if [[ -z "$(command -v powershell)" ]]; then
  echo "$(uname -m)"
  return;
fi
local ps_script=$(cat <<'EOFWINARCH'
function Has-Cmd {
  param([string] $arg)
  if ("$arg" -eq "") { return $false; }
  [bool] (Get-Command "$arg" -ErrorAction SilentlyContinue)
}

function Select-WMI-Objects([string] $class) {
  if     (Has-Cmd "Get-CIMInstance") { $ret = Get-CIMInstance $class; } 
  elseif (Has-Cmd "Get-WmiObject")   { $ret = Get-WmiObject   $class; } 
  if (-not $ret) { [Console]::Error.WriteLine("Warning! Missing neither Get-CIMInstance nor Get-WmiObject"); }
  return $ret;
}

function Get-CPU-Architecture-Suffix-for-Windows-Implementation() {
    # on multiple sockets x64
    $proc = Select-WMI-Objects "Win32_Processor";
    $a = ($proc | Select -First 1).Architecture
    if ($a -eq 0)  { return "x86" };
    if ($a -eq 1)  { return "mips" };
    if ($a -eq 2)  { return "alpha" };
    if ($a -eq 3)  { return "powerpc" };
    if ($a -eq 5)  { return "arm" };
    if ($a -eq 6)  { return "ia64" };
    if ($a -eq 9)  { 
      # Is 32-bit system on 64-bit CPU?
      # OSArchitecture: "ARM 64-bit Processor", "32-bit", "64-bit"
      $os = Select-WMI-Objects "Win32_OperatingSystem";
      $osArchitecture = ($os | Select -First 1).OSArchitecture
      if ($osArchitecture -like "*32-bit*") { return "x86"; }
      return "x64" 
    };
    if ($a -eq 12) { return "arm64" };
    return "";
}

Get-CPU-Architecture-Suffix-for-Windows-Implementation
EOFWINARCH
)
local win_arch=$(echo "$ps_script" | powershell -c - 2>/dev/null)
echo "$win_arch"
}

# Include File: [\Includes\Get-OS-Platform.sh]
function Get-OS-Platform() {
  _LIB_TheSystem="${_LIB_TheSystem:-$(uname -s)}"
  local ret="Unknown"
  [[ "$_LIB_TheSystem" == "Linux" ]] && ret="Linux"
  [[ "$_LIB_TheSystem" == "Darwin" ]] && ret="MacOS"
  [[ "$_LIB_TheSystem" == "FreeBSD" ]] && ret="FreeBSD"
  [[ "$_LIB_TheSystem" == "MSYS"* || "$_LIB_TheSystem" == "MINGW"* ]] && ret=Windows
  echo "$ret"
}

# Include File: [\Includes\Get-Sudo-Command.sh]
# 1) Linux, MacOs
#    return "sudo" if sudo is installed
# 2) Windows
#    If Run as Administrator then empty string
#    If sudo is not installed then empty string
Get-Sudo-Command() {
  # if sudo is missing then empty string
  if [[ -z "$(command -v sudo)" ]]; then return; fi
  # if non-windows and sudo is present then "sudo"
  if [[ "$(Get-OS-Platform)" != Windows ]]; then echo "sudo"; return; fi
  # workaround - avoid microsoft sudo
  return;
  # the last case: windows and sudo is present
  if net session >/dev/null 2>&1; then return; fi
  # is sudo turned on?
  if sudo config >/dev/null 2>&1; then echo "sudo --inline"; return; fi
}

# Include File: [\Includes\Get-Tmp-Folder.sh]
Get-Tmp-Folder() {
  # pretty perfect on termux and routers
  local ret="${TMPDIR:-/tmp}" # in windows it is empty, but substitution is correct
  if [[ -z "${_DEVOPS_LIBRARY_TMP_VALIDATED:-}" ]]; then
    mkdir -p "$ret" 2>/dev/null
    _DEVOPS_LIBRARY_TMP_VALIDATED=Done
  fi
  echo "$ret"
}
# Include File: [\Includes\Is-Microsoft-Hosted-Build-Agent.sh]
#!/usr/bin/env bash
Is-Microsoft-Hosted-Build-Agent() {
  if [[ "${TF_BUILD:-}" == True ]]; then
    if [[ "${AGENT_ISSELFHOSTED:-}" == "0" ]] || [[ "$(To-Lower-Case "${AGENT_ISSELFHOSTED:-}")" == "false" ]] || [[ "${AGENT_NAME:-}" == "Hosted Agent" ]] || [[ "${AGENT_NAME:-}" == "Azure Pipelines" ]] || [[ "${AGENT_NAME:-}" == "Azure Pipelines "* ]] || [[ "${AGENT_NAME:-}" == "ubuntu-latest" ]] || [[ "${AGENT_NAME:-}" == "windows-latest" ]] || [[ "${AGENT_NAME:-}" == "macos-latest" ]]; then
      echo True
      return;
    fi
  fi

  if [[ "${RUNNER_ENVIRONMENT:-}" == "github-hosted" ]]; then
      echo True
      return;
  fi

  echo False
}

# Include File: [\Includes\Is-Qemu-VM.sh]
# if windows in qemu then it returns False
function Is-Qemu-VM() {
  _LIB_Is_Qemu_VM_Cache="${_LIB_Is_Qemu_VM_Cache:-$(Is-Qemu-VM-Implementation)}"
  echo "$_LIB_Is_Qemu_VM_Cache"
}

function Test-Is-Qemu-VM() {
  if [[ "$(Is-Qemu-VM)" == True ]]; then return 0; else return 1; fi
}

function Is-Qemu-VM-Implementation() {
  # termux checkup is Not required
  # if [[ "$(Is_Termux)" == True ]]; then return; fi
  local sudo;
  # We ignore sudo on windows
  if [[ -z "$(command -v sudo)" ]] || [[ "$(Get-OS-Platform)" == Windows ]]; then sudo=""; else sudo="sudo"; fi
  local qemu_shadow="$($sudo grep -r QEMU /sys/devices 2>/dev/null || true)"
  # test -d /sys/firmware/qemu_fw_cfg && echo "Ampere on this Oracle Cloud"
  if [[ "$qemu_shadow" == *"QEMU"* ]]; then
    echo True
  else
    echo False
  fi
}

# Include File: [\Includes\Is-Termux.sh]
function Is-Termux() {
  if [[ -n "${TERMUX_VERSION:-}" ]] && [[ -n "${PREFIX:-}" ]] && [[ -d "${PREFIX}" ]]; then
    echo True
  else
    echo False
  fi
}

# Include File: [\Includes\Is-Windows.sh]
function Is-Windows() {
  if Test-Is-Windows; then echo "True"; else echo "False"; fi
}

function Test-Is-Windows() {
  if [[ "$(Get-OS-Platform)" == "Windows" ]]; then return 0; else return 1; fi
}

function Is-WSL() {
  if Test-Is-WSL; then echo "True"; else echo "False"; fi
}

function Test-Is-WSL() {
  _LIB_TheKernel="${_LIB_TheKernel:-$(uname -r)}"
  if [[ "$_LIB_TheKernel" == *"Microsoft" ]]; then return 0; else return 1; fi
}

function Test-Is-Linux() {
  if [[ "$(Get-OS-Platform)" == "Linux" ]]; then return 0; else return 1; fi
}

function Is-Linux() {
  if Test-Is-Linux; then echo "True"; else echo "False"; fi
}

function Test-Is-MacOS() {
  if [[ "$(Get-OS-Platform)" == "MacOS" ]]; then return 0; else return 1; fi
}

function Is-MacOS() {
  if Test-Is-MacOS; then echo "True"; else echo "False"; fi
}


# Include File: [\Includes\MkTemp-Smarty.sh]
function MkTemp-Folder-Smarty() {
  local template="${1:-tmp}";
  local optionalPrefix="${2:-}";

  local tmpdirCopy="${TMPDIR:-/tmp}";
  # trim last /
  mkdir -p "$tmpdirCopy" >/dev/null 2>&1 || true; pushd "$tmpdirCopy" >/dev/null; tmpdirCopy="$PWD"; popd >/dev/null;

  local defaultBase="${DEFAULT_TMP_DIR:-$tmpdirCopy}";
  local baseFolder="${defaultBase}";
  if [[ -n "$optionalPrefix" ]]; then baseFolder="$baseFolder/$optionalPrefix"; fi;
  mkdir -p "$baseFolder";
  System_Type="${System_Type:-$(uname -s)}";
  local ret;
  if [[ "${System_Type}" == "Darwin" ]]; then
    ret="$(mktemp -t "$template")";
    rm -f "$ret" >/dev/null 2>&1 || true;
    rnd="$RANDOM"; rnd="${rnd:0:1}";
    # rm -rf may fail
    ret="$baseFolder/$(basename "$ret")${rnd}"; 
    mkdir -p "$ret";
  else
    # ret="$(mktemp -d --tmpdir="$baseFolder" -t "${template}.XXXXXXXXX")";
    ret="$(mktemp -t "$template".XXXXXXXXX)";
    rm -f "$ret" >/dev/null 2>&1 || true;
    rnd="$RANDOM"; rnd="${rnd:0:1}";
    # rm -rf may fail
    ret="$baseFolder/$(basename "$ret")${rnd}"; 
    mkdir -p "$ret";
  fi
  if [[ -n "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}" ]] && [[ -f "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}" ]]; then echo "$ret" >> "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}"; fi
  echo $ret;
}; 
# MkTemp-Folder-Smarty session
# MkTemp-Folder-Smarty session azure-api
# sudo mkdir -p /usr/local/tmp3; sudo chown -R "$(whoami)" /usr/local/tmp3
# DEFAULT_TMP_DIR=/usr/local/tmp3 MkTemp-Folder-Smarty session azure-api


# template: without .XXXXXXXX suffix
# optionalFolder if omited then ${TMPDIR:-/tmp}
function MkTemp-File-Smarty() {
  local template="${1:-tmp}";
  local optionalFolder="${2:-}";

  local tmpdirCopy="${TMPDIR:-/tmp}";
  # trim last /
  mkdir -p "$tmpdirCopy" >/dev/null 2>&1 || true; pushd "$tmpdirCopy" >/dev/null; tmpdirCopy="$PWD"; popd >/dev/null;

  local folder;
  if [[ -z "$optionalFolder" ]]; then folder="$tmpdirCopy"; else if [[ "$optionalFolder" == "/"* ]]; then folder="$optionalFolder"; else folder="$tmpdirCopy/$optionalFolder"; fi; fi
  mkdir -p "$folder"
  System_Type="${System_Type:-$(uname -s)}";
  local ret;
  if [[ "${System_Type}" == "Darwin" ]]; then
    ret="$(mktemp -t "$template")";
    rm -f "$ret" >/dev/null 2>&1 || true;
    local rnd="$RANDOM"; rnd="${rnd:0:1}";
    # rm -rf may fail
    ret="$folder/$(basename "$ret")${rnd}"; 
    mkdir -p "$(dirname "$ret")"
    touch "$ret"
  else
    ret="$(mktemp --tmpdir="$folder" -t "${template}.XXXXXXXXX")";
  fi
  if [[ -n "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}" ]] && [[ -f "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}" ]]; then echo "$ret" >> "${_DEVOPS_LIBRARY_TEMP_FOLDERS_AND_FILES_LIST:-}"; fi
  echo $ret;
}; 




# Include File: [\Includes\Retry-On-Fail.sh]
function Echo-Red-Error() { 
  Colorize Red "\n$*\n"; 
}

function Retry-On-Fail() { 
  "$@" && return; 
  Echo-Red-Error "Retrying 2 of 3 for \"$*\""; 
  sleep 1; 
  "$@" && return; 
  Echo-Red-Error "Retrying last, 3 of 3, for \"$*\""; 
  sleep 1; 
  "$@"
}

# Include File: [\Includes\Say-Definition.sh]
# Last Parameter is Green, the rest are title
Say-Definition() {
  if [[ -z "$*" ]]; then echo ""; return; fi
  # local args=("$@")
  # local title="${args[@]:0:$#-1}"
  # local value="${!#}"
  local value="${@: -1}"
  # local title="${@:1:$#-1}"; # bash ok, zsh - all the parameters

  local title=""
  if [ $# -gt 1 ]; then
    local count=$(( $# - 1 ))
    title="${@:1:$count}"
  fi

  if [[ "$title" != *" " ]] && [[ -n "$title" ]]; then title="$title "; fi
  local colorTitle="${DEFINITION_COLOR:-Yellow}"
  local colorValue="${VALUE_COLOR:-Green}"
  Colorize --NoNewLine "$colorTitle" "${title}"
  Colorize "$colorValue" "${value}"
}

# Include File: [\Includes\Test-Has-Command.sh]
Test-Has-Command() {
  if command -v "${1:-}" >/dev/null 2>&1; then return 0; else return 1; fi
}

# Include File: [\Includes\Test-Is-Musl-Linux.sh]
Test-Is-Musl-Linux() {
  if [[ "$(Is-Termux)" == True ]]; then
    return 1;
  elif Test-Has-Command getconf && getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
    return 1;
  elif ldd --version 2>&1 | grep -iq "glibc"; then
    return 1;
  elif ldd /bin/ls 2>&1 | grep -q "musl"; then
    return 0;
  fi
  return 1; # by default GNU
}

Is-Musl-Linux() {
  if Test-Is-Musl-Linux; then echo "True"; else echo "False"; fi
}

# Include File: [\Includes\To-Boolean.sh]
# return True|False
function To-Boolean() {
  local name="${1:-}"
  local value="${2:-}"
  value="$(To-Lower-Case "$value")"
  if [[ "$value" == true ]] || [[ "$value" == on ]] || [[ "$value" == "1" ]] || [[ "$value" == "enable"* ]]; then echo "True"; return; fi
  if [[ "$value" == "" ]] || [[ "$value" == false ]] || [[ "$value" == off ]] || [[ "$value" == "0" ]] || [[ "$value" == "disable"* ]]; then echo "False"; return; fi
  echo "Validation Error! Invalid $name option '$value'. Boolean option accept only True|False|On|Off|Enable(d)|Disable(d)|1|0" >&2
}

# for x in True False 0 1 Enable Disable "" Enabled Disabled; do echo "[$x] as boolean is [$(To_Boolean "Arg" "$x")]"; done

# Include File: [\Includes\To-Lower-Case.sh]
function To-Lower-Case() {
  local a="${1:-}"
  if [[ "${BASH_VERSION:-}" == [4-9]"."* ]]; then
    echo "${a,,}"
  elif [[ -n "$(command -v tr)" ]]; then
    echo "$a" | tr '[:upper:]' '[:lower:]'
  elif [[ -n "$(command -v awk)" ]]; then
    echo "$a" | awk '{print tolower($0)}'
  else
    echo "WARNING! Unable to convert a string to lower case. It needs bash 4+, or tr, or awk, on legacy bash" >&2
    return 13
  fi
}
# x="  Hello  World!  "; echo "[$x] in lower case is [$(To_Lower_Case "$x")]"

# Include File: [\Includes\Validate-File-Is-Not-Empty.sh]
Validate-File-Is-Not-Empty() {
  local file="$1"
  # echo "Validate_File_Is_Not_Empty('$file')"
  local successMessage="${2:-"File %s exists and isn't empty, size is"}"
  if [[ -f "$file" ]]; then 
    local sz="$(ls -l "$file" | awk '{print $5}')"
    local title="$(printf "$successMessage" "$file" 2>/dev/null)"
    DEFINITION_COLOR=Default VALUE_COLOR=Green Say-Definition "$title" "$(Format-Thousand "$sz") bytes"
  else
    local errorMessage="${3:-"File $file exists and is'n empty"}"
    Colorize Red "$errorMessage"
  fi
}

# Include File: [\Includes\Wait-For-HTTP.sh]
# Wait-For-HTTP http://localhost:55555 30
Wait-For-HTTP() {
  local u="$1"; 
  local t="${2:-30}"; 

  local infoSeconds=seconds;
  [[ "$t" == "1" ]] && infoSeconds="second"
  printf "Waiting for [$u] during $t $infoSeconds ..."

  if [[ -z "$(command -v curl)" ]] && [[ -z "$(command -v wget)" ]]; then
    Colorize Red "MISSING curl|wget. 'Wait For $u' aborted.";
    return 1;
  fi

  local httpConnectTimeout="${HTTP_CONNECT_TIMEOUT:-3}"

  local startAt="$(Get-Global-Seconds)"
  local now;
  local errHttp;
  while [ $t -ge 0 ]; do 
    t=$((t-1)); 
    errHttp=0;
    if [[ -n "$(command -v curl)" ]]; then curl --connect-timeout "$httpConnectTimeout" -skf "$u" >/dev/null 2>&1 || errHttp=$?; else errHttp=13; fi
    if [ "$errHttp" -ne 0 ]; then
      errHttp=0;
      if [[ -n "$(command -v wget)" ]]; then wget -q --no-check-certificate -t 1 -T "$httpConnectTimeout" -O - "$u" >/dev/null 2>&1 || errHttp=$?; else errHttp=13; fi
    fi
    if [ "$errHttp" -eq 0 ]; then Colorize Green " OK"; return; fi; 
    printf ".";
    sleep 1;
    now="$(Get-Global-Seconds)"; now="${now:-}";
    local seconds=$((now-startAt))
    if [ "$seconds" -lt 0 ]; then break; fi
  done
  Colorize Red " FAIL";
  now="$(Get-Global-Seconds)"; now="${now:-}";
  local seconds2=$((now-startAt))
  Colorize Red "The service at '$u' is not responding during $seconds2 seconds"
  return 1;
}

# Include Directive: [ ..\Azure-DevOps-Api.Includes\*.sh ]
# Include File: [\Azure-DevOps-Api.Includes\$DEFAULTS.sh]
set -eu; set -o pipefail
# https://dev.azure.com
# https://stackoverflow.com/questions/43291389/using-jq-to-assign-multiple-output-variables
AZURE_DEVOPS_API_BASE="${AZURE_DEVOPS_API_BASE:-https://dev.azure.com/devizer/azure-pipelines-agent-in-docker}"
AZURE_DEVOPS_ARTIFACT_NAME="${AZURE_DEVOPS_ARTIFACT_NAME:-BinTests}" # not used anymore
AZURE_DEVOPS_API_PAT="${AZURE_DEVOPS_API_PAT:-}"; # empty for public project, mandatory for private
# PIPELINE_NAME="" - optional of more then one pipeline produce same ARTIFACT_NAME

# Include File: [\Azure-DevOps-Api.Includes\Azure-DevOps-DownloadViaApi.sh]
function Azure-DevOps-DownloadViaApi() {
  local url="$1"
  local file="$2";
  local header1="";
  local header2="";
  if [[ -n "${AZURE_DEVOPS_API_PAT:-}" ]]; then 
    local B64_PAT=$(printf "%s"":$API_PAT" | base64)
    # wget
    header1='--header="Authorization: Basic '${B64_PAT}'"'
    # curl
    header2='--header "Authorization: Basic '${B64_PAT}'"'
  fi
  local progress1="";
  local progress2="";
  if [[ "${API_SHOW_PROGRESS:-}" != "True" ]]; then
    progress1="-q -nv"
    progress2="-s"
  fi
  eval try-and-retry curl $header2 $progress2 -kfSL -o '$file' '$url' || eval try-and-retry wget $header1 $progress1 --no-check-certificate -O '$file' '$url'
  # download_file "$url" "$file"
  echo "$file"
}

# Include File: [\Azure-DevOps-Api.Includes\Azure-DevOps-GetArtifacts.sh]
# Colums:
#    Artifact ID
#    Name
#    Size in bytes
#    Download URL
function Azure-DevOps-GetArtifacts() {
  local buildId="${1:-}"
  if [[ -z "$buildId" ]]; then Colorize Red "Azure-DevOps-GetArtifacts(): Missing #1 buildId parameter" 2>/dev/null; return; fi

  local url="${AZURE_DEVOPS_API_BASE}/_apis/build/builds/${buildId}/artifacts?api-version=6.0"
  local file=$(Azure-DevOps-GetTempFileFullName artifacts-$buildId);
  local json=$(Azure-DevOps-DownloadViaApi "$url" "$file.json")
  local f='.value | map({"id":.id|tostring, "name":.name, "size":.resource?.properties?.artifactsize?, "url":.resource?.downloadUrl?}) | map([.id, .name, .size, .url] | join("|")) | join("\n")'
  jq -r "$f" "$file.json" > "$file.txt"
  echo "$file.txt"
}

# Include File: [\Azure-DevOps-Api.Includes\Azure-DevOps-GetBuilds.sh]
# Colums:
#    Build ID
#    Build Number (string)
#    Pipeline Name
#    Result
#    Status
# GET https://dev.azure.com/{organization}/{project}/_apis/build/builds?definitions={definitions}&queues={queues}&buildNumber={buildNumber}&minTime={minTime}&maxTime={maxTime}&requestedFor={requestedFor}&reasonFilter={reasonFilter}&statusFilter={statusFilter}&resultFilter={resultFilter}&tagFilters={tagFilters}&properties={properties}&$top={$top}&continuationToken={continuationToken}&maxBuildsPerDefinition={maxBuildsPerDefinition}&deletedFilter={deletedFilter}&queryOrder={queryOrder}&branchName={branchName}&buildIds={buildIds}&repositoryId={repositoryId}&repositoryType={repositoryType}&api-version=6.0
function Azure-DevOps-GetBuilds() {
  # resultFilter: canceled|failed|none|partiallySucceeded|succeeded
  #               optional, if omitted get all builds
  local resultFilter="${1:-}"
  local url="${AZURE_DEVOPS_API_BASE}/_apis/build/builds?api-version=6.0"
  if [[ -n "$resultFilter" ]]; then url="${url}&resultFilter=$resultFilter"; fi
  local file=$(Azure-DevOps-GetTempFileFullName builds);
  local json=$(Azure-DevOps-DownloadViaApi "$url" "$file.json")
  local f='.value | map({"id":.id|tostring, "buildNumber":.buildNumber, p:.definition?.name?, r:.result, s:.status}) | map([.id, .buildNumber, .p, .r, .s] | join("|")) | join("\n") '
  jq -r "$f" "$file.json" | sort -r -k1 -n -t"|" > "$file.txt"
  echo "$file.txt"
}

# Include File: [\Azure-DevOps-Api.Includes\Azure-DevOps-GetTempFileFullName.sh]
function Azure-DevOps-GetTempFileFullName() {
  local template="$1"

  Azure-DevOps-Lazy-CTOR
  local ret="$(MkTemp-File-Smarty "$template" "$AZURE_DEVOPS_IODIR")";
  rm -f "$ret" >/dev/null 2>&1|| true
  echo "$ret"
}

# Include File: [\Azure-DevOps-Api.Includes\Azure-DevOps-Lazy-CTOR.sh]
function Azure-DevOps-Lazy-CTOR() {
  if [[ -z "${AZURE_DEVOPS_IODIR:-}" ]]; then
    AZURE_DEVOPS_IODIR="$(MkTemp-Folder-Smarty session azure-devops-api)"
    # echo AZUREAPI_IODIR: $AZUREAPI_IODIR
  fi
};

# Include Directive: [ src\Run-Remote-Script-Body.sh  ]
# Include File: [\DevOps-Lib.ShellProject\src\Run-Remote-Script-Body.sh]
Run-Remote-Script() {
  local arg_runner
  local arg_url
  arg_runner=""
  arg_url=""
  passthrowArgs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        echo 'Usage: Run-Remote-Script [OPTIONS] <URL>

Arguments:
  URL                Target URL (required)

Options:
  -r, --runner STR   Specify the runner string
  -h, --help         Show this help message and exit
'
        return 0;;

      -r|--runner)
        if [ $# -gt 1 ]; then
          arg_runner="$2"
          shift 2
        else
          echo "Run-Remote-Script Arguments Error: -r|--runner requires a value" >&2
          return 1
        fi
        ;;
      *)
        if [ -z "$arg_url" ]; then
          arg_url="$1"
          shift
        else
          passthrowArgs+=("$1")
          shift
        fi
        ;;
    esac
  done

  if [ -z "$arg_url" ]; then
    echo "Run-Remote-Script Arguments Error: Missing required argument <URL>" >&2
    return 1
  fi

  local additionalError=""
  local lower="$(To-Lower-Case "$arg_url")"
  if [[ -z "$arg_runner" ]]; then
    if [[ "$lower" == *".ps1" ]]; then
      if [[ "$(command -v pwsh)" ]]; then arg_runner="pwsh"; fi
      if [[ "$(Get-OS-Platform)" == Windows ]] && [[ -z "$arg_runner" ]]; then arg_runner="powershell -f"; else additionalError=". On $(Get-OS-Platform) it requires pwsh"; fi
    elif [[ "$lower" == *".sh" ]]; then
      arg_runner="bash"
    fi
  fi

  if [[ -z "$arg_runner" ]]; then
    echo "Run-Remote-Script Arguments Error: Unable to autodetect runner for script '$arg_url'${additionalError}" >&2
    return 1
  fi
  
  # ok for non-empty array only
  printf "Invoking "; Colorize -NoNewLine Magenta "${arg_runner} "; Colorize Green "$arg_url" ${passthrowArgs[@]+"${passthrowArgs[@]}"}

  local folder="$(MkTemp-Folder-Smarty)"
  local file="$(basename "$arg_url")"
  if [[ "$file" == "download" ]]; then local x1="$(dirname "$arg_url")"; file="$(basename "$x1")"; fi
  if [[ -z "$file" ]]; then 
    file="script"; 
    if [[ "$arg_runner" == *"pwsh"* || "$arg_runner" == *"powershell"* ]]; then file="script.ps1"; fi
  fi;
  local fileFullName="$folder/$file"
  Download-File-Failover "$fileFullName" "$arg_url" 
  $arg_runner "$fileFullName" ${passthrowArgs[@]+"${passthrowArgs[@]}"}
  rm -rf "$folder" 2>/dev/null || true
  
  return 0
}

