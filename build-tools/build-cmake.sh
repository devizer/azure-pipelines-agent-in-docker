sudo apt-get install libssl-dev libncursesw5-dev libncurses5-dev -y -q

INSTALL_DIR="${INSTALL_DIR:-/opt/local-links/cmake}"

mkdir -p "$INSTALL_DIR"; rm -rf "$INSTALL_DIR"/* || rm -rf "$INSTALL_DIR"/* || rm -rf "$INSTALL_DIR"/*

url=https://github.com/Kitware/CMake/releases/download/v3.22.2/cmake-3.22.2.tar.gz
work=$HOME/build/cmake-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _cmake.tar.gz "$url"
tar xzf _cmake.tar.gz
cd cmake*
# minimum: gcc 5.5 for armv7, gcc 9.4 for x86_64
export CC=gcc CXX="c++" LD_LIBRARY_PATH="/usr/local/lib"
test -d /usr/local/lib64 && LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib"
export LD_LIBRARY_PATH
time ./bootstrap --parallel=5 --prefix="${INSTALL_DIR}" -- -DCMAKE_BUILD_TYPE:STRING=Release # 22 minutes
make -j$(nproc)
# sudo make install -j
time sudo -E bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; make install -j"
popd
rm -rf "$work"

function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum "'"$file"'" | awk '{print $1}')
      printf "$sum" > "$file.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}


pushd "$INSTALL_DIR"
mv bin binaries
cd binaries
strip * || true
for lib in /usr/local/lib64 /usr/local/lib; do
for file in libgcc_s.so.1 libstdc++.so.6; do
  test -s "$lib/$file" && cp -f "$lib/$file" .
done
done
cd "$INSTALL_DIR"
Say "pack [$(pwd)] release as gz"
archname="../cmake-3.22.2-$(uname -m)"
tar cf - . | gzip -9 > ${archname}.tar.gz
Say "pack [$(pwd)] release as xz"
tar cf - . | xz -z -9 -e > ${archname}.tar.xz
build_all_known_hash_sums ${archname}.tar.xz
build_all_known_hash_sums ${archname}.tar.gz
popd

exit 0;
echo '
cd /opt/local-links/cmake/bin
# export LD_LIBRARY_PATH=/usr/local/lib; 
printf "" > /tmp/cmake
for exe in ccmake  cmake  cpack  ctest; do ldd -v -r $exe >> /tmp/cmake; done
cat /tmp/cmake | grep "/usr/local" | awk '{print $NF}' | sort -u | while IFS='' read file; do test -e $file && echo $file; done
'

# x86_64
/usr/local/lib64/libgcc_s.so.1
/usr/local/lib64/libstdc++.so.6
# armv7
/usr/local/lib/libgcc_s.so.1
/usr/local/lib/libstdc++.so.6
