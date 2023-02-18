time apt-get update
time apt-get install less fontconfig mc htop ncdu p7zip -y

time apt-get install -y $(apt-cache search font | awk '{print $1}' | grep font | grep -v "fontforge-nox\|scalable-cyrfonts-tex")
