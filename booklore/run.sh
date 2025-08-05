#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

# Try to load Bashio if available (optional)
if [ -f /usr/lib/bashio/bashio ]; then
  # shellcheck disable=SC1091
  source /usr/lib/bashio/bashio
  HAS_BASHIO=1
else
  HAS_BASHIO=0
fi

log() { echo "[booklore-addon] $*"; }

# Read options from /data/options.json using bashio (if present) or jq
get_opt() {
  local key="$1" default="${2:-}"
  if [ "$HAS_BASHIO" -eq 1 ]; then
    bashio::config "$key" || echo -n "$default"
  else
    jq -r --arg def "$default" ".${key} // \$def" /data/options.json
  fi
}

USE_SVC="$(get_opt 'use_mysql_service' 'true')"
DB_NAME="$(get_opt 'db_name' 'booklore')"
SWAGGER_ENABLED="$(get_opt 'swagger_enabled' 'false')"

if [ "$USE_SVC" = "true" ]; then
  # Prefer Services API (MariaDB add-on)
  if [ "$HAS_BASHIO" -eq 1 ] && bashio::services.available "mysql"; then
    DB_HOST="$(bashio::services 'mysql' 'host')"
    DB_PORT="$(bashio::services 'mysql' 'port')"
    DB_USER="$(bashio::services 'mysql' 'username')"
    DB_PASS="$(bashio::services 'mysql' 'password')"
    log "Using MariaDB service discovery at ${DB_HOST}:${DB_PORT}"
  else
    # Fallback to raw Supervisor Services API if bashio is unavailable
    if curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql >/dev/null; then
      JSON="$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql)"
      DB_HOST="$(echo "$JSON" | jq -r '.data.host // .data.mysql.host')"
      DB_PORT="$(echo "$JSON" | jq -r '.data.port // .data.mysql.port')"
      DB_USER="$(echo "$JSON" | jq -r '.data.username // .data.mysql.username')"
      DB_PASS="$(echo "$JSON" | jq -r '.data.password // .data.mysql.password')"
      log "Using MariaDB service discovery at ${DB_HOST}:${DB_PORT}"
    else
      log "Services API not available; falling back to manual DB config."
      USE_SVC="false"
    fi
  fi
fi

if [ "$USE_SVC" != "true" ]; then
  DB_HOST="$(get_opt 'db_host' 'core-mariadb')"
  DB_PORT="$(get_opt 'db_port' '3306')"
  DB_USER="$(get_opt 'db_user' 'booklore')"
  DB_PASS="$(get_opt 'db_password' 'CHANGE_ME')"
  log "Using manual DB configuration at ${DB_HOST}:${DB_PORT}"
fi

# Export BookLore's expected env vars (as per upstream Docker instructions)
export DATABASE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}"
export DATABASE_USERNAME="${DB_USER}"
export DATABASE_PASSWORD="${DB_PASS}"
export SWAGGER_ENABLED="${SWAGGER_ENABLED}"

# Try to locate the BookLore jar if the upstream entrypoint is not preserved.
# Common locations (keep search shallow to avoid overhead).
JAR_CANDIDATE=""
for p in \
  "/app/booklore.jar" \
  "/opt/booklore/booklore.jar" \
  "/usr/local/lib/booklore.jar" \
  "/usr/share/booklore/booklore.jar"
do
  if [ -f "$p" ]; then JAR_CANDIDATE="$p"; break; fi
done

if [ -z "$JAR_CANDIDATE" ]; then
  # Best-effort search
  JAR_CANDIDATE="$(find / -maxdepth 4 -type f -name 'booklore*.jar' 2>/dev/null | head -n1 || true)"
fi

if [ -n "$JAR_CANDIDATE" ]; then
  log "Starting BookLore (jar: ${JAR_CANDIDATE}) on port 6060"
  exec java -XX:+UseG1GC -jar "${JAR_CANDIDATE}"
fi

# If jar not found, try to exec the original CMD (if any) passed to this entrypoint.
if [ "$#" -gt 0 ]; then
  log "Jar not found; exec original command: $*"
  exec "$@"
fi

log "Error: Unable to locate BookLore jar or original command. Container will sleep."
sleep infinity