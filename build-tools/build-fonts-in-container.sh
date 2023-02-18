export DEBIAN_FRONTEND=noninteractive
echo "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
time apt-get update
time apt-get install less fontconfig mc htop ncdu p7zip -y

time apt-get install -y $(apt-cache search font | awk '{print $1}' | grep font | grep -v "fontforge-nox\|scalable-cyrfonts-tex")

fc-list :spacing=100 | tee $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt
