export DEBIAN_FRONTEND=noninteractive
echo "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
time apt-get update
time apt-get install sudo less fontconfig mc htop ncdu p7zip software-properties-common sudo aria2 curl -y

add-apt-repository ppa:apt-fast/stable
apt-get update
apt-get -y install apt-fast

time apt-fast install -y $(apt-cache search font | awk '{print $1}' | grep font | grep -v "fontforge-nox\|scalable-cyrfonts-tex")

fc-list :spacing=100 | tee $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt
