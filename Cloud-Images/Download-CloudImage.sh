#!/usr/bin/env bash
set -eu; set -o pipefail

CLOUD_IMAGE_METADATA="$HOME/.local/cloud-images/metadata.txt"
mkdir -p "$(dirname "$CLOUD_IMAGE_METADATA")"

help='
Download-CloudImage.sh --reset-metadata
or
Download-CloudImage.sh [--temp /var/tmp] armhf-debian-12 $HOME/.cloud-images/armhf-debian-12

1.
ARM v7 Ubuntu cloud images
  armhf-ubuntu-14.04   armhf-ubuntu-16.04   armhf-ubuntu-18.04   armhf-ubuntu-20.04  
  armhf-ubuntu-22.04   armhf-ubuntu-23.10   armhf-ubuntu-24.04                       
ARM v8 Ubuntu cloud images
  arm64-ubuntu-14.04   arm64-ubuntu-16.04   arm64-ubuntu-18.04   arm64-ubuntu-20.04  
  arm64-ubuntu-22.04   arm64-ubuntu-23.10   arm64-ubuntu-24.04                       
ARM v7 Debian cloud images
  armhf-debian-8       armhf-debian-9       armhf-debian-10      armhf-debian-11     
  armhf-debian-12
ARM v8 Debian cloud images
  arm64-debian-10      arm64-debian-11      arm64-debian-12      arm64-debian-13

for a list of images see https://devizer.visualstudio.com/azure-pipelines-agent-in-docker/_build?definitionId=57&_a=summary

2.
metadata is cached in '$CLOUD_IMAGE_METADATA'
'
# https://hub.docker.com/v2/repositories/library/ubuntu/tags/?page_size=10000
if [[ "${1:-}" == "--reset-metadata" ]]; then
  test -f "$CLOUD_IMAGE_METADATA" && rm -f "$CLOUD_IMAGE_METADATA" >/dev/null 2>&1 || true
  exit 0
fi

# Include Detected: [ ..\Azure-DevOps-Api.Includes\*.sh ]
# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\$DEFAULTS.sh]
set -eu; set -o pipefail
# https://dev.azure.com
# https://stackoverflow.com/questions/43291389/using-jq-to-assign-multiple-output-variables
AZURE_DEVOPS_API_BASE="${AZURE_DEVOPS_API_BASE:-https://dev.azure.com/devizer/azure-pipelines-agent-in-docker}"
AZURE_DEVOPS_ARTIFACT_NAME="${AZURE_DEVOPS_ARTIFACT_NAME:-BinTests}"
AZURE_DEVOPS_API_PAT="${AZURE_DEVOPS_API_PAT:-}"; # empty for public project, mandatory for private
# PIPELINE_NAME="" - optional of more then one pipeline produce same ARTIFACT_NAME

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\Azure-DevOps-DownloadViaApi.sh]
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

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\Azure-DevOps-GetArtifacts.sh]
# Colums:
#    Artifact ID
#    Name
#    Size in bytes
#    Download URL
function Azure-DevOps-GetArtifacts() {
  local buildId="${1:-}"
  if [[ -z "$buildId" ]]; then say Red "Azure-DevOps-GetArtifacts(): Missing #1 buildId parameter" 2>/dev/null; return; fi

  local url="${AZURE_DEVOPS_API_BASE}/_apis/build/builds/${buildId}/artifacts?api-version=6.0"
  local file=$(Azure-DevOps-GetTempFileFullName artifacts-$buildId);
  local json=$(Azure-DevOps-DownloadViaApi "$url" "$file.json")
  local f='.value | map({"id":.id|tostring, "name":.name, "size":.resource?.properties?.artifactsize?, "url":.resource?.downloadUrl?}) | map([.id, .name, .size, .url] | join("|")) | join("\n")'
  jq -r "$f" "$file.json" > "$file.txt"
  echo "$file.txt"
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\Azure-DevOps-GetBuilds.sh]
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

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\Azure-DevOps-GetTempFileFullName.sh]
function Azure-DevOps-GetTempFileFullName() {
  local template="$1"

  Azure-DevOps-Lazy-CTOR
  local ret="$(MkTemp-File-Smarty "$template" "$AZURE_DEVOPS_IODIR")";
  rm -f "$ret" >/dev/null 2>&1|| true
  echo "$ret"
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Azure-DevOps-Api.Includes\Azure-DevOps-Lazy-CTOR.sh]
function Azure-DevOps-Lazy-CTOR() {
  if [[ -z "${AZURE_DEVOPS_IODIR:-}" ]]; then
    AZURE_DEVOPS_IODIR="$(MkTemp-Folder-Smarty session azure-api)"
    # echo AZUREAPI_IODIR: $AZUREAPI_IODIR
  fi
};

