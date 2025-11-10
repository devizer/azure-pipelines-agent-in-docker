set -eu; set -o pipefail
export DEBIAN_FRONTEND=noninteractive
echo "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
time apt-get update
time apt-get install sudo less fontconfig mc htop ncdu p7zip-full software-properties-common sudo aria2 curl -y | grep "Setting\|Unpack"

# add-apt-repository ppa:apt-fast/stable
# apt-get update
# apt-get -y install apt-fast | grep "Setting"


time apt-get install -y $(apt-cache search font | awk '{print $1}' | grep font | grep -v "fontforge-nox\|scalable-cyrfonts-tex") # | grep "Unpack\|Setting"
echo "DONE: apt-get install <fonts>"
echo "BUILD ARTIFACTS to [$SYSTEM_ARTIFACTSDIRECTORY]"

fc-list :spacing=100 | sort | tee $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt

mkdir /tmp/fonts
fc-list :spacing=100 | sort | awk -F':' '{print $1}' | grep -i -E 'ttf$' | while IFS='' read -r file; do
  name="$(basename "$file")"
  cp -f "$file" "/tmp/fonts/$name"
done

7z a "$SYSTEM_ARTIFACTSDIRECTORY"/mono-fonts.7z /tmp/fonts $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt
