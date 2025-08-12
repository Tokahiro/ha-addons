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
    local base_mount="/share/booklore"
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
        log "DEBUG: Checking if device '$device' exists as block device..."
        if [ ! -b "$device" ]; then
            log "ERROR: The specified device '$device' does not exist or is not a block device. Skipping."
            continue
        fi
        log "DEBUG: Device '$device' exists and is a valid block device."
        
        # Create unique mount point
        mount_point="${base_mount}/${mount_name}"
        log "DEBUG: Creating mount point '$mount_point'..."
        mkdir -p "$mount_point"
        log "DEBUG: Mount point '$mount_point' created successfully."

        # Enhanced mount state detection and cleanup
        log "DEBUG: Performing comprehensive mount state check..."
        
        # Check if device is already mounted anywhere (multiple methods)
        log "DEBUG: Checking if device '$device' is already mounted..."
        existing_mount=""
        
        # Method 1: Check /proc/mounts
        if [ -f /proc/mounts ]; then
            existing_mount=$(grep "^$device " /proc/mounts | awk '{print $2}' | head -n1 2>/dev/null || echo "")
        fi
        
        # Method 2: Use findmnt if available
        if [ -z "$existing_mount" ] && command -v findmnt >/dev/null 2>&1; then
            existing_mount=$(timeout 5 findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n1 || echo "")
        fi
        
        # Method 3: Fallback to mount command
        if [ -z "$existing_mount" ]; then
            existing_mount=$(timeout 10 sh -c "mount | grep '^$device ' | awk '{print \$3}' | head -n1" 2>/dev/null || echo "")
        fi
        
        log "DEBUG: Existing mount check completed. Result: '${existing_mount:-none}'"
        
        if [ -n "$existing_mount" ]; then
            log "WARNING: Device '$device' is already mounted at '$existing_mount'."
            if [ "$existing_mount" = "$mount_point" ]; then
                log "INFO: Device is already mounted at our target location. Checking if accessible..."
                if [ -d "$mount_point" ] && [ -r "$mount_point" ]; then
                    log "SUCCESS: Device '$device' is already properly mounted at '$mount_point'."
                    MOUNTED_PATHS+=("$mount_point")
                    continue
                else
                    log "WARNING: Mount exists but is not accessible. Attempting to remount..."
                fi
            fi
            
            log "INFO: Attempting to unmount '$device' from '$existing_mount'..."
            if umount "$device" 2>/dev/null; then
                log "DEBUG: Successfully unmounted '$device'."
            else
                log "WARNING: Could not unmount '$device'. Trying lazy unmount..."
                if umount -l "$device" 2>/dev/null; then
                    log "DEBUG: Lazy unmount successful."
                    sleep 2  # Give time for lazy unmount to complete
                else
                    log "ERROR: Could not unmount '$device' from '$existing_mount'. Skipping."
                    continue
                fi
            fi
        fi

        # Check and clean up mount point
        log "DEBUG: Checking mount point '$mount_point' state..."
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log "WARNING: Mount point '$mount_point' is still in use. Attempting cleanup..."
            if umount "$mount_point" 2>/dev/null; then
                log "DEBUG: Successfully unmounted mount point."
            else
                log "WARNING: Trying lazy unmount on mount point..."
                umount -l "$mount_point" 2>/dev/null || true
                sleep 2
            fi
        fi
        
        # Final check - ensure mount point is clean
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log "ERROR: Mount point '$mount_point' is still busy after cleanup attempts. Skipping."
            continue
        fi
        
        log "DEBUG: Mount point check and cleanup completed."

        # Detect filesystem type and set appropriate mount options
        log "DEBUG: Starting filesystem type detection for '$device'..."
        log "Detecting filesystem type for '$device'..."
        fstype=$(lsblk "$device" -no fstype 2>/dev/null || echo "unknown")
        log "DEBUG: lsblk command completed."
        log "Detected filesystem type: $fstype"
        
        # Get supported filesystems
        log "DEBUG: Getting supported filesystems..."
        fstypessupport=$(grep -v nodev /proc/filesystems 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//' || echo "ext2 ext3 ext4 vfat ntfs")
        log "DEBUG: Supported filesystems retrieved."
        
        # Set filesystem-specific options
        log "DEBUG: Setting filesystem-specific mount options for '$fstype'..."
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
        
        # Attempt to mount the device with timeout
        log "DEBUG: About to attempt mount operation..."
        log "DEBUG: Mount command will be: timeout 10 mount -t '$mount_type' -o '$mount_options' '$device' '$mount_point'"
        log "Mounting '$device' to '$mount_point' with type '$mount_type' and options '$mount_options'..."
        
        # Quick device accessibility test only
        log "DEBUG: Quick device accessibility test..."
        if timeout 2 blkid "$device" >/dev/null 2>&1; then
            log "DEBUG: Device '$device' is accessible."
        else
            log "WARNING: Device '$device' may not be accessible. Proceeding anyway..."
        fi
        
        log "DEBUG: Using background mount process with forceful termination..."
        
        # Function to attempt mount in background
        attempt_mount_with_kill() {
            local mount_cmd="$1"
            local timeout_sec="$2"
            local attempt_name="$3"
            
            log "DEBUG: $attempt_name - Starting background mount with ${timeout_sec}s limit..."
            
            # Start mount in background and capture its PID
            eval "$mount_cmd" >/tmp/mount_output_$$ 2>&1 &
            local mount_pid=$!
            
            # Wait for mount to complete or timeout
            local elapsed=0
            while [ $elapsed -lt $timeout_sec ]; do
                if ! kill -0 $mount_pid 2>/dev/null; then
                    # Process finished
                    wait $mount_pid
                    local exit_code=$?
                    local output=$(cat /tmp/mount_output_$$ 2>/dev/null)
                    rm -f /tmp/mount_output_$$
                    
                    if [ $exit_code -eq 0 ]; then
                        log "SUCCESS: $attempt_name completed successfully!"
                        return 0
                    else
                        log "DEBUG: $attempt_name failed with exit code $exit_code"
                        [ -n "$output" ] && log "DEBUG: Output: $output"
                        return $exit_code
                    fi
                fi
                sleep 0.5
                elapsed=$((elapsed + 1))
            done
            
            # Timeout reached - forcefully kill the mount process
            log "WARNING: $attempt_name timed out after ${timeout_sec} seconds. Killing process..."
            kill -9 $mount_pid 2>/dev/null
            
            # Also try to kill any child processes
            pkill -9 -P $mount_pid 2>/dev/null
            
            # Clean up
            rm -f /tmp/mount_output_$$
            
            # Wait a moment for process to die
            sleep 0.5
            
            return 124  # timeout exit code
        }
        
        mount_success=false
        
        # Raspberry Pi 4 + Argon EON NAS specific handling
        # The Argon EON uses a JMicron JMS561U SATA-to-USB3 bridge which has compatibility issues
        local is_rpi4=false
        local is_argon_eon=false
        
        if [ -f /proc/cpuinfo ] && grep -q "Raspberry Pi 4" /proc/cpuinfo 2>/dev/null; then
            is_rpi4=true
            log "INFO: Running on Raspberry Pi 4."
            
            # Check for Argon EON by looking for JMicron bridge or specific USB IDs
            if lsusb 2>/dev/null | grep -qE "(JMicron|152d:0561|152d:1561)"; then
                is_argon_eon=true
                log "INFO: Argon EON NAS detected - applying specific workarounds."
            fi
        fi
        
        # Check if this device is known to be problematic
        local is_problematic=false
        
        # Argon EON + ext4 is a known problematic combination
        if [ "$is_argon_eon" = true ] && [ "$fstype" = "ext4" ]; then
            log "WARNING: Argon EON with ext4 filesystem detected."
            log "INFO: This combination has known issues with Home Assistant OS."
            is_problematic=true
        elif [ "$is_rpi4" = true ] && [ "$fstype" = "ext4" ]; then
            # Check device size if possible
            local device_size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null || echo "0")
            if [ "$device_size" -gt 1000000000000 ]; then  # > 1TB
                log "WARNING: Large ext4 drive detected on Raspberry Pi 4."
                is_problematic=true
            fi
        fi
        
        # Specific device check
        if [ "$device" = "/dev/sdc1" ] && [ "$fstype" = "ext4" ]; then
            is_problematic=true
        fi
        
        if [ "$is_problematic" = true ]; then
            if [ "$is_argon_eon" = true ]; then
                log "WARNING: Argon EON NAS with ext4 requires special handling."
                log "INFO: Attempting Argon EON specific workarounds..."
            else
                log "WARNING: This device configuration may cause issues on your hardware."
                log "INFO: Attempting Raspberry Pi 4 specific workarounds..."
            fi
            
            # Argon EON specific workarounds
            if [ "$is_argon_eon" = true ]; then
                # The JMicron bridge in Argon EON doesn't handle certain mount options well
                # Use very basic mount options and ultra-short timeout
                
                # Workaround 1: Absolute minimal mount
                log "DEBUG: Attempting minimal mount for Argon EON (0.5s timeout)..."
                if attempt_mount_with_kill "mount -o defaults '$device' '$mount_point'" 0.5 "Argon EON minimal"; then
                    mount_success=true
                    log "SUCCESS: Minimal mount succeeded on Argon EON!"
                else
                    # Workaround 2: Try with nobarrier option which helps with SATA bridges
                    log "DEBUG: Attempting mount with nobarrier option..."
                    if attempt_mount_with_kill "mount -o nobarrier,noatime '$device' '$mount_point'" 0.5 "Argon EON nobarrier"; then
                        mount_success=true
                        log "SUCCESS: Mount succeeded with nobarrier option!"
                    else
                        # Workaround 3: Read-only mount first
                        log "DEBUG: Attempting read-only mount for Argon EON..."
                        if attempt_mount_with_kill "mount -o ro '$device' '$mount_point'" 0.5 "Argon EON read-only"; then
                            mount_success=true
                            log "WARNING: Mounted read-only. The Argon EON bridge may need firmware update."
                        fi
                    fi
                fi
            else
                # Standard RPi4 workarounds (non-Argon EON)
                log "DEBUG: Attempting mount with sync option to avoid USB buffer issues..."
                if attempt_mount_with_kill "mount -o sync,noatime '$device' '$mount_point'" 1 "Sync mount"; then
                    mount_success=true
                    log "SUCCESS: Sync mount succeeded (may be slower but stable)!"
                else
                    # Try with minimal caching
                    log "DEBUG: Attempting mount with minimal caching..."
                    if attempt_mount_with_kill "mount -o ro,noatime,nodiratime,nobarrier '$device' '$mount_point'" 1 "Minimal cache mount"; then
                        if mount -o remount,rw,sync "$mount_point" 2>/dev/null; then
                            mount_success=true
                            log "SUCCESS: Mount succeeded with RPi4 workarounds!"
                        else
                            mount_success=true
                            log "WARNING: Mounted read-only due to RPi4 USB limitations."
                        fi
                    fi
                fi
            fi
            
            # Workaround 3: Try FUSE-based mount as last resort
            if [ "$mount_success" = false ] && [ "$fstype" = "ext4" ]; then
                log "DEBUG: Attempting FUSE-based mount (if available)..."
                if command -v fuseext2 >/dev/null 2>&1; then
                    if attempt_mount_with_kill "fuseext2 -o ro '$device' '$mount_point'" 1 "FUSE mount"; then
                        mount_success=true
                        log "WARNING: Using FUSE mount (slower but works around kernel issues)."
                    fi
                fi
            fi
            
            if [ "$mount_success" = false ]; then
                if [ "$is_argon_eon" = true ]; then
                    log "ERROR: Unable to mount $device on Argon EON NAS."
                    log "INFO: This is a known issue with the Argon EON's JMicron SATA bridge."
                    log "TIP: Try these solutions:"
                    log "  1. Update Argon EON firmware if available"
                    log "  2. Add 'usb-storage.quirks=152d:0561:u' to /boot/cmdline.txt"
                    log "  3. Use a different filesystem (btrfs or xfs may work better)"
                    log "  4. Mount the drive manually after boot with: mount -o nobarrier /dev/sdc1 /mnt"
                    log "  5. Consider using the drive for data storage only, not for addon data"
                else
                    log "ERROR: Unable to mount $device on Raspberry Pi 4."
                    log "INFO: This is a known issue with RPi4 USB3 ports and large drives."
                    log "TIP: Try these solutions:"
                    log "  1. Connect the drive to a USB2 port instead of USB3"
                    log "  2. Use a powered USB hub"
                    log "  3. Add 'usb-storage.quirks=XXXX:YYYY:u' to /boot/cmdline.txt"
                    log "  4. Format the drive with a different filesystem (exFAT/NTFS)"
                fi
                log "CRITICAL: Skipping this device to prevent system hang."
                rmdir "$mount_point" 2>/dev/null || true
                continue
            fi
        else
            # Normal mount attempts for other devices
            
            # On RPi4, use shorter timeouts due to USB instability
            local timeout1=3
            local timeout2=2
            if [ "$is_rpi4" = true ]; then
                timeout1=2
                timeout2=1
                log "DEBUG: Using reduced timeouts for Raspberry Pi 4."
            fi
            
            # Attempt 1: Simple mount
            if attempt_mount_with_kill "mount '$device' '$mount_point'" $timeout1 "Simple mount"; then
                mount_success=true
            elif [ $? -eq 124 ]; then
                # Attempt 2: Read-only mount
                if attempt_mount_with_kill "mount -o ro '$device' '$mount_point'" $timeout2 "Read-only mount"; then
                    # Try to remount as read-write
                    if mount -o remount,rw "$mount_point" 2>/dev/null; then
                        mount_success=true
                        log "SUCCESS: Remounted as read-write!"
                    else
                        mount_success=true
                        log "WARNING: Mounted as read-only."
                    fi
                elif [ $? -eq 124 ]; then
                    # Attempt 3: Explicit filesystem type
                    if [ -n "$fstype" ] && [ "$fstype" != "unknown" ]; then
                        if attempt_mount_with_kill "mount -t '$fstype' '$device' '$mount_point'" $timeout2 "Mount with $fstype"; then
                            mount_success=true
                        elif [ $? -eq 124 ]; then
                            log "ERROR: All mount attempts timed out."
                            log "CRITICAL: Device '$device' appears to cause hanging. Skipping."
                            rmdir "$mount_point" 2>/dev/null || true
                            continue
                        fi
                    fi
                fi
            fi
        fi
        
        # No additional error handling needed - all handled in attempt_mount_with_kill
        
        if [ "$mount_success" = true ]; then
            log "DEBUG: Mount operation completed successfully."
            log "Successfully mounted '$device' to '$mount_point'."
            MOUNTED_PATHS+=("$mount_point")
        else
            log "ERROR: Failed to mount '$device' to '$mount_point' after all attempts."
            log "Filesystem type was: $fstype"
            log "Mount options used: $mount_options"
            
            # CRITICAL FALLBACK: Don't let mount failures block addon startup
            log "FALLBACK: Mount failed but addon will continue with default storage."
            log "FALLBACK: You can manually mount the device later if needed."
            log "FALLBACK: Device '$device' will be skipped for now."
            
            # Clean up the created directory if mount fails
            rmdir "$mount_point" 2>/dev/null || true
        fi
    done < <(echo "$mounts_json" | jq -r '.[]')

    # Report summary
    if [ ${#MOUNTED_PATHS[@]} -gt 0 ]; then
        log "Mounting summary: Successfully mounted ${#MOUNTED_PATHS[@]} device(s)."
        export BOOKLORE_LIBRARY_PATHS="${MOUNTED_PATHS[*]}"
    else
        log "WARNING: No external devices were successfully mounted."
    fi
}

# Cleanup function for graceful shutdown
cleanup_mounts() {
    if [ ${#MOUNTED_PATHS[@]} -eq 0 ]; then
        return
    fi

    log "Unmounting ${#MOUNTED_PATHS[@]} device(s)..."
    for mount_point in "${MOUNTED_PATHS[@]}"; do
        if mountpoint -q "$mount_point"; then
            log "Unmounting '$mount_point'..."
            if umount "$mount_point"; then
                rmdir "$mount_point" 2>/dev/null || true
            else
                log "WARNING: Failed to unmount '$mount_point' on shutdown."
            fi
        fi
    done
}

# Set up trap for cleanup on exit
trap cleanup_mounts EXIT

# Call the mount function directly - it has its own timeouts for each mount operation
log "Starting external disk mounting..."
mount_external_disks
log "External disk mounting process completed."

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
