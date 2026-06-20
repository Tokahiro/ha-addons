# Grimmory Add-on Documentation

> 📚 **Version 3.2.2** - Your personal digital library in Home Assistant

## 🚀 Quick Start

1. **Install** the Grimmory add-on from the Home Assistant store
2. **Start** the add-on (it works with default settings!)
3. **Open** Grimmory from your Home Assistant sidebar
4. **Add books** to your `/media` folder and enjoy!

## ⚙️ Configuration

### Basic Setup
Most users don't need to change anything - Grimmory works great out of the box!

```yaml
# Default configuration (works for most users)
db_name: "grimmory"
mounts: []
```

### External Storage
Want to use a USB drive or external disk? Just add it to your config:

```yaml
mounts:
  - "MyBooks"        # Use the drive's label
  - "/dev/sdc1"      # Or use the device path
```

**What works:**
- 💾 USB drives, external hard drives, SSDs
- 🔧 Raspberry Pi 4 with Argon EON NAS
- 📁 Any filesystem: ext4, NTFS, exFAT, FAT32
- 📍 Your drives appear in `/mnt/` (e.g., `/mnt/MyBooks`)

### Database
Grimmory automatically finds and uses the MariaDB add-on for best performance.

**Want to use a different database server?**
```yaml
db_host: "your-database-server"
db_user: "your-username"
db_password: "your-password"
```

## 📱 Mobile Access

Use any OPDS-compatible app (like Moon+ Reader) to access your library:

1. Open Grimmory in your browser
2. Find your OPDS URL in the settings
3. Add it to your mobile reading app
4. Use your Home Assistant login

## 🔄 Migrating from Booklore

Grimmory is forward-compatible with existing Booklore MariaDB databases. To migrate:

1. **Back up** your Booklore database (recommended)
2. **Install** the Grimmory add-on
3. **Configure** `db_name` and `db_user` to match your existing Booklore values:
   ```yaml
   db_name: "booklore"
   db_user: "booklore"
   ```
4. **Start** Grimmory — it auto-migrates the schema on first boot

## ⚠️ Migration Notes (v3.1.0)

The following options and environment variables were removed in this release:

- **`mount` (singular)** — use the `mounts` list instead:
  ```yaml
  # Old (no longer works)
  mount: "MyDrive"

  # New
  mounts:
    - "MyDrive"
  ```
- **`BOOKLORE_PORT` / `BOOKLORE_LIBRARY_PATHS`** — these internal environment variable aliases have been removed. If you have custom scripts or integrations that read them, switch to `GRIMMORY_PORT` and `GRIMMORY_LIBRARY_PATHS`.

## 🔧 Troubleshooting

### Common Issues

**Add-on won't start?**
- Check the logs for error messages
- Make sure you have enough disk space
- Try the default configuration first

**External drive won't mount?**
- Check if the drive appears in `lsblk` command
- For Raspberry Pi 4: Add `usb-storage.quirks=152d:0561:u` to `/boot/cmdline.txt`
- Try a different USB port or powered USB hub

**Slow performance?**
- Install the MariaDB add-on for better database performance
- Use faster storage (SSD instead of old hard drive)

### Getting Help

Need more help? [Open an issue on GitHub](https://github.com/Tokahiro/ha-addons/issues) and include:
- Your add-on configuration (remove passwords!)
- The add-on logs
- Your Home Assistant version

---

*That's it! Grimmory is designed to be simple and just work. Enjoy your digital library! 📚*
