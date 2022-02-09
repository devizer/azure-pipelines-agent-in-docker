# https://github.com/nmilosev/termux-fedora/blob/master/termux-fedora.sh
# image="debian:8"
# image="multiarch/debian-debootstrap:arm64-jessie"
# image="arm64v8/debian:8"
# KEY=rootfs-debian-8-arm64
# [[ "$(command -v jq)" == "" ]] && apt-get install jq -y
set -e; set -u; set -o pipefail

SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"


sudo apt-get install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/local/bin bash > /dev/null
smart-apt-install rsync pv sshpass jq qemu-user-static -y -qq >/dev/null

Say "Registering binary formats for qemu-user-static"
docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
# docker buildx imagetools inspect --raw "$image" | jq

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done

function replace_links_to_relative() {
  dir="$1"
  pushd "$dir" > /dev/null
  links="$(find . -type l)"
  for l in $links; do
      root="$(pwd)"
      target="$(readlink "$l")"
      if [[ "$target" == "/"* ]]; then
        tmp1="${l//[^\/]}"
        depth="${#tmp1}" n=$depth
        prefix=""
        while [ $n -gt 1 ]; do prefix="$prefix../"; n=$((n-1)); done
        prefix="${prefix::-1}"
        new_target="${prefix}${target}"
        # example: cd ....; ln -s ../some/other/file linkname
        cd "$(dirname "${l}")"
          cmd="cd $(pwd); ln -f -s $new_target $(basename "$l")"
          pwd="$(pwd)"
        echo "$target <-- $l [$depth] ($pwd) $new_target"
        echo $cmd
        eval "$cmd" || true
        echo ""
      fi
      cd "$root"
  done
  popd > /dev/null
}

