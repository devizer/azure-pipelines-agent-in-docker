if [[ -z "$(command -v python3 || true)" ]]; then
    smart-apt-install python3 || true
fi
script="https://bootstrap.pypa.io/get-pip.py"
wget -q -nv --no-check-certificate -O "/tmp/get-pip.py" $script 2>/dev/null || curl -ksSL $script -o "/tmp/get-pip.py"
python3 /tmp/get-pip.py
