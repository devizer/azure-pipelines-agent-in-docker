ARG BUILDER_IMAGE
ARG SQL_BASE_IMAGE

FROM ${BUILDER_IMAGE} AS build
SHELL ["/bin/bash", "-c"]
WORKDIR /root
COPY wrapper.c /root/
COPY start-mssql.sh /opt/mssql-memorypolicy-muter/
COPY sqlcmd.sh /opt/mssql-memorypolicy-muter/

RUN \
  set -eu; set -o pipefail; \
  apt-get update -qq || apt-get update -qq apt-get update -qq; \
  apt-get install -y -qq binutils gcc || apt-get install -y -qq binutils gcc || apt-get install -y -qq binutils gcc; \
  gcc -shared -ldl -fPIC -o wrapper.so wrapper.c; \
  mkdir -p /opt/mssql-memorypolicy-muter/; \
  cp -v wrapper.so /opt/mssql-memorypolicy-muter/; \
  chmod +x /opt/mssql-memorypolicy-muter/*.sh;


FROM ${SQL_BASE_IMAGE}
USER root
COPY --from=build /opt/mssql-memorypolicy-muter/ /opt/mssql-memorypolicy-muter/
# It works
RUN cp -f /opt/mssql-memorypolicy-muter/sqlcmd.sh /usr/local/bin/sqlcmd;

# It is not tested
# RUN \
#  exe="$(ls -1 /opt/mssql-tools*/bin/sqlcmd 2>/dev/null | head -1)"
#  if [[ -n "$exe" ]] && [[ -x "$exe" ]]; then ln -s -f "$exe" /usr/local/bin/sqlcmd; fi
#

CMD /opt/mssql-memorypolicy-muter/start-mssql.sh

