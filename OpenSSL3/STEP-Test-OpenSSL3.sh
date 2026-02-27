SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/Functions.sh"


Build-Test-Image() {
  Say "BUILDING 'openssl-test-image' image from $IMAGE"
  if [[ "$(uname -m)" == x86_64 ]]; then
      Say "Check if [qemu-user-static] is installed"
      sudo try-and-retry apt-get update -qq
      sudo try-and-retry apt-get install qemu-user-static -y -qq >/dev/null
      Say "Register qemu user static"
      docker pull -q multiarch/qemu-user-static:register
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  fi


  sudo swapon 2>/dev/null || true
  Download-File https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh install-build-tools-bundle.sh
  Download-File https://devizer.github.io/Install-DevOps-Library.sh Install-DevOps-Library.sh

  
  docker build --build-arg BASE_IMAGE=$IMAGE -f Dockerfile.TEST-OpenSSL3 -t openssl-test-image .
}

docker run --rm openssl-test-image bash -c 'echo;
  Say "Get-NET-RID - [$(Get-NET-RID)]"
  Say "Get-Linux-OS-ID - [$(Get-Linux-OS-ID)]"
  Say "Get-Linux-OS-Architecture - [$(Get-Linux-OS-Architecture)]"
'

if [[ "${ARG_SET:-}" == "X64_ONLY" && "${IMAGE:-}" == *":arm"* ]]; then
  echo "SKIPPING ARM on X64_ONLY Workflow"
  exit 0
fi
