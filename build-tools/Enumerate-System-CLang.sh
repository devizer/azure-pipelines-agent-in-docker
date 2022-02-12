apt-get update -q; apt-get install mc nano htop ncdu -y

SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds/Enumerate-GCC}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

clang_packages="$(apt-cache search --names-only clang | awk '{print $1}' | grep -E '^clang[0-9\.\-]*$' | sort -V -r | awk '$1=$1' ORS=' ')"
echo "CLang Packages: $clang_packages" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/clang.packages.result"
for p in $clang_packages; do 
  apt-get install $p -y; 
  pushd /usr/bin >/dev/null
    clang_executables="$(ls -1 clang* | grep -E '^clang[0-9\.\-]*$' | sort -V -r | awk '{print "/usr/bin/" $1}' | awk '$1=$1' ORS=' ')"
    echo "CLang Executables for the [$p] packages: [$clang_executables]" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/executables.for-$p.result"
  popd >/dev/null
  for clang_exe in $clang_executables; do
    exe="$(basename "${clang_exe}")"
    folder="$SYSTEM_ARTIFACTSDIRECTORY/$exe-from-the-$p-package"
    mkdir -p "$folder"
    echo "${clang_exe}: $("${clang_exe}" --version | head -1)" 2>&1 |& tee "$folder/$exe.version.result"
    echo $p |& tee "$folder/package.name"
  done
  apt-get purge $p -y;
done
# time apt-get install $clang_packages -y
