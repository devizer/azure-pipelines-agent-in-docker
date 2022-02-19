VER=v4.20.1
output="$HOME/yq-release"
mkdir -p "$output" && rm -rf "$output"/*

for f in build-gcc-utilities.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done
source /tmp/build-gcc-utilities.sh

[[ "$(command -v lynx)" == "" ]] && apt-get install lynx -y -qq

work=$(mktemp -d -t yq-repack-XXXXXXXXXXX)
pushd "$work"
lynx -dump https://github.com/mikefarah/yq/releases/tag/v4.20.1 | awk '/http/ && $NF ~ /\.tar\.gz$/ {print $NF}' | tee links.txt
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
