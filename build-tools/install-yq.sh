#!/usr/bin/env bash
# export INSTALL_DIR=/usr/local YQ_VER=v4.20.1; script="https://master.dl.sourceforge.net/project/yq-repack/install-yq.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
set -e
set -u
set -o pipefail

TMPDIR="${TMPDIR:-/tmp}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
YQ_VER="${YQ_VER:-v4.20.1}"

function find_hash_algorithm() {
  local alg
  for alg in sha512 sha384 sha256 sha224 sha1 md5; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      echo $alg
      return;
    fi
  done
  if [[ "$(uname -s)" == "Darwin" ]] && [[ "$(command -v md5)" != "" ]] ; then
    echo "md5"
  fi
}

function check_up_is_yq_works() {
  local work="$(mk_temp_directory yq-acceptance-test)"
  mkdir -p "$work"
  pushd "$work" >/dev/null
  local v42="$(echo "v: '42'" | "${INSTALL_DIR}/bin/yq" e '.v' - 2>log.txt || true)"
  if [[ "$v42" == "42" ]]; then
    echo "yq acceptance test passed"
  else
    echo "yq acceptance test failed. below is an output"
    cat log.txt
  fi
  rm -rf "$work" 2>/dev/null || rm -rf "$work" 2>/dev/null || rm -rf "$work"
}

function find_decompressor() {
  # argument is space separated list of prepared archives
  local present="${1:-7z xz bzip2 gzip}"; present="${present}"
  COMPRESSOR_EXT=""
  COMPRESSOR_EXTRACT=""
  if [[ "$(command -v xz)" != "" ]] && [[ " $present " == *" xz "* ]]; then
    COMPRESSOR_EXT=xz
    COMPRESSOR_EXTRACT="xz -f -d"
  elif [[ "$(command -v bzip2)" != "" ]] && [[ " $present " == *" bzip2 "* ]]; then
    COMPRESSOR_EXT=bz2
    COMPRESSOR_EXTRACT="bzip2 -f -d"
  elif [[ "$(command -v gzip)" != "" ]] && [[ " $present " == *" gzip "* ]]; then
    COMPRESSOR_EXT=gz
    COMPRESSOR_EXTRACT="gzip -f -d"
  fi
}

function smart_sudo() {
  if [[ "$(command -v sudo)" ]]; then 
    sudo "$@"
  else
    eval "$@"
  fi
}

function mk_temp_directory() {
  local template="${1:-tmp}"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mktemp -d -t "$template"
  else
    mktemp -d -t "$template".XXXXXX
  fi
}

function download_file() {
  local url="$1"
  local file="$2";
  local progress1="";
  local progress2="";
  if [[ "$DOWNLOAD_SHOW_PROGRESS" != "True" ]] || [[ ! -t 1 ]]; then
    progress1="-q -nv"
    progress2="-s"
  fi
  local try1=""
  if [[ "$(command -v wget)" != "" ]]; then
    try1="${try1:-} wget $progress1 --no-check-certificate -O '$file' '$url'"
  fi
  if [[ "$(command -v curl)" != "" ]]; then
    [[ -n "${try1:-}" ]] && try1="$try1 || "
    try1="${try1:-} curl $progress2 -kSL -o '$file' '$url'"
  fi
  if [[ "${try1:-}" == "" ]]; then
    echo "error: niether curl or wget is available"
    exit 42;
  fi
  eval $try1 || eval $try1 || eval $try1
  # eval try-and-retry wget $progress1 --no-check-certificate -O '$file' '$url' || eval try-and-retry curl $progress2 -kSL -o '$file' '$url'
}

function install_yq() {
  local alg=$(find_hash_algorithm)
  find_decompressor "xz bzip2 gzip"

  local machine="$(uname -m)"
  local suffix="unknown";
  local long="$(getconf LONG_BIT)"
  if [[ "${machine:-}" =~ i?86 ]];    then suffix="linux_386"; fi
  if [[ "${machine:-}" =~ aarch64 ]]; then 
    if [[ "${long:-}" == "32" ]]; then suffix="linux_arm"; else suffix="linux_arm64"; fi
  fi
  if [[ "${machine:-}" =~ armv ]];    then suffix="linux_arm"; fi
  if [[ "${machine:-}" =~ x86\_64 ]]; then 
    if [[ "${long:-}" == "32" ]]; then suffix="linux_386"; else suffix="linux_amd64"; fi
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    suffix="darwin_amd64"
    suf=darwin_amd64; [[ "$machine" == arm* ]] && suf=darwin_arm64 # x86_64 for intel
  fi


  local    url_hash="https://master.dl.sourceforge.net/project/yq-repack/yq_${suffix}_${YQ_VER}.tar.${COMPRESSOR_EXT}.${alg}?viasf=1"
  local url_archive="https://master.dl.sourceforge.net/project/yq-repack/yq_${suffix}_${YQ_VER}.tar.${COMPRESSOR_EXT}?viasf=1"

  # get hash
  DOWNLOAD_SHOW_PROGRESS=False
  local user="${USER:-$(whoami)}"
  local tmp_hash_file="${TMPDIR}/yq-${suffix}-for-${user}"
  download_file "$url_hash" "$tmp_hash_file"
  local hash="$(cat "$tmp_hash_file" | awk 'NR==1 {print $NF}')"
  if [[ -z "${hash:-}" ]] || [[ "${#hash}" -lt 32 ]]; then hash="<error>"; fi
  rm -f "$tmp_hash_file" || true
  echo "Downloading yq ${YQ_VER} for ${suffix} details:
  arch: ${suffix}
  url: $url_archive
  directory: ${INSTALL_DIR}
  integrity algorithm: ${alg}
  integrity hash: ${hash}
  temp download dir: ${TMPDIR}"
  
  # get archive
  DOWNLOAD_SHOW_PROGRESS=True
  local tmp_file="${TMPDIR}/yq-${suffix}-for-${user}.tar.${COMPRESSOR_EXT}"
  download_file "$url_archive" "$tmp_file"
  # validate hash
  local actual_hash="unknown"
  if [[ "$(command -v ${alg}sum)" != "" ]]; then
    actual_hash="$(eval ${alg}sum "$tmp_file" | awk '{print $1}')"
  elif [[ "$(uname -s)" == "Darwin" ]] && [[ "$alg" == "md5" ]] && [[ "$(command -v md5)" != "" ]]; then
    actual_hash="$(md5 -q "$tmp_file")"
  fi
  if [[ "${actual_hash:-}" != "$hash" ]]; then
    echo "Actual hash is different: ${actual_hash:-}"
    exit 13;
  else
    echo "${alg} hash is correct. Extracting yq ${YQ_VER} to [$INSTALL_DIR]"
  fi

  smart_sudo mkdir -p "$INSTALL_DIR"
  pushd "$INSTALL_DIR" >/dev/null
    cat "$tmp_file" | eval $COMPRESSOR_EXTRACT | smart_sudo tar -xf -
  popd >/dev/null
  rm -f "$tmp_file"

  export PATH="$INSTALL_DIR/bin:$PATH"
  echo "Added $INSTALL_DIR/bin to the PATH var"
  check_up_is_yq_works
}

install_yq
