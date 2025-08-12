#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

log(){ echo "[booklore-addon] $*"; }

# Optional: Bashio for options & Services API helpers
if [ -f /usr/lib/bashio/bashio ]; then
  # shellcheck disable=SC1091
  source /usr/lib/bashio/bashio
  HAS_BASHIO=1
else
  HAS_BASHIO=0
fi


# ---- Read options from UI ----
get_opt() {
  local key="$1" def="${2:-}"
  if [ "$HAS_BASHIO" -eq 1 ]; then
    bashio::config "$key" || echo -n "$def"
  else
    jq -r --arg def "$def" ".${key} // \$def" /data/options.json
  fi
}

# ---- External Disk Mounting V3 (Multi-Mount) ----

# Global array to track successfully mounted paths
declare -a MOUNTED_PATHS=()

mount_external_disks() {
    local mounts_json mount_value device mount_point mount_name
    local base_mount="/mnt"  # Use /mnt like alexbelgium addons, not /share
    local mount_opts="rw,noatime"
    local global_start_time=$(date +%s)
    local global_timeout=120  # 2 minutes global timeout

    # Check for legacy single mount option for backward compatibility
    if [ "$HAS_BASHIO" -eq 1 ]; then
        if ! bashio::config.has_value 'mounts'; then
            legacy_mount=$(bashio::config 'mount' '')
            if [ -n "$legacy_mount" ]; then
                bashio::log.warning "Using legacy 'mount' option. Please migrate to the 'mounts' list."
                mounts_json="[\"$legacy_mount\"]"
            else
                mounts_json="[]"
            fi
        else
            mounts_json=$(bashio::config 'mounts')
        fi
    else
        # Fallback to jq when bashio is not available
        if jq -e '.mounts' /data/options.json >/dev/null 2>&1; then
            mounts_json=$(jq -r '.mounts' /data/options.json)
        elif jq -e '.mount' /data/options.json >/dev/null 2>&1; then
            legacy_mount=$(jq -r '.mount // ""' /data/options.json)
            if [ -n "$legacy_mount" ]; then
                log "Using legacy 'mount' option. Please migrate to the 'mounts' list."
                mounts_json="[\"$legacy_mount\"]"
            else
                mounts_json="[]"
            fi
        else
            mounts_json="[]"
        fi
    fi

    # If mounts list is empty, do nothing.
    if [ -z "$mounts_json" ] || [ "$mounts_json" = "[]" ]; then
        log "No external mounts specified. Using default storage."
        return 0
    fi

    log "Processing external mounts..."
    
    # Show available devices for debugging
    log "Available block devices:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null || log "lsblk command failed"
    
    # Show supported filesystems
    fstypessupport=$(grep -v nodev < /proc/filesystems | awk '{$1=" "$1}1' | tr -d '\n\t')
    log "Supported filesystems: $fstypessupport"

    # Create base directory if it doesn't exist
    mkdir -p "$base_mount"

    # Parse JSON array and iterate through each entry
    while IFS= read -r mount_value; do
        # Skip empty values that might result from jq parsing
        [ -z "$mount_value" ] && continue
        
        # Check global timeout
        local current_time=$(date +%s)
        local elapsed=$((current_time - global_start_time))
        if [ $elapsed -ge $global_timeout ]; then
            log "WARNING: Global timeout reached after ${elapsed} seconds. Stopping mount attempts."
            log "WARNING: Addon will continue with mounts completed so far."
            break
        fi

        log "--- Processing mount: $mount_value ---"

        # Intelligent detection: Is it a device path or a label?
        if [[ "$mount_value" == /dev/* ]]; then
            device="$mount_value"
            mount_name=$(echo "$mount_value" | sed 's|^/dev/||; s|/|-|g')
        else
            device=$(blkid -L "$mount_value" 2>/dev/null)
            if [ -z "$device" ]; then
                log "ERROR: A device with the label '$mount_value' could not be found. Skipping."
                continue
            fi
            log "Found device '$device' for label '$mount_value'."
            mount_name=$(echo "$mount_value" | sed 's/[^a-zA-Z0-9_-]/_/g')
        fi

        # Check if device exists
        if [ ! -b "$device" ]; then
            log "ERROR: The specified device '$device' does not exist or is not a block device. Skipping."
            continue
        fi
        
        # Create unique mount point
        mount_point="${base_mount}/${mount_name}"
        
        # Check if device is already mounted somewhere
        existing_mount=$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n1 || echo "")
        
        if [ -n "$existing_mount" ]; then
            log "INFO: Device '$device' is already mounted at '$existing_mount'."
            # Create a symlink to the existing mount if it's not at our expected location
            if [ "$existing_mount" != "$mount_point" ]; then
                log "INFO: Creating symlink from '$mount_point' to existing mount at '$existing_mount'."
                mkdir -p "$(dirname "$mount_point")"
                ln -sfn "$existing_mount" "$mount_point"
                MOUNTED_PATHS+=("$mount_point")
            else
                MOUNTED_PATHS+=("$mount_point")
            fi
            continue
        fi
        
        # Create mount point if it doesn't exist
        mkdir -p "$mount_point"

        # Detect filesystem type and set appropriate mount options
        log "Detecting filesystem type for '$device'..."
        fstype=$(lsblk "$device" -no fstype 2>/dev/null || echo "unknown")
        log "Detected filesystem type: $fstype"
        
        # Get supported filesystems
        fstypessupport=$(grep -v nodev /proc/filesystems 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//' || echo "ext2 ext3 ext4 vfat ntfs")
        
        # Set filesystem-specific options
        mount_options="nosuid,relatime,noexec"
        mount_type="auto"
        
        case "$fstype" in
            exfat | vfat | msdos)
                log "WARNING: $fstype permissions and ACL don't work - using experimental support"
                mount_options="${mount_options},umask=000"
                ;;
            ntfs)
                log "WARNING: $fstype is experimental support"
                mount_options="${mount_options},umask=000"
                mount_type="ntfs"
                ;;
            squashfs)
                log "WARNING: $fstype is experimental support"
                mount_options="loop"
                mount_type="squashfs"
                ;;
            ext2 | ext3 | ext4 | xfs | btrfs)
                # Standard Linux filesystems - use default options with rw
                mount_options="rw,noatime"
                ;;
            *)
                if [[ "${fstypessupport}" != *"${fstype}"* ]] && [ "$fstype" != "unknown" ]; then
                    log "ERROR: Filesystem type '$fstype' for device '$device' is not supported by this system."
                    log "Supported filesystems: $fstypessupport"
                    rmdir "$mount_point" 2>/dev/null || true
                    continue
                fi
                # Use default options for unknown or other supported filesystems
                mount_options="rw,noatime"
                ;;
        esac
        
        # Attempt to mount the device - using exact approach from alexbelgium addons
        log "Mounting '$device' to '$mount_point'..."
        
        mount_success=false
        
        # Mount the device
        
        # Try mount with filesystem type first
        if mount -t "$mount_type" "$device" "$mount_point" -o "$mount_options" 2>/dev/null; then
            mount_success=true
            log "Successfully mounted '$device' to '$mount_point'."
        else
            # If first attempt fails, try without type specification (auto-detect)
            if mount "$device" "$mount_point" -o "$mount_options" 2>/dev/null; then
                mount_success=true
                log "Successfully mounted '$device' to '$mount_point' (auto-detected type)."
            else
                log "WARNING: Failed to mount '$device'. Continuing without this mount."
            fi
        fi
        
        if [ "$mount_success" = true ]; then
            MOUNTED_PATHS+=("$mount_point")
        else
            # Clean up the created directory if mount fails
            rmdir "$mount_point" 2>/dev/null || true
        fi
    done < <(echo "$mounts_json" | jq -r '.[]')

    # Report summary
    if [ ${#MOUNTED_PATHS[@]} -gt 0 ]; then
        log "Successfully mounted ${#MOUNTED_PATHS[@]} device(s) at: ${MOUNTED_PATHS[*]}"
        export BOOKLORE_LIBRARY_PATHS="${MOUNTED_PATHS[*]}"
    else
        log "No external devices were mounted."
    fi
}

# Cleanup function for graceful shutdown
cleanup_mounts() {
    if [ ${#MOUNTED_PATHS[@]} -eq 0 ]; then
        return
    fi

    for mount_point in "${MOUNTED_PATHS[@]}"; do
        if mountpoint -q "$mount_point"; then
            if umount "$mount_point"; then
                rmdir "$mount_point" 2>/dev/null || true
            fi
        fi
    done
}

# Set up trap for cleanup on exit
trap cleanup_mounts EXIT

# Mount external disks
mount_external_disks

DB_NAME="$(get_opt 'db_name' 'booklore')"

# ---- MariaDB auto-discovery or manual fallback ----
# Always try service discovery first (since we have mysql:need in config)
if [ "$HAS_BASHIO" -eq 1 ] && bashio::services.available "mysql"; then
  DB_HOST="$(bashio::services 'mysql' 'host')"
  DB_PORT="$(bashio::services 'mysql' 'port')"
  DB_USER="$(bashio::services 'mysql' 'username')"
  DB_PASS="$(bashio::services 'mysql' 'password')"
  log "Using MariaDB service discovery at ${DB_HOST}:${DB_PORT}"
elif [ -n "${SUPERVISOR_TOKEN:-}" ] && curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql >/dev/null; then
  JSON="$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mysql)"
  DB_HOST="$(echo "$JSON" | jq -r '.data.host // .data.mysql.host')"
  DB_PORT="$(echo "$JSON" | jq -r '.data.port // .data.mysql.port')"
  DB_USER="$(echo "$JSON" | jq -r '.data.username // .data.mysql.username')"
  DB_PASS="$(echo "$JSON" | jq -r '.data.password // .data.mysql.password')"
  log "Using MariaDB (raw Services API) at ${DB_HOST}:${DB_PORT}"
fi

if [ -z "${DB_HOST:-}" ]; then
  DB_HOST="$(get_opt 'db_host' 'core-mariadb')"
  DB_PORT="$(get_opt 'db_port' '3306')"
  DB_USER="$(get_opt 'db_user' 'booklore')"
  DB_PASS="$(get_opt 'db_password' 'CHANGE_ME')"
  log "Using manual DB configuration at ${DB_HOST}:${DB_PORT}"
fi

# ---- Export upstream env vars ----
export DATABASE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}"
export DATABASE_USERNAME="${DB_USER}"
export DATABASE_PASSWORD="${DB_PASS}"

# ---- Start backend on 8080 (as upstream expects behind NGINX) ----
if [ ! -f /app/app.jar ]; then
  log "Error: /app/app.jar not found. Listing /app:"
  ls -alh /app || true
  sleep infinity
fi

log "Starting backend on 8080: /app/app.jar"
java -XX:+UseG1GC -Dserver.port=8080 -jar /app/app.jar >/proc/1/fd/1 2>/proc/1/fd/2 &

# Optional: Wait briefly for backend health (best-effort)
for i in $(seq 1 40); do
  if curl -fsS http://127.0.0.1:8080/actuator/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

# ---- Start NGINX on 6060 (Ingress & direct access) ----
if command -v nginx >/dev/null 2>&1; then
  log "Starting NGINX on 6060 (foreground)"
  exec nginx -g "daemon off;"
else
  log "NGINX not found in image. Falling back to backend only on 8080."
  log "You can expose 8080 temporarily for debugging if needed."
  sleep infinity
fi
