#!/usr/bin/env bash
echo ":ssl_verify_mode: 0" | tee -a ~/.gemrc
source /etc/os-release
if [[ "$VERSION_ID" == "8" && "$ID" == "debian" ]]; then
    if [[ "$(uname -m)" == arm* ]]; then
        mkdir -p /opt
        pushd /opt
        url=https://raw.githubusercontent.com/devizer/glist/master/bin/portable-ruby-2.6.0-armhf-jessie.tar.gz
        file=$(basename $url)
        Say "Downloading [$url] to $(pwd)/${file}"
        wget -q -nv --no-check-certificate -O _$file $url 2>/dev/null || curl -ksSL -o _$file $url
        tar xzf _$file
        rm -f _$file
        export PATH="/opt/portable-ruby/bin:$PATH"
        echo /opt/portable-ruby/bin > /etc/agent-path.d/ruby
        Say "Installing dpl dpl-releases dpl-bintray via gem"
        gem install dpl dpl-releases dpl-bintray
        popd
    elif [[ "$(uname -m)" == x86_64 ]]; then
        smart-apt-install install curl wget gnupg2 sudo mc ncdu nano software-properties-common -y;
        Say "Attaching ppa:brightbox/ruby-ng for ruby 2.5"
        echo "" | sudo add-apt-repository ppa:brightbox/ruby-ng; 
        pushd /etc/apt/sources.list.d; for f in *; do sed -i 's/jessie/trusty/g' $f; done; popd; 
        sudo apt-get update
        Say "Installing ruby 2.5";
        apt-get install ruby2.5-dev ruby2.5 -y
        ruby --version
        gem --version
        Say "Installing dpl dpl-releases dpl-bintray via gem"
        gem install dpl dpl-releases dpl-bintray
        # remove ruby repo
        Say "Removing ruby repo"
        pushd /etc/apt/sources.list.d; rm -f *ruby* || true; popd;
    else
        Say "Skipping dpl, dpl-releases, dpl-bintray on Debian Jessie on $(uname -m)";
    fi
else
    Say "Installing ruby-dev via apt"
    # gem=$(apt-cache search gem | grep -E '^gem ' | awk '{print $1}')
    sudo apt-get install -y ruby-dev
    Say "Installing dpl dpl-releases dpl-bintray via gem"
    sudo gem install dpl dpl-releases dpl-bintray
fi