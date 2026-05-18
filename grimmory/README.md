# Grimmory - Home Assistant Add-on

> 📚 **Version 3.1.0** - Your personal digital library

![Version](https://img.shields.io/badge/version-3.1.0-blue.svg)
![Arch](https://img.shields.io/badge/arch-aarch64%20%7C%20amd64%20%7C%20armv7-green.svg)
![Status](https://img.shields.io/badge/status-stable-green.svg)

## What is Grimmory?

Transform your Home Assistant into a powerful book server! Grimmory organizes your digital books and comics with beautiful covers, metadata, and a built-in reader.

Grimmory is the active community fork of the discontinued [Booklore](https://github.com/booklore-app/booklore) project, continuing development and adding new features.

## ✨ Features

- 📚 **Smart Library** - Automatically organizes books with covers and info
- 💾 **External Storage** - Works with USB drives, external disks, NAS
- 🔧 **Raspberry Pi Ready** - Optimized for RPi4 + Argon EON
- 📱 **Mobile Access** - Read on any device with OPDS support
- 👥 **Multi-User** - Personal accounts and reading progress
- 🔒 **Secure** - Uses Home Assistant authentication

## 🚀 Quick Start

1. **Install** Grimmory from the Home Assistant add-on store
2. **Start** the add-on (default settings work great!)
3. **Access** Grimmory from your Home Assistant sidebar
4. **Add books** to `/media` folder or connect external storage

## 📖 Documentation

Need help with setup or external storage? Check the **Documentation** tab in the add-on for detailed instructions.

## 🔄 Migrating from Booklore

Since Grimmory is a new add-on (different slug), Home Assistant treats it as a fresh install. Your existing Booklore MariaDB database is forward-compatible — Grimmory will auto-migrate it on first start.

To migrate:
1. Back up your Booklore MariaDB database first
2. Install the Grimmory add-on
3. In the Grimmory configuration, set `db_name` and `db_user` to match your existing Booklore values (e.g., `db_name: "booklore"`)
4. Start Grimmory — it will detect and migrate the existing schema automatically

## 🙏 Credits

Built on the [Grimmory project](https://github.com/grimmory-tools/grimmory) — the community fork of the original Booklore application.

## 🆘 Support

- **Add-on issues**: [GitHub Issues](https://github.com/Tokahiro/ha-addons/issues)
- **App features**: [Grimmory repo](https://github.com/grimmory-tools/grimmory)
