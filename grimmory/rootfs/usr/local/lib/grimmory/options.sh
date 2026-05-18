# shellcheck shell=bash

readonly _GRIMMORY_OPTIONS_FILE=/data/options.json

# grimmory::opt::get KEY [DEFAULT]  → scalar string value
grimmory::opt::get() {
  local key="$1" default="${2:-}"
  jq -r --arg d "$default" ".${key} // \$d" "$_GRIMMORY_OPTIONS_FILE" 2>/dev/null \
    || echo -n "$default"
}

# grimmory::opt::get_json KEY [DEFAULT_JSON]  → raw JSON value (array, object, …)
grimmory::opt::get_json() {
  local key="$1" default="${2:-[]}"
  jq -c --argjson d "$default" ".${key} // \$d" "$_GRIMMORY_OPTIONS_FILE" 2>/dev/null \
    || echo -n "$default"
}

# grimmory::opt::has KEY  → returns 0 if key is present and non-empty
grimmory::opt::has() {
  local key="$1"
  jq -e ".${key} != null and .${key} != \"\"" "$_GRIMMORY_OPTIONS_FILE" >/dev/null 2>&1
}
