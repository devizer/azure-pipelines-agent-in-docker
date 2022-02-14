url=https://github.com/Kitware/CMake/releases/download/v3.22.2/cmake-3.22.2.tar.gz
work=$HOME/build/automake-src
mkdir -p "$work"
pushd .
cd $work && rm -rf *
curl -kSL -o _cmake.tar.gz "$url"
tar xzf _cmake.tar.gz
cd cmake*
# minimum: gcc 5.5
export CC=gcc CXX="c++" LD_LIBRARY_PATH="/usr/local/lib/"
time ./bootstrap --parallel=5 --prefix=/opt/local-links/cmake -- -DCMAKE_BUILD_TYPE:STRING=Release # 22 minutes
make -j$(nproc)
# sudo make install -j
sudo bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; make install -j"
popd
rm -rf "$work"