# Include Detected: [ ..\Includes\*.sh ]
# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\download_file.sh]
function download_file() {
  local url="$1"
  local file="$2";
  local progress1="" progress2="" progress3="" 
  if [[ "${DOWNLOAD_SHOW_PROGRESS:-}" != "True" ]] || [[ ! -t 1 ]]; then
    progress1="-q -nv"       # wget
    progress2="-s"           # curl
    progress3="--quiet=true" # aria2c
  fi
  rm -f "$file" 2>/dev/null || rm -f "$file" 2>/dev/null || rm -f "$file"
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
    echo "error: niether curl, wget or aria2c is available"
    exit 42;
  fi
  eval $try1 || eval $try1 || eval $try1
  # eval try-and-retry wget $progress1 --no-check-certificate -O '$file' '$url' || eval try-and-retry curl $progress2 -kSL -o '$file' '$url'
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\download_file_fialover.sh]
function download_file_fialover() {
  local file="$1"
  shift
  for url in "$@"; do
    # DEBUG: echo -e "\nTRY: [$url] for [$file]"
    local err=0;
    download_file "$url" "$file" || err=$?
    # DEBUG: say Green "Download status for [$url] is [$err]"
    if [ "$err" -eq 0 ]; then return; fi
  done
  return 55;
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\find_decompressor.sh]
function find_decompressor() {
  COMPRESSOR_EXT=""
  COMPRESSOR_EXTRACT=""
  if [[ -n "${GCC_FORCE_GZIP_PRIORITY:-}" ]] || [[ -n "${FORCE_GZIP_PRIORITY:-}" ]]; then
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
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\find_hash_algorithm.sh]
function find_hash_algorithm() {
  local alg
  for alg in sha256 sha512 sha384 sha224 sha1 md5; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      echo $alg
      return;
    fi
  done
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\Format_Thousand.sh]
function Format_Thousand() {
  local num="$1"
  # LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$num" # but it is locale dependent
  # Next is locale independent version for positive integers
  awk -v n="$num" 'BEGIN { len=length(n); res=""; for (i=0;i<=len;i++) { res=substr(n,len-i+1,1) res; if (i > 0 && i < len && i % 3 == 0) { res = "," res } }; print res }' 2>/dev/null || echo "$num"
}

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\get_glibc_version.sh]
# returns 21900 for debian 8
function get_glibc_version() {
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

# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\MkTempSmarty.sh]
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

  folder="${optionalFolder:-$tmpdirCopy}"
  mkdir -p "$folder"
  System_Type="${System_Type:-$(uname -s)}";
  local ret;
  if [[ "${System_Type}" == "Darwin" ]]; then
    ret="$(mktemp -t "$template")";
    rm -f "$ret" >/dev/null 2>&1 || true;
    rnd="$RANDOM"; rnd="${rnd:0:1}";
    # rm -rf may fail
    ret="$folder/$(basename "$ret")${rnd}"; 
    mkdir -p "$(dirname "$ret")"
    touch "$ret"
  else
    ret="$(mktemp --tmpdir="$folder" -t "${template}.XXXXXXXXX")";
  fi
  echo $ret;
}; 
# MkTemp-File-Smarty builds
# MkTemp-File-Smarty builds $HOME/.tmp/sessions
# MkTemp-File-Smarty builds /tmp




