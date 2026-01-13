set -eu; set -o pipefail
image="$1"
Say "TESTING on IMAGE [$image]"
Download() {
  local url="$1"; local file="$(basename "$url")"
  echo "Downloading '$url' as $(pwd -P)/$file"
  try1="wget -q -nv --no-check-certificate -O $file $url 2>/dev/null 1>&2 || curl -kfsSL -o $file $url 2>/dev/null 1>&2"
  eval $try1 || eval $try1 || eval $try1
}
saveTo="$(mktemp -d)"; 
cp -v *.sh "$saveTo"/
cd "$saveTo"
Download https://devizer.github.io/Install-DevOps-Library.sh
Download https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh
Download https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1
docker run -t -v $(pwd -P):/app -w /app "$image" sh -e -c '
  if [ -n "$(command -v apk)" ]; then apk update; apk add bash; fi
  if [ -n "$(command -v apt-get)" ]; then apt-get update -qq; apt-get install wget -y -qq | { grep Setting || true; }; fi
  bash install-build-tools-bundle.sh; 
  bash Install-DevOps-Library.sh; 
  Wait-For-HTTP https://google-777.com 1 || echo "ERROR AS EXPECTED: https://google-777.com"; 
  Wait-For-HTTP https://google.com 1;
  for test in "[Test] ALL.sh" "[Test] Download.sh" "[Test] Fetch S5 Dashboard API.sh" "[Test] Retry.sh" "[Test] Run-Remote-Script.sh" "[Test] Validate File Is Not Empty.sh" "[Test] Wait For Http.sh" ; do
    echo "________________________________________________";
    Colorize Magenta "RUNNING $test"
    bash "$test"
  done
'
