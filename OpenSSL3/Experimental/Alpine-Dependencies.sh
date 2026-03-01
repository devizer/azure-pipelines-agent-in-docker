# since alpine 3.19 libcrypto.so must not be deleted
for minor in {7..21}; do
  v="3.$minor"
  docker pull -q alpine:$v
  docker run -it --rm alpine:$v sh -c 'apk add coreutils >/dev/null && echo ALPINE '$v'; ldd /usr/bin/dirname'
done 
