# trixie doesn't have python 2, so we copy it from bullseye
FROM debian:bullseye-slim AS python2
RUN apt-get update && \
  apt-get install -y python2.7 libpython2.7 libssl1.1 --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

FROM debian:trixie-slim
LABEL maintainer="zodern"

# libnsl2 needed for python 2
RUN apt-get update && \
  apt-get install -y curl python3 make g++ bzip2 ca-certificates libnsl2 --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

# Copy python 2 and make sure nothing is missing
COPY --from=python2 /usr/bin/python2.7 /usr/bin/python2.7
COPY --from=python2 /usr/lib/python2.7 /usr/lib/python2.7
COPY --from=python2 /usr/lib/*-linux-gnu/libpython2.7.so.1.0 /usr/local/lib/
COPY --from=python2 /usr/lib/*-linux-gnu/libssl.so.1.1 /usr/local/lib/
COPY --from=python2 /usr/lib/*-linux-gnu/libcrypto.so.1.1 /usr/local/lib/
COPY --from=python2 /usr/lib/*-linux-gnu/libffi.so.7.* /usr/local/lib/
RUN ldconfig && \
  set -e && \
  for module in /usr/lib/python2.7/lib-dynload/*.so; do \
    if ldd "$module" | grep -q 'not found'; then \
      echo "Missing dependency for $module"; \
      ldd "$module"; \
      exit 1; \
    fi; \
  done && \
  python2.7 -c 'import ssl, hashlib, ctypes, bz2, readline, sqlite3, zlib, nis' && \
  ln -s /usr/bin/python2.7 /usr/bin/python2 && \
  ln -s /usr/bin/python2.7 /usr/bin/python

RUN useradd --create-home --shell /bin/bash --uid 1000 --user-group app

RUN mkdir /built_app && \
  mkdir /bundle && \
  chown -R app:app /home/app/ && \
  chown -R app:app /built_app && \
  chown -R app:app /bundle && \
  chmod 700 /built_app && \
  chmod 700 /bundle

USER app
WORKDIR /home/app
RUN mkdir scripts && mkdir setup
COPY ./setup ./setup
RUN bash setup/install_nvm.sh

COPY ./scripts ./scripts

ONBUILD USER app
ONBUILD ARG NODE_VERSION='8.17.0'
ONBUILD ARG EXACT_NODE_VERSION=false
ONBUILD RUN bash ./scripts/onbuild-node.sh
ONBUILD ENV NODE_PATH=/home/app/.onbuild-node/lib/node_modules PATH=/home/app/.onbuild-node/bin:$PATH

USER root
RUN bash setup/setup_root_nvm.sh
EXPOSE 3000
ENTRYPOINT bash /home/app/scripts/entry.sh
