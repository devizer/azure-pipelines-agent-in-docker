ARG BUILDER_IMAGE
ARG SQL_BASE_IMAGE

FROM ${BUILDER_IMAGE} AS build
SHELL ["/bin/bash", "-c"]
WORKDIR /root
ADD wrapper.c /root/
ADD start-mssql.sh /opt/mssql-memorypolicy-muter/

RUN \
  set -eu; set -o pipefail; \
  apt-get update -qq || apt-get update -qq apt-get update -qq; \
  apt-get install -y -qq binutils gcc || apt-get install -y -qq binutils gcc || apt-get install -y -qq binutils gcc; \
  gcc -shared  -ldl -fPIC -o wrapper.so wrapper.c; \
  mkdir -p /opt/mssql-memorypolicy-muter/; \
  cp -v wrapper.so /opt/mssql-memorypolicy-muter/; \
  chmod +x /opt/mssql-memorypolicy-muter/*.sh;


FROM ${SQL_BASE_IMAGE}
USER root
COPY --from=build /opt/mssql-memorypolicy-muter/ /opt/mssql-memorypolicy-muter/
CMD /opt/mssql-memorypolicy-muter/start-mssql.sh