# File: [C:\Cloud\vg\PUTTY\Repo-BASH\Includes\say.sh]
# say Green|Yellow|Red Hello World without quotes
function say() { 
   local NC='\033[0m' Color_Green='\033[1;32m' Color_Red='\033[1;31m' Color_Yellow='\033[1;33m'; 
   local var="Color_${1:-}"
   local color="${!var}"
   shift 
   printf "${color:-}$*${NC}\n";
}


function Update-CloudImage-Metadata() {
  echo "Quering latest succeeded Build ID of CloudImages pipeline"
  fileBuilds="$(Azure-DevOps-GetBuilds "succeeded")"
  echo "Total Succeeded Builds: $(cat "$fileBuilds" | wc -l)"

  latestBuildId="$(cat "$fileBuilds" | grep -E "\|CloudImages\|" | head -1 | awk -F"|" {'print $1'})"
  echo "The Latest Succeeded Build ID for CloudImages: [$latestBuildId]"

  artifacts="$(Azure-DevOps-GetArtifacts $latestBuildId)"
  cat "${artifacts}" | sort -V -k2 -t"|" | grep "Succeeded" > "${artifacts}".Succeeded
  cp -f "${artifacts}".Succeeded "$CLOUD_IMAGE_METADATA"
  say Green "Total images: $(cat "${artifacts}".Succeeded | wc -l)"
}

Azure-DevOps-Lazy-CTOR
echo "AZURE_DEVOPS_IODIR = [$AZURE_DEVOPS_IODIR]"

DOWNLOAD_CLOUD_IMAGE_FOLDER="${TMPDIR:-/tmp}/.cloud-image-downloads"
if [[ "${1:-}" == "--temp" ]]; then
  DOWNLOAD_CLOUD_IMAGE_FOLDER="$2"
  shift; shift
fi

image="$1"
storeTo="$2"

if [[ ! -s "$CLOUD_IMAGE_METADATA" ]]; then Update-CloudImage-Metadata; fi

url="$(cat "$CLOUD_IMAGE_METADATA" | awk -F"|" -v image="$image" '(index($2, image) != 0) {print $4}' | head -1)"
size="$(cat "$CLOUD_IMAGE_METADATA" | awk -F"|" -v image="$image" '(index($2, image) != 0) {print $3}' | head -1)"
size_h="$(Format_Thousand "$size")"

say Green "Downloading Cloud Image $image"
echo "     to : $storeTo"
echo "    url : ${url:-NOT FOUND}"
if [[ -z "$url" ]]; then
  say Red "Image '$image' not found. Abort"
  exit 33
fi
echo "   size : $size_h bytes"
tmp="$(MkTemp-File-Smarty "$image" "$DOWNLOAD_CLOUD_IMAGE_FOLDER")"
echo "    tmp : ${tmp}.zip"

function my_clean_up() {
  if [[ -n "${1:-}" ]]; then
    echo "[Download-CloudImage.sh] An error occurred on line $1. Cleanup and abort"
  fi
  if [[ -n "${tmp:-}" ]]; then
     rm -f "${tmp}.zip" >/dev/null 2>&1 || true
     rm -f "${tmp}"     >/dev/null 2>&1 || true
     rm -rf "${tmp}_"   >/dev/null 2>&1 || true
  fi
  if [[ -n "${1:-}" ]]; then
    exit 77
  fi
}
trap 'my_clean_up $LINENO' ERR

download_file "$url" "$tmp.zip"

echo "Extracting ${tmp}.zip"
mkdir -p "${tmp}_"
pushd "${tmp}_" >/dev/null
unzip "${tmp}.zip" >/dev/null || 7z x -y "${tmp}.zip"
cd *
rm -rf _*
xz_files=$(ls *.xz)
echo Extracting $xz_files
xz -d *.xz
echo "DECOMPRESSED FILES"
ls -lh
mkdir -p "$storeTo"
cp -f * "$storeTo"
popd >/dev/null

my_clean_up
