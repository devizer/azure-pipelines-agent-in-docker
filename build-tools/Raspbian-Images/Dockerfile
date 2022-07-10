# docker run --rm --privileged multiarch/qemu-user-static:register --reset; 
# time docker build -t devizervlad/armv6:raspberry-wheezy -t devizervlad/armv6:raspberry-latest .
FROM scratch
ADD ./files/. /
RUN Say "FIRST Packages"; list-packages; bash -e -c "source /tmp/build-gcc-utilities.sh; adjust_os_repo" && apt-get update && Say "FINAL Packages" && list-packages
ENTRYPOINT ["/bin/bash", "-c"]
