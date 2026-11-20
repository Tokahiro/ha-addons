FROM ghcr.io/riddix/home-assistant-matter-hub-addon:2.0.60

COPY patch.mjs /patch.mjs
RUN set -e \
 && cli="$(readlink -f /usr/local/bin/home-assistant-matter-hub)" \
 && node /patch.mjs "$cli" \
 && node --check "$cli" \
 && grep -q '^exec home-assistant-matter-hub start' /docker-entrypoint.sh \
 && sed -i "s|^exec home-assistant-matter-hub start|export HAMH_AREA_TYPES=\"\$(bashio::config 'area_types' '')\"\nexec home-assistant-matter-hub start|" /docker-entrypoint.sh \
 && grep -q 'HAMH_AREA_TYPES' /docker-entrypoint.sh
