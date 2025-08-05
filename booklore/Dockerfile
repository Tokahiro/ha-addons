ARG BOOKLORE_TAG=latest
FROM ghcr.io/adityachandelgit/booklore-app:${BOOKLORE_TAG}

# Small tools for config/discovery (bash, curl, jq)
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then apk add --no-cache bash curl jq; \
    elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y --no-install-recommends bash curl jq && rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf >/dev/null 2>&1; then microdnf install -y bash curl jq && microdnf clean all; \
    else echo "Skipping package install"; fi

# Optional but handy for Services API helpers
ARG BASHIO_VERSION=0.16.2
RUN curl -fsSL https://github.com/hassio-addons/bashio/archive/refs/tags/v${BASHIO_VERSION}.tar.gz \
  | tar xz -C /tmp && mv /tmp/bashio-${BASHIO_VERSION} /usr/lib/bashio || true

COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]