#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

_LIB=/usr/local/lib/grimmory
# shellcheck source=/dev/null
. "${_LIB}/log.sh"
# shellcheck source=/dev/null
. "${_LIB}/options.sh"
# shellcheck source=/dev/null
. "${_LIB}/mounts.sh"
# shellcheck source=/dev/null
. "${_LIB}/paths.sh"
# shellcheck source=rootfs/usr/local/lib/grimmory/database.sh
. "${_LIB}/database.sh"

# Global PID for signal forwarding.
_GRIMMORY_APP_PID=""
_grimmory_stop() { kill -TERM "$_GRIMMORY_APP_PID" 2>/dev/null || true; }

main() {
  mkdir -p /var/run/grimmory

  # ---- External disk mounts ----
  local mounts_json
  mounts_json=$(grimmory::opt::get_json 'mounts' '[]')
  grimmory::mounts::process_all "$mounts_json"

  # ---- Persistent paths ----
  local books_dir bookdrop_dir data_dir
  books_dir=$(grimmory::opt::get    'books_dir'    '/media/grimmory/books')
  bookdrop_dir=$(grimmory::opt::get 'bookdrop_dir' '/share/grimmory/bookdrop')
  data_dir=$(grimmory::opt::get     'data_dir'     '/data/grimmory')

  grimmory::log::info "books_dir=${books_dir}"
  grimmory::log::info "bookdrop_dir=${bookdrop_dir}"
  grimmory::log::info "data_dir=${data_dir}"

  grimmory::paths::ensure_dir "$books_dir" "$bookdrop_dir" "$data_dir"
  grimmory::paths::link "$data_dir"    /app/data
  grimmory::paths::link "$books_dir"   /books
  grimmory::paths::link "$bookdrop_dir" /bookdrop

  # ---- Database ----
  local db_name
  db_name=$(grimmory::opt::get 'db_name' 'grimmory')
  DB_HOST="" DB_PORT="" DB_USER="" DB_PASS=""  # populated by grimmory::db::resolve
  grimmory::db::resolve

  export DATABASE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${db_name}"
  export DATABASE_USERNAME="${DB_USER}"
  export DATABASE_PASSWORD="${DB_PASS}"
  export GRIMMORY_PORT=6060

  local lib_paths
  lib_paths=$(grimmory::mounts::library_paths)
  [[ -n "$lib_paths" ]] && export GRIMMORY_LIBRARY_PATHS="$lib_paths"

  # ---- Start nginx reverse proxy ----
  grimmory::log::info "Starting nginx..."
  nginx

  # ---- Start Grimmory (upstream entrypoint handles user/group setup) ----
  grimmory::log::info "Starting Grimmory..."
  trap _grimmory_stop TERM INT
  /usr/local/bin/entrypoint.sh "$@" &
  _GRIMMORY_APP_PID=$!

  wait "$_GRIMMORY_APP_PID"
  local exit_code=$?

  nginx -s quit 2>/dev/null || true
  grimmory::mounts::cleanup_all

  return "$exit_code"
}

main "$@"
