#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

log(){ echo "[booklore-addon] $*"; }

# --- Optional: Bashio for Services API/Config helpers ---
if [ -f /usr/lib/bashio/bashio ]; then
  # shellcheck disable=SC1091
  source /usr/lib/bashio/bashio
  HAS_BASHIO=1
else
  HAS_BASHIO=0
fi

# --- Read options (UI) ---
opt() {
  local key="$1" def="${2:-}"
  if [ "$HAS_BASHIO" -eq 1 ]; then
    bashio::config "$key" || echo -n "$def"
  else
    jq -r --arg def "$def" ".${key} // \$def" /data/options.json
  fi
}

USE_SVC="$(opt 'use_mysql_service' 'true')"
DB_NAME="$(opt 'db_name' 'booklore')"
SWAGGER_ENABLED="$(opt 'swagger_enabled' 'false')"

# --- Services API (MariaDB) or manual fallback ---
if [ "$USE_SVC" = "true" ]; then
  if [ "$HAS_BASHIO" -eq 1 ] && bashio::services.available "mysql"; then
    DB_HOST="$(bashio::services 'mysql' 'host')"
    DB_PORT="$(bashio::services 'mysql' 'port')"
    DB_USER="$(bashio::services 'mysql' 'username')"
    DB_PASS="$(bashio::services 'mysql' 'password')"
    log "Using MariaDB via Services API at ${DB_HOST}:${DB_PORT}"
  elif [ -n "${SUPERVISOR_TOKEN:-}" ] && curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql >/dev/null; then
    JSON="$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql)"
    DB_HOST="$(echo "$JSON" | jq -r '.data.host // .data.mysql.host')"
    DB_PORT="$(echo "$JSON" | jq -r '.data.port // .data.mysql.port')"
    DB_USER="$(echo "$JSON" | jq -r '.data.username // .data.mysql.username')"
    DB_PASS="$(echo "$JSON" | jq -r '.data.password // .data.mysql.password')"
    log "Using MariaDB via raw Services API at ${DB_HOST}:${DB_PORT}"
  fi
fi

if [ -z "${DB_HOST:-}" ]; then
  DB_HOST="$(opt 'db_host' 'core-mariadb')"
  DB_PORT="$(opt 'db_port' '3306')"
  DB_USER="$(opt 'db_user' 'booklore')"
  DB_PASS="$(opt 'db_password' 'CHANGE_ME')"
  log "Using manual DB configuration at ${DB_HOST}:${DB_PORT}"
fi

# --- Export BookLore env (as upstream Docker docs expect) ---
export DATABASE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}"
export DATABASE_USERNAME="${DB_USER}"
export DATABASE_PASSWORD="${DB_PASS}"
export SWAGGER_ENABLED="${SWAGGER_ENABLED}"

log "DB url: ${DATABASE_URL}"
log "DB user: ${DATABASE_USERNAME}"

# --- 1) Prefer delegating to an upstream entrypoint if present ---
# Common locations/names patterns
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
done

# NGINX official images run /docker-entrypoint.sh and process /docker-entrypoint.d/*
if [ -x "/docker-entrypoint.sh" ] && [ -d "/docker-entrypoint.d" ]; then
  cat >/docker-entrypoint.d/10-booklore-env.sh <<'EOF'
#!/bin/sh
# Export DB env for BookLore before nginx starts
export DATABASE_URL="${DATABASE_URL}"
export DATABASE_USERNAME="${DATABASE_USERNAME}"
export DATABASE_PASSWORD="${DATABASE_PASSWORD}"
export SWAGGER_ENABLED="${SWAGGER_ENABLED}"
EOF
  chmod +x /docker-entrypoint.d/10-booklore-env.sh
  log "Found nginx-style entrypoint. Injected /docker-entrypoint.d/10-booklore-env.sh"
  exec /docker-entrypoint.sh "$@"
fi

# --- 2) s6-overlay style images ---
if [ -x "/init" ]; then
  log "Found s6-overlay /init; handing off"
  exec /init
fi

# --- 3) supervisord style images ---
if [ -f "/etc/supervisord.conf" ] || [ -f "/etc/supervisor/supervisord.conf" ]; then
  if command -v supervisord >/dev/null 2>&1; then
    log "Found supervisord; starting it"
    exec supervisord -n -c /etc/supervisord.conf 2>/dev/null || exec supervisord -n -c /etc/supervisor/supervisord.conf
  fi
fi

# --- 4) Last resort: try to start the backend JAR directly ---
log "Attempting to locate BookLore JAR as last resort..."
CANDS=""
# Avoid depending on 'find' being installed; use POSIX shell globs
for d in /app /opt /usr/local /usr/share /; do
  for j in "$d"/**/*booklore*.jar "$d"/**/*booklore-api*.jar "$d"/*booklore*.jar "$d"/*booklore-api*.jar; do
    [ -f "$j" ] && CANDS="${CANDS}${j}"$'\n'
  done
done

if [ -n "$CANDS" ]; then
  JAR="$(printf "%s" "$CANDS" | head -n1)"
  log "Starting JAR: $JAR"
  exec java -XX:+UseG1GC -jar "$JAR"
fi

# --- If we reached here, we couldn't find anything executable ---
log "Fatal: Unable to locate an upstream entrypoint, s6/init, supervisord, or a BookLore JAR."
log "Filesystem snapshot (top-level):"; ls -alh /
log "Likely places:"; for p in /app /opt /usr/local /usr/share; do echo "== $p =="; ls -alh "$p" 2>/dev/null || true; done
sleep infinity