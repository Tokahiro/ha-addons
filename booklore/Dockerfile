ARG BOOKLORE_TAG=0.38.0
FROM ghcr.io/booklore-app/booklore:${BOOKLORE_TAG}

# Small tools + nginx + mount utilities
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash curl jq nginx \
        util-linux e2fsprogs ntfs-3g exfat-utils; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends \
        bash curl jq nginx mount util-linux e2fsprogs \
        ntfs-3g exfat-utils exfat-fuse && \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf >/dev/null 2>&1; then \
      microdnf install -y bash curl jq nginx \
        util-linux e2fsprogs ntfs-3g exfat-utils && \
        microdnf clean all; \
    else \
      echo "Assuming mount utilities present."; \
    fi

# Use our Nginx config for 6060 -> 8080 proxy with WS support
COPY nginx/booklore.conf /etc/nginx/conf.d/default.conf

# (Optional) Bashio for easier Services API usage
ARG BASHIO_VERSION=0.16.2
RUN curl -fsSL https://github.com/hassio-addons/bashio/archive/refs/tags/v${BASHIO_VERSION}.tar.gz \
  | tar xz -C /tmp && \
  if [ -d "/tmp/bashio-${BASHIO_VERSION}" ]; then \
    mv /tmp/bashio-${BASHIO_VERSION} /usr/lib/bashio && \
    echo "Bashio installed successfully"; \
  else \
    echo "Warning: Bashio installation failed, fallback mode will be used"; \
  fi

COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]