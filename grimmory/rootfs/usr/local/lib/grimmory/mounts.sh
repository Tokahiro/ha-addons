# shellcheck shell=bash

readonly _GRIMMORY_MOUNT_STATE=/var/run/grimmory/mounted_paths
readonly _GRIMMORY_MOUNT_BASE=/mnt
readonly _GRIMMORY_MOUNT_TIMEOUT=120

# Append a successfully mounted path to the state file.
grimmory::mounts::record() {
  printf '%s\n' "$1" >> "$_GRIMMORY_MOUNT_STATE"
}

# Unmount every path recorded in the state file (reverse order).
grimmory::mounts::cleanup_all() {
  [[ ! -f "$_GRIMMORY_MOUNT_STATE" ]] && return 0
  local paths=() mp
  while IFS= read -r mp; do [[ -n "$mp" ]] && paths+=("$mp"); done < "$_GRIMMORY_MOUNT_STATE"
  local i
  for (( i=${#paths[@]}-1; i>=0; i-- )); do
    mp="${paths[$i]}"
    if mountpoint -q "$mp" 2>/dev/null; then
      umount "$mp" && rmdir "$mp" 2>/dev/null || true
    elif [[ -L "$mp" ]]; then
      rm -f "$mp"
    fi
  done
}

# Return space-separated list of all mounted paths (empty string if none).
grimmory::mounts::library_paths() {
  [[ ! -f "$_GRIMMORY_MOUNT_STATE" ]] && return 0
  tr '\n' ' ' < "$_GRIMMORY_MOUNT_STATE" | sed 's/ $//'
}

# Resolve a device path or label to an absolute /dev/… path.
grimmory::mounts::resolve_device() {
  local value="$1"
  if [[ "$value" == /dev/* ]]; then
    echo "$value"
  else
    blkid -L "$value" 2>/dev/null || true
  fi
}

# Return filesystem-specific mount options for a given fstype.
grimmory::mounts::mount_opts_for() {
  case "$1" in
    exfat|vfat|msdos) echo "nosuid,relatime,noexec,umask=000" ;;
    ntfs)             echo "nosuid,relatime,noexec,umask=000" ;;
    squashfs)         echo "loop" ;;
    ext2|ext3|ext4|xfs|btrfs) echo "rw,noatime" ;;
    *)                echo "rw,noatime" ;;
  esac
}

# Detect the filesystem type of a block device.
grimmory::mounts::detect_fs() {
  lsblk "$1" -no fstype 2>/dev/null || echo "unknown"
}

# Mount a single entry (device path or label).
grimmory::mounts::process_one() {
  local value="$1" device="" mount_name mount_point fstype mount_opts existing_mount

  if [[ "$value" == /dev/* ]]; then
    device="$value"
    mount_name=$(echo "$value" | sed 's|^/dev/||; s|/|-|g')
  else
    device=$(grimmory::mounts::resolve_device "$value")
    if [[ -z "$device" ]]; then
      grimmory::log::warn "No device found for label '$value', skipping."
      return 0
    fi
    mount_name=$(echo "$value" | sed 's/[^a-zA-Z0-9_-]/_/g')
    grimmory::log::info "Label '$value' resolved to '$device'."
  fi

  if [[ ! -b "$device" ]]; then
    grimmory::log::warn "'$device' is not a block device, skipping."
    return 0
  fi

  mount_point="${_GRIMMORY_MOUNT_BASE}/${mount_name}"

  existing_mount=$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n1 || true)
  if [[ -n "$existing_mount" ]]; then
    grimmory::log::info "'$device' already mounted at '$existing_mount'."
    if [[ "$existing_mount" != "$mount_point" ]]; then
      mkdir -p "$(dirname "$mount_point")"
      ln -sfn "$existing_mount" "$mount_point"
    fi
    grimmory::mounts::record "$mount_point"
    return 0
  fi

  mkdir -p "$mount_point"

  fstype=$(grimmory::mounts::detect_fs "$device")
  mount_opts=$(grimmory::mounts::mount_opts_for "$fstype")
  grimmory::log::info "Mounting '$device' ($fstype) at '$mount_point'..."

  local mount_type="auto"
  [[ "$fstype" == "ntfs" ]]     && mount_type="ntfs"
  [[ "$fstype" == "squashfs" ]] && mount_type="squashfs"

  if mount -t "$mount_type" "$device" "$mount_point" -o "$mount_opts" 2>/dev/null \
    || mount "$device" "$mount_point" -o "$mount_opts" 2>/dev/null; then
    grimmory::log::info "Mounted '$device' at '$mount_point'."
    grimmory::mounts::record "$mount_point"
  else
    grimmory::log::warn "Failed to mount '$device', skipping."
    rmdir "$mount_point" 2>/dev/null || true
  fi
}

# Process the full mounts JSON array from options.
grimmory::mounts::process_all() {
  local mounts_json="$1"
  if [[ -z "$mounts_json" || "$mounts_json" == "[]" ]]; then
    grimmory::log::info "No external mounts configured."
    return 0
  fi

  grimmory::log::info "Processing external mounts..."
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null || true
  mkdir -p "$_GRIMMORY_MOUNT_BASE"

  local start_time now elapsed value
  start_time=$(date +%s)

  while IFS= read -r value; do
    [[ -z "$value" ]] && continue
    now=$(date +%s)
    elapsed=$(( now - start_time ))
    if (( elapsed >= _GRIMMORY_MOUNT_TIMEOUT )); then
      grimmory::log::warn "Global mount timeout (${elapsed}s) reached. Stopping."
      break
    fi
    grimmory::log::info "--- Processing mount: $value ---"
    grimmory::mounts::process_one "$value"
  done < <(printf '%s' "$mounts_json" | jq -r '.[]')

  local lib_paths
  lib_paths=$(grimmory::mounts::library_paths)
  if [[ -n "$lib_paths" ]]; then
    grimmory::log::info "Mounted paths: $lib_paths"
  else
    grimmory::log::info "No external devices mounted."
  fi
}
