# shellcheck shell=bash

# grimmory::paths::ensure_dir DIR [DIR …]  → mkdir -p for each
grimmory::paths::ensure_dir() {
  local path
  for path in "$@"; do
    mkdir -p "$path"
    grimmory::log::info "Ensured directory: $path"
  done
}

# grimmory::paths::link TARGET LINK  → idempotent symlink; removes non-symlink at LINK
grimmory::paths::link() {
  local target="$1" link="$2"
  if [[ -e "$link" && ! -L "$link" ]]; then
    grimmory::log::warn "Removing non-symlink at $link"
    rm -rf "$link"
  fi
  ln -sfn "$target" "$link"
  grimmory::log::info "Linked $link -> $target"
}
