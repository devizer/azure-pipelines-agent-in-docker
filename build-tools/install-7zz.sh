#!/usr/bin/env bash
# export INSTALL_DIR=/usr/local/bin LINK_AS_7Z=/usr/local/bin/7z; script="https://master.dl.sourceforge.net/project/p7zz-repack/install-7zz.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
set -e
set -u
set -o pipefail

TMPDIR="${TMPDIR:-/tmp}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
LINK_AS_7Z="${LINK_AS_7Z:-}"

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

function check_up_is_7z_executable_works() {
  local bin="$1"
  # local work="$TMPDIR/check_7z_executable-$(basename "$bin")"
  local template="check_7z_executable-$(basename "$bin")"
  local work="$(mk_temp_directory "$template")"
  mkdir -p "$work"
  pushd "$work" >/dev/null
  printf "42" >42.txt
  "$bin" a 42.7z 42.txt 1>/dev/null 2>&1 || true
  mkdir -p extracted; 
  cd extracted
  rm -f 42.txt
  "$bin" x -y ../42.7z >/dev/null 2>&1 || true
  local actual="$(cat 42.txt 2>/dev/null)"
  popd >/dev/null
  rm -rf "$work"
  if [[ "$actual" == 42 ]]; then echo "OK"; else echo "Error"; fi
}

function find_7z_executable() {
  local cmd;
  for cmd in 7za 7zr 7z 7zz 7zzs; do
    if [[ "$(command -v "$cmd")" != "" ]]; then
      local ok7z="$(check_up_is_7z_executable_works "$cmd")"
      if [[ "${ok7z:-}" == "OK" ]]; then
        echo "$cmd"
        return
      fi
    fi
  done
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

function install_7zz() {
  local alg=$(find_hash_algorithm)
  find_decompressor "xz bzip2 gzip"

  local machine="$(uname -m)"
  local suffix="unknown";
  local long="$(getconf LONG_BIT)"
  if [[ "${machine:-}" =~ i?86 ]];    then suffix="linux-x86"; fi
  if [[ "${machine:-}" =~ aarch64 ]]; then 
    if [[ "${long:-}" == "32" ]]; then suffix="linux-arm"; else suffix="linux-arm64"; fi
  fi
  if [[ "${machine:-}" =~ armv ]];    then suffix="linux-arm"; fi
  if [[ "${machine:-}" =~ x86\_64 ]]; then 
    if [[ "${long:-}" == "32" ]]; then suffix="linux-x86"; else suffix="linux-x64"; fi
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    suffix="mac"
  fi


  local    url_hash="https://master.dl.sourceforge.net/project/p7zz-repack/7z2107-${suffix}.tar.${COMPRESSOR_EXT}.${alg}?viasf=1"
  local url_archive="https://master.dl.sourceforge.net/project/p7zz-repack/7z2107-${suffix}.tar.${COMPRESSOR_EXT}?viasf=1"

  # get hash
  DOWNLOAD_SHOW_PROGRESS=False
  local user="${USER:-$(whoami)}"
  local tmp_hash_file="${TMPDIR}/7z2107-${suffix}-for-${user}"
  download_file "$url_hash" "$tmp_hash_file"
  local hash="$(cat "$tmp_hash_file" | awk 'NR==1 {print $NF}')"
  if [[ -z "${hash:-}" ]] || [[ "${#hash}" -lt 32 ]]; then hash="<error>"; fi
  rm -f "$tmp_hash_file" || true
  echo "Downloading 7z 21.04 for ${suffix} details:
  arch: ${suffix}
  url: $url_archive
  directory: ${INSTALL_DIR}
  integrity algorithm: ${alg}
  integrity hash: ${hash}
  temp download dir: ${TMPDIR}"
  
  # get archive
  DOWNLOAD_SHOW_PROGRESS=True
  local tmp_file="${TMPDIR}/7z2107-${suffix}-for-${user}.tar.${COMPRESSOR_EXT}"
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
    echo "${alg} hash is correct. Extracting 7z 21.07 to [$INSTALL_DIR]"
  fi

  mkdir -p "$INSTALL_DIR"
  pushd "$INSTALL_DIR" >/dev/null
    cat "$tmp_file" | eval $COMPRESSOR_EXTRACT | smart_sudo tar xf -
  popd >/dev/null
  rm -f "$tmp_file"

  # 7zz OK?
  local  ok7zz="$(check_up_is_7z_executable_works "${INSTALL_DIR}/7zz")"
  echo "Check up ${INSTALL_DIR}/7zz: $ok7zz"
  if [[ "$ok7zz" != "OK" ]]; then
    echo " ... deleting ${INSTALL_DIR}/7zz"
    smart_sudo rm -f "${INSTALL_DIR}/7zz"
  fi

  # 7zzs OK? missed on mac
  local ok7zzs=""
  if [[ -e "${INSTALL_DIR}/7zzs" ]]; then
      ok7zzs="$(check_up_is_7z_executable_works "${INSTALL_DIR}/7zzs")"
      echo "Check up ${INSTALL_DIR}/7zzs: $ok7zzs"
      if [[ "$ok7zzs" != "OK" ]]; then
        echo " ... deleting ${INSTALL_DIR}/7zzs"
        smart_sudo rm -f "${INSTALL_DIR}/7zzs"
      fi
  fi

  if [[ "$ok7zz" == "OK" ]] || [[ "$ok7zzs" == "OK" ]]; then
    export PATH="$INSTALL_DIR:$PATH"
    echo "Added $INSTALL_DIR to the PATH var"
  fi

  if [[ -n "${LINK_AS_7Z:-}" ]]; then
      local linkTo=""
      if [[ "$ok7zzs" == "OK" ]]; then linkTo="${INSTALL_DIR}/7zzs"; fi
      if [[ "$ok7zz"  == "OK" ]]; then linkTo="${INSTALL_DIR}/7zz"; fi
      if [[ -n "${linkTo:-}" ]]; then
          echo '#!/usr/bin/env sh
"'$linkTo'" "$@"' | smart_sudo tee "${LINK_AS_7Z:-}" >/dev/null
          smart_sudo chmod +x "${LINK_AS_7Z:-}"
          echo "Added the "${LINK_AS_7Z:-}" sh-link to $linkTo"
      else
         echo "Both 7zz and 7zzs are not usable. Can't create 7z shell link"
      fi
  fi
}

install_7zz
