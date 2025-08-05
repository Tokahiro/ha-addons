# syntax=docker/dockerfile:1.6

# We reuse the upstream BookLore container (no source build).
ARG BOOKLORE_TAG=latest
FROM ghcr.io/adityachandelgit/booklore-app:${BOOKLORE_TAG}

# Install minimal tools needed by the wrapper (bash, curl, jq, tar).
# Try common package managers; ignore failures if some don't exist.
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash curl jq tar; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends bash curl jq ca-certificates tar && rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf >/dev/null 2>&1; then \
      microdnf install -y bash curl jq tar && microdnf clean all; \
    else \
      echo "No known package manager found; assuming bash/curl/jq exist in base image."; \
    fi

# Add Bashio helper library (optional but robust for Services API & options parsing)
ARG BASHIO_VERSION=0.16.2
RUN curl -fsSL https://github.com/hassio-addons/bashio/archive/refs/tags/v${BASHIO_VERSION}.tar.gz \
  | tar xz -C /tmp && mv /tmp/bashio-${BASHIO_VERSION} /usr/lib/bashio || true

# Our startup wrapper: reads add-on options & Services API, then starts BookLore
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Keep the upstream port; Ingress will proxy to it.
EXPOSE 6060

# Make our script PID 1; it will exec the upstream app.
ENTRYPOINT ["/run.sh"]