function prepare_proot() {
work="$HOME/root-fs/$KEY"
mkdir -p "$work"
rm -rf "$work/*"
docker run --rm --privileged multiarch/qemu-user-static:register --reset >/dev/null
docker rm -f container-$KEY || true
Say "Start container [$IMAGE] for [$KEY]"
tmp=/tmp/proot-$KEY
mkdir -p $tmp; rm -rf $tmp/*
docker run -d --privileged --hostname "container-$KEY" --name "container-$KEY" -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static "$IMAGE" bash -c 'while [ 1 -eq 1 ] ; do echo ...; sleep 1; done'
for cmd in Say try-and-retry; do
  docker cp /usr/local/bin/$cmd "container-$KEY":/usr/bin/$cmd
done
docker cp /tmp/build-gcc-utilities.sh "container-$KEY":/tmp/build-gcc-utilities.sh

cat <<-'EOF' > /tmp/provisioning-$KEY
  set -e
  Say --Reset-Stopwatch
  
  source /tmp/build-gcc-utilities.sh
  prepare_os
  
  # adjust_os_repo; configure_os_locale; apt-get install curl get -y -qq
  script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | TARGET_DIR=/usr/bin bash >/dev/null

  function apt-mini-log {
    grep "Unpacking\|Setting"
  }

  Say "aria2"
  apt-get install aria2 -y -qq | apt-mini-log

  Say "FOR HTOP on $KEY"
  apt-get install -y -qq libncurses5 libncurses5-dev ncurses-bin | apt-mini-log
  apt-get install -y -qq libncursesw5 libncursesw5-dev | apt-mini-log

  Say "FOR GIT on $KEY"
  apt-get install git libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip -y -qq | apt-mini-log

  rm -rf /var/cache/apt/*;
  rm -rf /var/lib/apt/*

  source /etc/os-release
  os_ver="${ID:-}:${VERSION_ID:-}"
  if false && [[ "$os_ver" == "debian:7" ]] || [[ "$os_ver" == "debian:8" ]]; then
    Say "BZIP2 for $KEY"
    work=/rmp/bzip-src
    mkdir -p "$work"
    pushd "$work"
    git clone git://sourceware.org/git/bzip2.git
    cd bzip2*
    time make -j install
    popd
    rm -rf "$work"
  fi

  if [[ "$(getconf LONG_BIT)" == "32" ]]; then
    Say "FAKE UNAME on $KEY"
    uname="$(command -v uname)"
    sudo cp "${uname}" /usr/bin/uname-bak;
    script=https://raw.githubusercontent.com/devizer/glist/master/Fake-uname.sh;
    cmd="(wget --no-check-certificate -O /tmp/Fake-uname.sh $script 2>/dev/null || curl -kSL -o /tmp/Fake-uname.sh $script)"
    eval "$cmd || $cmd || $cmd" && sudo cp /tmp/Fake-uname.sh /usr/bin/uname && sudo chmod +x /usr/bin/uname; echo "OK"
  fi

  Say "uname -m: [$(uname -m)]"

  Say "FOR DotNet Core"
  url=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-dependencies.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | UPDATE_REPOS="" bash -e && echo "Successfully installed .NET Core Dependencies"

  if [[ "$os_ver" != "debian:7" ]]; then
    apt-get install libcurl3-gnutls -y | apt-mini-log || true #  FOR GIT 'error while loading shared libraries: libcurl-gnutls.so.4'
    Say "TOOLS (jq git bash 7z nano) for [$(uname -m)]"
    export INSTALL_DIR=/usr/local TOOLS="bash git jq 7z nano"; script="https://master.dl.sourceforge.net/project/gcc-precompiled/build-tools/Install-Build-Tools.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
  fi

  Say "COMPLETE on $KEY"

EOF

docker cp /tmp/provisioning-$KEY "container-$KEY":/tmp/provisioning-$KEY
docker exec -t "container-$KEY" bash -e -c "export KEY=$KEY; source /tmp/provisioning-$KEY" | tee $work.build.log

rm -rf $work/*; rm -rf $work/*; 
docker cp container-$KEY:/. $work
docker rm -f container-$KEY
cat $work/etc/os-release
source $work/etc/os-release
local os_ver="${ID:-}:${VERSION_ID:-}"


echo '

if [ ! -z "$BASH" ]
then
  export PS1="\[\033[01;31m\]\u@'$KEY'\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] "
fi

export LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
if [[ ! -d $HOME/bin ]]; then mkdir -p $HOME/bin; fi
export PATH="$HOME/bin:$PATH"
export TMPDIR=/tmp

' | tee -a $work/root/.bashrc

echo "nameserver 8.8.8.8" > $work/etc/resolv.conf

# CLEAN UP
rm -f $work/usr/bin/qemu-*-static
rm -rf $work/tmp/*
sudo rm -rf $work/var/log/* $work/var/tmp/*

  Say "Do Not Replace aboslute simlinks to relative [$work]"
  Say " ... in $(pwd)"
  # [[ "$(command -v symlinks)" == "" ]] && apt-get install -y -q symlinks
  # chroot /home/user/system symlinks -cr .
  sudo chown -R $(whoami) "$work"
  # replace_links_to_relative "$work"
  
  Say "Pack $IMAGE as [$work.tar.xz]"
  Say " ... in $(pwd)"
  sudo chown -R root:root "$work"
  pushd $work
  # 8 threads need 8 Gb of RAM
  sudo tar cf - . | pv | xz -z -9 -e --threads=2 > $work.tar.xz
  popd

  Say "Copy artifact"
  cp -f $work.tar.xz $SYSTEM_ARTIFACTSDIRECTORY/$(basename $work.tar.xz)
  Say "Done artifact: $KEY"

}

KEY="debian-8-arm32v7"  IMAGE="arm32v7/debian:8"  prepare_proot

KEY="debian-7-arm32v7"  IMAGE="arm32v7/debian:7"  prepare_proot

KEY="debian-8-arm64"    IMAGE="arm64v8/debian:8"  prepare_proot

KEY="debian-11-arm64"   IMAGE="arm64v8/debian:11" prepare_proot
KEY="debian-11-arm32v7" IMAGE="arm64v8/debian:11" prepare_proot

KEY="debian-10-arm64"   IMAGE="arm64v8/debian:10" prepare_proot
KEY="debian-10-arm32v7" IMAGE="arm64v8/debian:10" prepare_proot

KEY="debian-9-arm64"   IMAGE="arm64v8/debian:9" prepare_proot
KEY="debian-9-arm32v7" IMAGE="arm64v8/debian:9" prepare_proot

