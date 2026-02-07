# syntax=docker/dockerfile:1
#
# BETA MASS image: base image + server installed from source at startup
#
FROM ghcr.io/music-assistant/base:1.4.8

ENV VIRTUAL_ENV=/app/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# ensure UV is installed
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# add some additional packages needed for building from source
RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends jq git curl ca-certificates libportaudio2 libasound2-plugins dbus \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && uv venv $VIRTUAL_ENV \
  && uv pip install \
  --no-cache \
  --link-mode=copy \
  -r "https://raw.githubusercontent.com/music-assistant/server/refs/heads/dev/requirements_all.txt"

VOLUME [ "/data" ]
EXPOSE 8095

RUN chmod 777 -R /app && \
  chmod 777 -R /tmp

COPY entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
