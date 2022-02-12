#!/usr/bin/env bash
# GIT_VER=${GIT_VER:-v2.26.2}
# GIT_VER=${GIT_VER:-v2.28.0}
GIT_VER=${GIT_VER:-v2.34.1}
# GIT_VER=${GIT_VER:-v2.35.0}
TRANSIENT_BUILDS="${TRANSIENT_BUILDS:-$HOME/build}"
work=$TRANSIENT_BUILDS/build/git-src
mkdir -p $work
pushd $work >/dev/null
smart-apt-install build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext zlib1g-dev unzip 
url=https://codeload.github.com/git/git/zip/$GIT_VER
wget -q --no-check-certificate -O _git-src.zip "$url"  || curl -kfSL -o _git-src.zip "$url"
unzip -q _git-src.zip
rm -f _git-src.zip
cd git*

Say "GCC $(gcc --version)"
cpus=$(nproc)
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
Say "Building [make] GIT [${GIT_VER}] into ${INSTALL_PREFIX} on [$(uname -m)]"
time make prefix="$INSTALL_PREFIX" all -j${cpus}
Say "Building [make install] GIT [${GIT_VER}] into ${INSTALL_PREFIX} on [$(uname -m)]"
time sudo -E make prefix="$INSTALL_PREFIX" install -j${cpus}
if [[ -d "$INSTALL_PREFIX/bin" ]]; then
  Say "Strip $INSTALL_PREFIX/bin/*"
  pushd "$INSTALL_PREFIX/bin"
  sudo strip * || true
  popd
  Say "Strip $INSTALL_PREFIX/libexec/git-core/*"
  pushd "$INSTALL_PREFIX/libexec/git-core"
  sudo strip * || true
  popd
else 
  Say --Display-As=Error "Can't strip, build failed"
fi

popd
rm -rf "$work"

export PATH="$INSTALL_PREFIX/bin:$PATH"
bash -c "git --version"

Say "git version"
git --version
Say "Force git http version to HTTP/1.1"
git config --global http.version HTTP/1.1
Say "git configuration"
git config -l

