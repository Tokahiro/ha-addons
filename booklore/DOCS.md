# BookLore Add-on Documentation

> 📚 **Version 1.3.0** - Your personal digital library in Home Assistant

## 🚀 Quick Start

1. **Install** the BookLore add-on from the Home Assistant store
2. **Start** the add-on (it works with default settings!)
3. **Open** BookLore from your Home Assistant sidebar
4. **Add books** to your `/media` folder and enjoy!

## ⚙️ Configuration

### Basic Setup
Most users don't need to change anything - BookLore works great out of the box!

```yaml
# Default configuration (works for most users)
db_name: "booklore"
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
BookLore automatically finds and uses the MariaDB add-on for best performance. If you don't have it, BookLore uses a built-in database.

**Want to use a different database?**
```yaml
db_host: "your-database-server"
db_user: "your-username"
db_password: "your-password"
```

## 📱 Mobile Access

Use any OPDS-compatible app (like Moon+ Reader) to access your library:

1. Open BookLore in your browser
2. Find your OPDS URL in the settings
3. Add it to your mobile reading app
4. Use your Home Assistant login

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

*That's it! BookLore is designed to be simple and just work. Enjoy your digital library! 📚*