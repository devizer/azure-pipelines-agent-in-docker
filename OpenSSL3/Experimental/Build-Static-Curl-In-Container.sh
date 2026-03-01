apk add wget clang lld libc-dev cmake openssl-dev openssl-libs-static zlib-static brotli-static zstd-static make file

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

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/curl-8 \
  -DBUILD_SHARED_LIBS=OFF \
  -DCURL_STATICLIB=ON \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DUSE_OPENSSL=ON \
  -DUSE_NGHTTP2=ON \
  -DUSE_ZLIB=ON \
  -DUSE_BROTLI=ON \
  -DUSE_ZSTD=ON \
  -DCURL_USE_LIBPSL=OFF \
  -DHTTP_ONLY=OFF \
  -DCURL_DISABLE_FTP=OFF \
  -DCURL_DISABLE_FILE=OFF \
  -DCURL_DISABLE_LDAP=ON \
  -DCURL_DISABLE_RTSP=ON \
  -DCURL_DISABLE_PROXY=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-static"

cmake --build build --config Release -j$(nproc)
cmake --install build
echo; file /opt/curl-8/bin/curl; echo; /opt/curl-8/bin/curl --version; echo; /opt/curl-8/bin/curl -I https://google.com; echo; ls -lah /opt/curl-8/bin/curl

strip /opt/curl-8/bin/curl; echo; ls -lah /opt/curl-8/bin/curl

public_name="curl-$(apk info --print-arch)"
cp -v /opt/curl-8/bin/curl "${SYSTEM_ARTIFACTSDIRECTORY:-}/$public_name"
/opt/curl-8/bin/curl --version > "${SYSTEM_ARTIFACTSDIRECTORY:-}/curl-version.txt"
apk info --print-arch > "${SYSTEM_ARTIFACTSDIRECTORY:-}/curl-arch.txt"
