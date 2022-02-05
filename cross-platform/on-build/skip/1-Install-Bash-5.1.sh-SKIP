#!/usr/bin/env bash

url=https://ftp.gnu.org/gnu/bash/bash-5.1.tar.gz
Say "Installing [$url]"
file=$(basename $url)
work=$HOME/build/bash-stable-src
mkdir -p $work
pushd $work >/dev/null
smart-apt-install build-essential gettext zlib1g-dev
wget -q --no-check-certificate -O _$file "$url"  || curl -kfSL -o _$file "$url"
tar xzf _$file
rm -f _$file
cd bash*

pre=/usr/local
./configure --prefix=$pre --without-bash-malloc
# --build=$(support/config.guess)

cpus=$(cat /proc/cpuinfo | grep -E '^(P|p)rocessor' | wc -l)
time make prefix=$pre all -j${cpus}
sudo make prefix=$pre install -j${cpus}

popd
rm -rf $work

strip $pre/bin/bash
ln -s -f $pre/bin/bash /usr/bin/bash
ln -s -f $pre/bin/bash /bin/bash

/usr/bin/bash -c 'echo $BASH_VERSION'
/bin/bash -c 'echo $BASH_VERSION'
