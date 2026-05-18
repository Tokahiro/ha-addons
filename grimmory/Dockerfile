ARG GRIMMORY_REF=v3.1.0
FROM ghcr.io/grimmory-tools/grimmory:${GRIMMORY_REF}

# Mount utilities, nginx (reverse proxy), and jq (options parsing)
RUN apk add --no-cache \
    bash curl jq nginx \
    util-linux e2fsprogs ntfs-3g exfat-utils

# Replace Alpine's default nginx server with the Grimmory ingress proxy config
RUN rm -f /etc/nginx/http.d/default.conf
COPY nginx/grimmory.conf /etc/nginx/http.d/default.conf

# Install helper library and entrypoint
COPY rootfs/ /
COPY run.sh /run.sh
RUN chmod +x /run.sh \
    && chmod +x /usr/local/lib/grimmory/*.sh

ENTRYPOINT ["/run.sh"]
