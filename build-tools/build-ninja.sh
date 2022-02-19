set -eu; set -o pipefail
# needs cmake 3.15

Say "Install Ninja into $INSTALL_DIR"

echo '
https://github.com/Baeldung/kotlin-tutorials/tarball/master
https://github.com/ninja-build/ninja/archive/refs/heads/master.zip
https://github.com/ninja-build/ninja/tarball/v1.10.2
https://github.com/ninja-build/ninja/tarball/release
https://github.com/ninja-build/ninja/tarball/master
https://github.com/ninja-build/ninja/archive/refs/tags/v1.10.2.zip
' >/dev/null

work=$HOME/build/ninja-src
mkdir -p $work
pushd $work && rm -rf *
# curl?
err=0;
try-and-retry curl -o _ninja.tar.gz -k -sSL https://github.com/ninja-build/ninja/tarball/release &&
  tar xzf _ninja.tar.gz &&
  cd ninja* || err=1
# git?
if [[ $err -ne 0 ]]; then
  git clone git://github.com/ninja-build/ninja.git &&
  cd ninja &&
  git checkout release || err=2
fi
test $err -ne 0 && echo error $err

# cat README.md
# time cmake -Bbuild-cmake; time cmake --build build-cmake
Say "Building ninja using cmake $(cmake --version | head -1)" 
mkdir build-cmake; cd build-cmake
time (cmake ..; make -j)
if [[ "${SKIP_NINJA_TESTS:-}" != True ]]; then
  Say "Testing ninja" 
  ./ninja_test
else
  Say --Display-As=Error "Warning! ./ninja_test skipped"
fi
Say "ninja: $(./ninja --version)" 
strip ninja || true
cp -f ninja "$INSTALL_DIR/bin/"
popd

