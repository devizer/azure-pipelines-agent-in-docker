set -e
set -u
set -o pipefail

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done
source /tmp/build-gcc-utilities.sh

urls="https://www.7-zip.org/a/7z2107-linux-x64.tar.xz
https://www.7-zip.org/a/7z2107-linux-x86.tar.xz
https://www.7-zip.org/a/7z2107-linux-arm64.tar.xz
https://www.7-zip.org/a/7z2107-linux-arm.tar.xz
https://www.7-zip.org/a/7z2107-mac.tar.xz"



work="$HOME/repack-7zz"
mkdir -p $work
cd $work
for url in $urls; do
  file="$(basename "$url")"
  tar="${file%.*}"
  curl -kSL -o $file "$url"
  cat $file | xz -d | gzip -9 > "$tar.gz"
  cat $file | xz -d | bzip2 -9 > "$tar.bz2"
  for ext in gz bz2 xz; do
    build_all_known_hash_sums "$tar.$ext"
  done 
done
