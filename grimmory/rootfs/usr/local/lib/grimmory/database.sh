# shellcheck shell=bash

# Populated by grimmory::db::resolve; consumed by run.sh for DATABASE_URL export.
export DB_HOST=""
export DB_PORT=""
export DB_USER=""
export DB_PASS=""

# Attempt to discover MariaDB credentials via the HA Supervisor services API.
grimmory::db::from_services() {
  [[ -z "${SUPERVISOR_TOKEN:-}" ]] && return 1
  local json
  json=$(curl -fsS \
    -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/services/mysql 2>/dev/null) || return 1
  DB_HOST=$(printf '%s' "$json" | jq -r '.data.host // .data.mysql.host // empty')
  DB_PORT=$(printf '%s' "$json" | jq -r '.data.port // .data.mysql.port // empty')
  DB_USER=$(printf '%s' "$json" | jq -r '.data.username // .data.mysql.username // empty')
  DB_PASS=$(printf '%s' "$json" | jq -r '.data.password // .data.mysql.password // empty')
  [[ -n "$DB_HOST" ]]
}

# Fall back to manually-configured options.
grimmory::db::from_options() {
  DB_HOST=$(grimmory::opt::get 'db_host' 'core-mariadb')
  DB_PORT=$(grimmory::opt::get 'db_port' '3306')
  DB_USER=$(grimmory::opt::get 'db_user' 'grimmory')
  DB_PASS=$(grimmory::opt::get 'db_password' '')
}

# Resolve DB credentials: Supervisor API first, manual config as fallback.
grimmory::db::resolve() {
  if grimmory::db::from_services; then
    grimmory::log::info "MariaDB via Supervisor API at ${DB_HOST}:${DB_PORT}"
  else
    grimmory::db::from_options
    grimmory::log::info "MariaDB via manual config at ${DB_HOST}:${DB_PORT}"
  fi
}
