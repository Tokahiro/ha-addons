#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

log(){ echo "[booklore-addon] $*"; }

# Try to load Bashio (nice-to-have)
if [ -f /usr/lib/bashio/bashio ]; then
  # shellcheck disable=SC1091
  source /usr/lib/bashio/bashio
  HAS_BASHIO=1
else
  HAS_BASHIO=0
fi

# Read an option from /data/options.json via bashio or jq
get_opt() {
  local key="$1" def="${2:-}"
  if [ "$HAS_BASHIO" -eq 1 ]; then
    bashio::config "$key" || echo -n "$def"
  else
    jq -r --arg def "$def" ".${key} // \$def" /data/options.json
  fi
}

# -------- Resolve DB settings (Services API or manual options) --------
USE_SVC="$(get_opt 'use_mysql_service' 'true')"
DB_NAME="$(get_opt 'db_name' 'booklore')"
SWAGGER_ENABLED="$(get_opt 'swagger_enabled' 'false')"

if [ "$USE_SVC" = "true" ]; then
  if [ "$HAS_BASHIO" -eq 1 ] && bashio::services.available "mysql"; then
    DB_HOST="$(bashio::services 'mysql' 'host')"
    DB_PORT="$(bashio::services 'mysql' 'port')"
    DB_USER="$(bashio::services 'mysql' 'username')"
    DB_PASS="$(bashio::services 'mysql' 'password')"
    log "Using MariaDB (service discovery) at ${DB_HOST}:${DB_PORT}"
  elif [ -n "${SUPERVISOR_TOKEN:-}" ] && curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql >/dev/null; then
    JSON="$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql)"
    DB_HOST="$(echo "$JSON" | jq -r '.data.host // .data.mysql.host')"
    DB_PORT="$(echo "$JSON" | jq -r '.data.port // .data.mysql.port')"
    DB_USER="$(echo "$JSON" | jq -r '.data.username // .data.mysql.username')"
    DB_PASS="$(echo "$JSON" | jq -r '.data.password // .data.mysql.password')"
    log "Using MariaDB (service discovery) at ${DB_HOST}:${DB_PORT}"
  fi
fi

if [ -z "${DB_HOST:-}" ]; then
  DB_HOST="$(get_opt 'db_host' 'core-mariadb')"
  DB_PORT="$(get_opt 'db_port' '3306')"
  DB_USER="$(get_opt 'db_user' 'booklore')"
  DB_PASS="$(get_opt 'db_password' 'CHANGE_ME')"
  log "Using manual DB configuration at ${DB_HOST}:${DB_PORT}"
fi

# Export env vars that BookLore expects (as per upstream Docker usage)
export DATABASE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}"
export DATABASE_USERNAME="${DB_USER}"
export DATABASE_PASSWORD="${DB_PASS}"
export SWAGGER_ENABLED="${SWAGGER_ENABLED}"

# -------- Try to delegate to upstream entrypoint if present --------
for ep in \
  "/entrypoint.sh" \
  "/docker-entrypoint.sh" \
  "/usr/local/bin/docker-entrypoint.sh" \
  "/opt/booklore/entrypoint.sh" \
  "/start.sh"
do
  if [ -x "$ep" ]; then
    log "Delegating to upstream entrypoint: $ep"
    exec "$ep" "$@"
  fi
  if [ -f "$ep" ]; then
    log "Delegating to upstream entrypoint (non-exec): $ep via bash"
    exec bash "$ep" "$@"
  fi
done

# -------- Fallback: start Nginx (if available) and the Java backend --------
if command -v nginx >/dev/null 2>&1; then
  # Start Nginx in the background (frontend/proxy to backend)
  log "Starting nginx (background)"
  nginx -g "daemon off;" & disown || true
fi

# Find a plausible BookLore jar anywhere on the filesystem
log "Searching for BookLore jar..."
CANDS="$(find / -type f \( -iname '*booklore*.jar' -o -iname '*booklore-api*.jar' \) 2>/dev/null || true)"
if [ -n "$CANDS" ]; then
  # Prefer names containing -api-, else pick the largest jar
  JAR="$(echo "$CANDS" | grep -i -- '-api.*\.jar' | head -n1 || true)"
  if [ -z "$JAR" ]; then
    JAR="$(while read -r p; do [ -f "$p" ] && echo "$(stat -c '%s' "$p"):$p"; done <<<"$CANDS" | sort -nr | head -n1 | cut -d: -f2-)"
  fi
fi

if [ -n "${JAR:-}" ] && [ -f "$JAR" ]; then
  log "Starting BookLore jar: $JAR"
  exec java -XX:+UseG1GC -jar "$JAR"
fi

log "Fatal: Unable to locate BookLore entrypoint or jar."
log "Candidates were:"
echo "${CANDS:-<none>}" | sed 's/^/[booklore-addon]   /'
sleep infinity