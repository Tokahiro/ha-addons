# BookLore Home Assistant Add-on Documentation

> 📚 **Version 0.19.0** - Full documentation for the BookLore add-on.

## 🚀 Installation & Quick Start

1.  **Add the Repository**: If you haven't already, add the repository to your Home Assistant add-on store.
2.  **Install BookLore**: Find the "BookLore" add-on and click **Install**.
3.  **Basic Configuration**: For most users, the default settings are sufficient. The add-on will automatically detect the MariaDB add-on if it is available.
    ```yaml
    use_mysql_service: true
    db_name: "booklore"
    ```
4.  **Start the Add-on**: Click **Start** to launch BookLore.
5.  **Access the Web UI**: Open BookLore from the Home Assistant sidebar.
6.  **Add Books**: Place your book files (EPUB, PDF, CBZ, etc.) into the `/media` directory in your Home Assistant configuration. BookLore will automatically find and import them.

## ⚙️ Configuration

### External Access

To access BookLore directly from your browser (outside of the HA sidebar), you need to map a port in the add-on's "Network" configuration section.

```yaml
# In Home Assistant Add-on Configuration -> Network
# Set the host port you want to use.
ports:
  "8099/tcp": 6060 # The internal port is always 6060
```

You can then access BookLore at `http://homeassistant.local:8099`.

### Database

-   **Auto-Detection (Recommended)**: By default (`use_mysql_service: true`), the add-on will try to use the official Home Assistant MariaDB add-on. This provides the best performance.
-   **Manual Configuration**: If you use a different database, you can specify the connection details manually.
    ```yaml
    use_mysql_service: false
    db_host: "your_database_host"
    db_port: 3306
    db_user: "your_user"
    db_password: "your_password"
    db_name: "booklore"
    ```
-   **Built-in (SQLite)**: If no database is configured, a local SQLite database will be used. This is suitable for smaller collections.

### Storage

#### Default Storage (`/media`)

The easiest method is to place your books in the `/media` folder, which is readily accessible via Samba, the File Editor, or other means.

#### Network Storage (SMB/CIFS or NFS)

You can mount network shares to host your library. This is ideal for large collections stored on a NAS.

1.  Enable a storage type in your configuration (`enable_network_storage: true`).
2.  Define your mounts.

**Example SMB/CIFS Mount:**
```yaml
enable_network_storage: true
network_mounts:
  - name: "nas_books"
    server: "192.168.1.100"
    share: "books"
    username: "user"
    password: "password"
    type: "cifs"
    # For older NAS devices, you may need to specify the SMB version
    # options: "vers=2.1" 
```

#### Local Storage (USB Drives / Disks)

You can mount locally attached storage devices like USB drives.

**Example Local Mount:**
```yaml
enable_local_mounts: true
local_mounts:
  - name: "external_drive"
    device: "/dev/sda1"
```

The add-on will attempt to automatically determine the filesystem type.

### Performance Tuning

For very large libraries (>5,000 books), you can improve performance by adjusting the memory and enabling caching.

```yaml
memory_limit: "1g"    # Increase available memory
enable_caching: true
cache_size: "512m"    # Allocate memory for caching
```

For a full list of configuration options and examples, please refer to the [`config.examples.yaml`](config.examples.yaml) file.

## 📱 Mobile Access with OPDS

You can access your library from mobile devices using an ODPS-compatible reader app (like Moon+ Reader for Android or KyBook for iOS).

1.  **Find your OPDS URL**: In the BookLore Web UI, go to the settings or about page to find your unique OPDS URL. It is tied to your Home Assistant ingress session.
2.  **Add to your App**: Add the URL to your mobile app as a new catalog.
3.  **Authenticate**: Use your Home Assistant username and password.

## 🔍 Troubleshooting Guide

### First Steps

1.  **Check the Logs**: The first place to look for errors is the add-on log. Go to `Settings -> Add-ons -> BookLore -> Log`.
2.  **Use Debug Logging**: To get more detailed logs, set the log level to debug in the configuration.
    ```yaml
    log_level: "DEBUG"
    ```
    Then, restart the add-on and check the logs again.
3.  **Try Minimal Configuration**: Revert to the most basic configuration to see if the issue is related to a specific setting.

### Common Issues & Solutions

| Issue | Solution |
| :--- | :--- |
| **Add-on won't start** | - Check the logs for `FATAL` errors. <br> - Ensure you have at least 1GB of free disk space. <br> - Try a minimal configuration. |
| **Configuration validation failed** | - A setting is incorrect. The debug log will tell you which one. <br> - Common errors include invalid memory format (use `512m` or `1g`, not `512MB`) or invalid cron expressions. |
| **Database connection failed** | - If using the MariaDB add-on, ensure it is started. <br> - Double-check your credentials if using a manual configuration. |
| **Network storage won't mount** | - Verify server address, share name, username, and password. <br> - Test connectivity from another device. <br> - For older NAS/SMB shares, try adding `options: "vers=2.1"` to the mount configuration. |
| **Slow performance** | - For large libraries, increase `memory_limit` and enable `caching`. <br> - Ensure you are using the MariaDB add-on, as it is significantly faster than SQLite. |

### Getting Help

If you continue to have problems, please [open an issue on GitHub](https://github.com/Tokahiro/ha-addons/issues). Include the following information:
- Your add-on configuration (remove any passwords!).
- The complete add-on log.
- Your Home Assistant version and installation type (OS, Supervised, etc.).