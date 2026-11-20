FROM ghcr.io/riddix/home-assistant-matter-hub-addon:2.0.60

COPY patch.mjs /patch.mjs
RUN set -e \
 && cli="$(readlink -f /usr/local/bin/home-assistant-matter-hub)" \
 && node /patch.mjs "$cli" \
 && node --check "$cli" \
 && grep -q '^exec home-assistant-matter-hub start' /docker-entrypoint.sh \
 && sed -i "s|^exec home-assistant-matter-hub start|export AREA_TYPE_OVERRIDES=\"\$(bashio::config 'area_types' '')\"\nexport VACUUM_ONLY=\"\$(bashio::config 'vacuum_only' 'false')\"\nexec home-assistant-matter-hub start|" /docker-entrypoint.sh \
 && grep -q 'AREA_TYPE_OVERRIDES' /docker-entrypoint.sh \
 && grep -q 'VACUUM_ONLY' /docker-entrypoint.sh
