set -eu; set -o pipefail
export DEBIAN_FRONTEND=noninteractive
echo "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
time apt-get update
time apt-get install sudo less fontconfig mc htop ncdu p7zip-full software-properties-common sudo aria2 curl -y | grep "Setting\|Unpack"

# add-apt-repository ppa:apt-fast/stable
# apt-get update
# apt-get -y install apt-fast | grep "Setting"

# grep -v 'font-manager\|font-manager-common\|font-viewer\|gnome-font-viewer\|thunar-font-manager\|nemo-font-manager\|nautilus-font-manager\|birdfont\|fontforge\|trufont\|open-font-design-toolkit\|fontcustom\|bumpfontversion\|emacs-intl-fonts\|elpa-clojure-mode-extra-font-locking\|fluid-soundfont-gm\|fluid-soundfont-gs\|musescore-general-soundfont\|musescore-general-soundfont-large\|musescore-general-soundfont-small\|timgm6mb-soundfont\|font-downloader\|dvi2ps'

fonts="$(apt-cache search font | awk '{print $1}' | grep font | grep -v 'fonts-ubuntu-classic' | grep -v "fontforge-nox\|scalable-cyrfonts-tex\|python\|texlive\|node-webfont" | grep -v 'font-manager\|font-manager-common\|font-viewer\|gnome-font-viewer\|thunar-font-manager\|nemo-font-manager\|nautilus-font-manager\|birdfont\|fontforge\|trufont\|open-font-design-toolkit\|fontcustom\|bumpfontversion\|emacs-intl-fonts\|elpa-clojure-mode-extra-font-locking\|fluid-soundfont-gm\|fluid-soundfont-gs\|musescore-general-soundfont\|musescore-general-soundfont-large\|musescore-general-soundfont-small\|timgm6mb-soundfont\|font-downloader\|dvi2ps')"
echo;
echo "FONTS"
echo $fonts
time apt-get install -y --no-install-recommends $fonts # | grep "Unpack\|Setting"
echo "DONE: apt-get install <fonts>"
echo "BUILD ARTIFACTS to [$SYSTEM_ARTIFACTSDIRECTORY]"

fc-list :spacing=100 | sort | tee $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt

mkdir /tmp/fonts
fc-list :spacing=100 | sort | awk -F':' '{print $1}' | grep -i -E '(ttf|otf)$' | while IFS='' read -r file; do
  name="$(basename "$file")"
  cp -f "$file" "/tmp/fonts/$name"
done

7z a "$SYSTEM_ARTIFACTSDIRECTORY"/mono-fonts.7z /tmp/fonts $SYSTEM_ARTIFACTSDIRECTORY/mono-fonts-raw.txt
