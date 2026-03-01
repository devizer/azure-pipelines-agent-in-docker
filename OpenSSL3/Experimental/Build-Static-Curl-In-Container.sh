set -eu; set -o pipefail

apk add wget clang lld libc-dev cmake openssl-dev openssl-libs-static zlib-dev zlib-static brotli-dev brotli-static zstd-dev zstd-static make file

work=$HOME/build/curl
mkdir -p $work
cd $work && rm -rf *

ver=8_18_0
url=https://codeload.github.com/curl/curl/tar.gz/refs/tags/curl-$ver
wget --no-check-certificate -O _src.tar.gz $url
tar xzf _src.tar.gz
cd curl*

export OPENSSL_USE_STATIC_LIBS=TRUE
export CMAKE_FIND_LIBRARY_SUFFIXES=".a"

ARTIFACTS_SUFFIX="${ARTIFACTS_SUFFIX:-$(apk info --print-arch)}"
public_name="curl-$ARTIFACTS_SUFFIX-static"


cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/curl-8 \
  -DBUILD_SHARED_LIBS=OFF \
  -DCURL_STATICLIB=ON \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DUSE_OPENSSL=ON \
  -DUSE_NGHTTP2=ON \
  -DUSE_ZLIB=ON \
  -DZLIB_LIBRARY=/usr/lib/libz.a \
  -DZLIB_INCLUDE_DIR=/usr/include \  -DUSE_BROTLI=ON \
  -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
  -DUSE_ZSTD=ON \
  -DCURL_USE_LIBPSL=OFF \
  -DHTTP_ONLY=OFF \
  -DCURL_DISABLE_FTP=OFF \
  -DCURL_DISABLE_FILE=OFF \
  -DCURL_DISABLE_LDAP=ON \
  -DCURL_DISABLE_RTSP=ON \
  -DCURL_DISABLE_PROXY=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-static" | tee "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name-configure.log"

cmake --build build --config Release -j$(nproc)
cmake --install build
echo; file /opt/curl-8/bin/curl; echo; /opt/curl-8/bin/curl --version; echo; /opt/curl-8/bin/curl -I https://google.com; echo; ls -lah /opt/curl-8/bin/curl

strip /opt/curl-8/bin/curl; echo; ls -lah /opt/curl-8/bin/curl

cp -v /opt/curl-8/bin/curl "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name"
(echo "PLATFORM: $PLATFORM"; echo; /opt/curl-8/bin/curl --version; echo; file /opt/curl-8/bin/curl;) > "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name-version.txt"
ldd /opt/curl-8/bin/curl 2>&1 > "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name-alpine-dependencies.txt" || true
apk info --print-arch > "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name-arch.txt"
echo "PLATFORM: $PLATFORM" > "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name-platform.txt"


