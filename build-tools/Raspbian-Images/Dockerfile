# docker run --rm --privileged multiarch/qemu-user-static:register --reset; 
# time docker build -t devizervlad/armv6:raspberry-wheezy -t devizervlad/armv6:raspberry-latest .
FROM scratch
ADD ./files/. /
RUN apt-get update && list-packages && rm -rf /opt/*
ENTRYPOINT ["/bin/bash", "-c"]
