# https://cmake.org/cmake/help/v3.7/module/FindOpenSSL.html
# https://github.com/Kitware/CMake/blob/master/Modules/FindOpenSSL.cmake
# docker run -it --rm alpine:edge sh -c "apk add bash nano mc; export PS1='\w # '; bash"
Say "PLATFORM: $PLATFORM, CMAKE_VER: $CMAKE_VER"
apk upgrade
time apk add build-base perl pkgconfig make clang clang-static cmake ncurses-dev ncurses-static linux-headers mc nano \
  openssl-dev openssl-libs-static \
  nghttp2-dev nghttp2-static libssh2-dev libssh2-static \
  zlib-dev zlib-static bzip2-dev bzip2-static curl expat-dev expat-static \
  libarchive-dev libarchive-static

url=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz
work=$HOME/build/cmake; mkdir -p "$work"; cd $work
try-and-retry curl -f -kSL -o /tmp/_cmake.tar.gz "$url"
tar xzf /tmp/_cmake.tar.gz
cd cmake*
mkdir -p out; cd out

export CC=clang CXX=clang++ CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static"
# Trash for armv5
if [[ "$PLATFORM" == "armv6" ]]; then
  export CFLAGS="$CFLAGS -march=armv5t" CXXFLAGS="-O2 -march=armv5t"
fi
Say "CFLAGS=[$CFLAGS] CXXFLAGS=[$CXXFLAGS]"

rm -rf *; time cmake -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX=/opt/cmake \
  -DBUILD_TESTING:BOOL=OFF -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DOPENSSL_ROOT_DIR=/usr \
  .. 2>&1 | tee ~/my-cmake.log

time make install -j2 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="-static -all-static" |& tee my-make.log
ldd /opt/cmake/bin/cmake && (Say --Display-As=Error "/opt/cmake/bin/cmake is not static"; exit 13) || true
ls -la /opt/cmake/bin/
/opt/cmake/bin/cmake --version
Say "Stripped copy: /opt/cmake-stripped"
cp -r /opt/cmake /opt/cmake-stripped
strip /opt/cmake-stripped/bin/*
Say "DONE: Static Portable CMake"
