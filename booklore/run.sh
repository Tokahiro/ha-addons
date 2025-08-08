#!/usr/bin/env bashio
# shellcheck shell=bash
set -euo pipefail

log(){ echo "[booklore-addon] $*"; }

# Optional: Bashio for options & Services API helpers
echo ls -al /usr/lib/bashio/
echo ls -al /usr/lib/bashio/bashio
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

# ---- External Disk Mounting ----
# ---- External Disk Mounting ----
mount_external_disk() {
  local enabled label device mount_point fs_type mount_opts
  
  # Read external disk configuration
  enabled=$(bashio::config 'external_disk.enabled' 'false')
  
  if [ "$enabled" != "true" ]; then
    bashio::log.info "External disk mounting is disabled"
    return 0
  fi
  
  label=$(bashio::config 'external_disk.label' '')
  device=$(bashio::config 'external_disk.device' '')
  mount_point=$(bashio::config 'external_disk.mount_point' '/mnt/external_library')
  fs_type=$(bashio::config 'external_disk.filesystem' 'auto')
  mount_opts=$(bashio::config 'external_disk.mount_options' 'rw,noatime')
  
  # Determine device path (Label has priority)
  if [ -n "$label" ]; then
    bashio::log.info "Attempting to find device by label: $label"
    device_path_from_label=$(blkid -L "$label" 2>/dev/null)
    
    if [ -n "$device_path_from_label" ]; then
      device="$device_path_from_label"
      bashio::log.info "Found device $device for label $label"
    else
      bashio::log.fatal "Could not find a device with the label: $label"
      bashio::log.info "Available block devices and labels:"
      blkid -o list
      return 1
    fi
  elif [ -z "$device" ]; then
    bashio::log.fatal "External disk enabled, but no device or label was specified."
    bashio::log.info "Please configure either a 'device' path or a 'label' in the addon settings."
    return 1
  fi

  # Validate device path format
  if ! echo "$device" | grep -qE '^/dev/(sd[a-g][0-9]?|nvme[0-9]n[0-9](p[0-9])?)$'; then
    bashio::log.fatal "Invalid device path format: $device"
    bashio::log.fatal "Device must be in format /dev/sdXY or /dev/nvmeXnYpZ"
    return 1
  fi
  
  # Check if device exists
  if [ ! -b "$device" ]; then
    bashio::log.fatal "Device $device does not exist or is not a block device"
    bashio::log.info "Available block devices on this system:"
    ls -1 /dev/sd[a-g]* /dev/nvme*n*p* 2>/dev/null | grep -E '(sd[a-g][0-9]?|nvme[0-9]n[0-9]p[0-9])$' || true
    return 1
  fi
  
  # Create mount point if it doesn't exist
  if [ ! -d "$mount_point" ]; then
    bashio::log.info "Creating mount point: $mount_point"
    mkdir -p "$mount_point"
  fi
  
  # Check if already mounted
  if mountpoint -q "$mount_point" 2>/dev/null; then
    bashio::log.warning "Mount point $mount_point is already in use, attempting to unmount..."
    umount "$mount_point" 2>/dev/null || {
      bashio::log.warning "Could not unmount existing mount at $mount_point"
      return 1
    }
  fi
  
  # Detect filesystem if auto is specified
  if [ "$fs_type" = "auto" ]; then
    detected_fs=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "")
    if [ -n "$detected_fs" ]; then
      bashio::log.info "Detected filesystem: $detected_fs"
      fs_type="$detected_fs"
    else
      bashio::log.info "Could not detect filesystem, will let mount auto-detect"
    fi
  fi
  
  # Attempt to mount the device
  bashio::log.info "Mounting $device to $mount_point (filesystem: $fs_type, options: $mount_opts)"
  
  # Build mount command
  mount_cmd="mount"
  [ "$fs_type" != "auto" ] && mount_cmd="$mount_cmd -t $fs_type"
  mount_cmd="$mount_cmd -o $mount_opts $device $mount_point"
  
  if $mount_cmd 2>&1 | tee /tmp/mount.log; then
    bashio::log.info "Successfully mounted $device to $mount_point"
    
    # Set appropriate permissions for the BookLore application
    chown -R 1000:1000 "$mount_point" 2>/dev/null || {
      bashio::log.warning "Could not change ownership of $mount_point"
    }
    
    # Create library subdirectories if they don't exist
    for dir in books comics uploads metadata thumbnails; do
      if [ ! -d "$mount_point/$dir" ]; then
        mkdir -p "$mount_point/$dir"
        chown 1000:1000 "$mount_point/$dir"
      fi
    done
    
    # Export environment variable for BookLore to use this path
    export EXTERNAL_LIBRARY_PATH="$mount_point"
    export BOOKLORE_LIBRARY_PATH="$mount_point/books"
    export BOOKLORE_COMICS_PATH="$mount_point/comics"
    
    # Log mount details
    df -h "$mount_point" | tail -1
    
    return 0
  else
    bashio::log.fatal "Failed to mount $device to $mount_point"
    bashio::log.fatal "Mount error details:"
    cat /tmp/mount.log
    return 1
  fi
}

# Cleanup function for graceful shutdown
cleanup_mounts() {
  local mount_point
  mount_point=$(bashio::config 'external_disk.mount_point' '/mnt/external_library')
  if mountpoint -q "$mount_point" 2>/dev/null; then
    bashio::log.info "Unmounting external disk at $mount_point"
    umount "$mount_point" 2>/dev/null || bashio::log.warning "Could not unmount $mount_point"
  fi
}

# Set up trap for cleanup on exit
trap cleanup_mounts EXIT

# Call the mount function with error handling
if ! mount_external_disk; then
  bashio::log.warning "External disk mounting failed, continuing with default storage"
  # The addon will continue using the default /media or /share mappings
fi

USE_SVC="$(get_opt 'use_mysql_service' 'true')"
DB_NAME="$(get_opt 'db_name' 'booklore')"
SWAGGER_ENABLED="$(get_opt 'swagger_enabled' 'false')"

# ---- MariaDB auto-discovery or manual fallback ----
if [ "$USE_SVC" = "true" ]; then
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
export SWAGGER_ENABLED="${SWAGGER_ENABLED}"

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