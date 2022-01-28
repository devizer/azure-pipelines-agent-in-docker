set -eu
# sudo apt-get install make autoconf build-essential libtool sudo wget curl htop mc cmake pv jq p7zip xz-utils -y -q
smart-apt-install build-essential gettext zlib1g-dev

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

url=https://ftp.gnu.org/gnu/bash/bash-5.1.tar.gz
url=https://ftp.gnu.org/gnu/bash/bash-5.1.16.tar.gz

Say "Installing [$url] for [$(uname -a)]"
file=$(basename $url)
work=$HOME/build/bash-stable-src
mkdir -p $work
pushd $work >/dev/null
wget -q --no-check-certificate -O _$file "$url"  || curl -kfSL -o _$file "$url"
tar xzf _$file
rm -f _$file
cd bash*

pre="${INSTALL_PREFIX}"
./configure --prefix="$pre" --without-bash-malloc
# --build=$(support/config.guess)


# time make prefix=$pre all -j
# sudo make prefix=$pre install -j
time make all -j
sudo make install -j

popd
rm -rf $work

strip $pre/bin/bash
# ln -s -f $pre/bin/bash /usr/bin/bash
# ln -s -f $pre/bin/bash /bin/bash

# /usr/bin/bash -c 'echo $BASH_VERSION'
# /bin/bash -c 'echo $BASH_VERSION'

Say "BASH VERSION: $("$pre/bin/bash" -c 'echo $BASH_VERSION')"


