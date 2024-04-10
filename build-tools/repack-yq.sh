latestRelease="$(Get-GitHub-Latest-Release mikefarah yq)"
latestRelease="${latestRelease:-v4.43.1}"
VER="$latestRelease"
Say "REPACK LATEST YQ RELEASE: $latestRelease"

output="$HOME/yq-release-repack-$VER"
mkdir -p "$output" && rm -rf "$output"/*

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done
source /tmp/build-gcc-utilities.sh

[[ "$(command -v lynx)" == "" ]] && apt-get install lynx -y -qq

work=$(mktemp -d -t yq-repack-XXXXXXXXXXX)
pushd "$work"
# https://api.github.com/repos/mikefarah/yq/releases/v4.43.1

echo "ALL ASSETS for yq $latestRelease"
Get-GitHub-Latest-Release-Assets mikefarah yq | awk '/http/ && $NF ~ /\.tar\.gz$/ {print $NF}' | tee links.txt
for link in $(cat links.txt | grep "linux\|darwin"); do
  filename1="$(basename "$link")"
  filename="${filename1%.*}"
  filename="${filename%.*}"
  Say "Repak $(printf "%-17s" "$filename") [$link]"
  try-and-retry curl -f -kSL -o _"$filename1" "$link"
  mkdir -p "$filename"
  cd "$filename"
  tar xzf ../_"$filename1"
  sudo chown -R root:root *
  mkdir -p bin; mv yq_* bin/yq || echo ERROR
  mkdir -p share/man/man1; mv yq.1 share/man/man1/yq.1 || echo ERROR
  rm -f *.sh
  tar="$output/${filename}_${VER}.tar"
  tar cf - * | gzip -9 > "$tar.gz"
  tar cf - * | bzip2 -9 > "$tar.bz2"
  tar cf - * | xz -9 -e > "$tar.xz"
  for ext in gz bz2 xz; do
    build_all_known_hash_sums "$tar.$ext"
  done 
  cd ..
done
# popd
