# https://cmake.org/cmake/help/v3.7/module/FindOpenSSL.html
# https://github.com/Kitware/CMake/blob/master/Modules/FindOpenSSL.cmake
# docker run -it --rm alpine:edge sh -c "apk add bash nano mc; export PS1='\w # '; bash"
apk upgrade
time apk add build-base perl pkgconfig make clang clang-static cmake ncurses-dev ncurses-static linux-headers mc nano \
  openssl-dev openssl-libs-static \
  nghttp2-dev nghttp2-static libssh2-dev libssh2-static \
  zlib-dev zlib-static bzip2-dev bzip2-static curl expat-dev expat-static \
  libarchive-dev libarchive-static

url=https://github.com/Kitware/CMake/releases/download/v3.22.2/cmake-3.22.2.tar.gz
work=$HOME/build/cmake; mkdir -p "$work"; cd $work
curl -kSL -o /tmp/_cmake.tar.gz "$url"
tar xzf /tmp/_cmake.tar.gz
cd cmake*
mkdir -p out; cd out

export CC=clang CXX=clang++ CFLAGS="-Oz" LDFLAGS="-static" CFLAGS="-O0"
rm -rf *; time cmake -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX=/opt/cmake \
  -DBUILD_TESTING:BOOL=OFF -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DOPENSSL_ROOT_DIR=/usr \
  .. 2>&1 | tee ~/my-cmake.log

time make install -j5 CFLAGS="-Oz" LDFLAGS="-static -all-static" |& tee my-make.log
ldd /opt/cmake/bin/cmake
