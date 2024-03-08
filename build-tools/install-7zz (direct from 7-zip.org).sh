set -e
set -u
set -o pipefail

TMPDIR="${TMPDIR:-/tmp}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
LINK_AS_7Z="${LINK_AS_7Z:-}"
# Either 2107 or 2301
VERSION_7Z="${VERSION_7Z:-2301}"

function smart_sudo() {
  if [[ "$(command -v sudo)" ]]; then 
    sudo "$@"
  else
    eval "$@"
  fi
}

function check_7z_executable() {
  local bin="$1"
  local work="$TMPDIR/check_7z_executable-$(basename "$bin")"
  mkdir -p "$work"
  pushd "$work" >/dev/null
  printf "42" >42.txt
  "$bin" a 42.7z 42.txt 1>/dev/null 2>&1
  mkdir -p extracted; 
  cd extracted
  rm -f 42.txt
  "$bin" x -y ../42.7z >/dev/null 2>&1
  local actual="$(cat 42.txt 2>/dev/null)"
  popd >/dev/null
  # rm -rf "$work"
  if [[ "$actual" == 42 ]]; then echo "OK"; else echo "Error"; fi
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
  local  url_x86_64="https://www.7-zip.org/a/7z${VERSION_7Z}-linux-x64.tar.xz"
  local    url_i686="https://www.7-zip.org/a/7z${VERSION_7Z}-linux-x86.tar.xz"
  local url_aarch64="https://www.7-zip.org/a/7z${VERSION_7Z}-linux-arm64.tar.xz"
  local     url_arm="https://www.7-zip.org/a/7z${VERSION_7Z}-linux-arm.tar.xz"
  local     url_osx="https://www.7-zip.org/a/7z${VERSION_7Z}-mac.tar.xz"
  local machine="$(uname -a)"
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
    suffix="max"
  fi

  local url="https://www.7-zip.org/a/7z${VERSION_7Z}-${suffix}.tar.xz"
  local file="${TMPDIR}/$(basename "$url")"
  echo "Downloading $url"
  DOWNLOAD_SHOW_PROGRESS=True download_file "$url" "$file"

  pushd "${INSTALL_DIR}" >/dev/null
  smart_sudo tar xJf "$file"
  popd >/dev/null
  rm -f "$file"

  # 7zz OK?
  local  ok7zz="$(check_7z_executable "${INSTALL_DIR}/7zz")"
  echo "Check ${INSTALL_DIR}/7zz:  $ok7zz"
  if [[ "$ok7zz" != "OK" ]]; then
    echo "Deleting ${INSTALL_DIR}/7zz"
    rm -f "${INSTALL_DIR}/7zz"
  fi

  # 7zzs OK?
  local ok7zzs="$(check_7z_executable "${INSTALL_DIR}/7zzs")"
  echo "Check ${INSTALL_DIR}/7zzs: $ok7zzs"
  if [[ "$ok7zzs" != "OK" ]]; then
    echo "Deleting ${INSTALL_DIR}/7zzs"
    rm -f "${INSTALL_DIR}/7zzs"
  fi

  if [[ "$ok7zzs" == "OK" ]] || [[ "$ok7zzs" == "OK" ]]; then
    export PATH="$INSTALL_DIR:$PATH"
    echo "Added $INSTALL_DIR to PATH var"
  fi

  if [[ -n "${LINK_AS_7Z:-}" ]]; then
      local linkTo=""
      if [[ "$ok7zzs" == "OK" ]]; then linkTo="${INSTALL_DIR}/7zzs"; fi
      if [[ "$ok7zz"  == "OK" ]]; then linkTo="${INSTALL_DIR}/7zz"; fi
      if [[ -n "${linkTo:-}" ]]; then
          echo '#!/usr/bin/env sh
"'$linkTo'" "$@"' | smart_sudo tee "${LINK_AS_7Z:-}" >/dev/null
          smart_sudo chmod +x "${LINK_AS_7Z:-}"
          echo "Added the "${LINK_AS_7Z:-}" shell link to $linkTo"
      else
         echo "Both 7zz and 7zzs are not usable. Can't create 7z shell link"
      fi
  fi
}

install_7zz
