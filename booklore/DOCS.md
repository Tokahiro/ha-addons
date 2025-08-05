# BookLore (Home Assistant add-on)

This add-on reuses the upstream BookLore container and integrates it into Home Assistant via **Ingress**.  
It reads configuration from the **Configuration tab** (no need to edit `config.yaml`) and can **auto-discover** the MariaDB add-on.

- Upstream image: `ghcr.io/adityachandelgit/booklore-app:latest`
- Web UI (Ingress): Use **Open Web UI** on the add-on page (port 6060 internal)
- Database: MariaDB/MySQL (auto-discovered or manual via options)

## Options (configure in the UI)
- `use_mysql_service` (default `true`) – use Supervisor Services API to pick up credentials from the MariaDB add-on
- `db_host`, `db_port`, `db_name`, `db_user`, `db_password` – used when auto-discovery is disabled or not available
- `swagger_enabled` – pass-through to BookLore

## First run
1. Ensure the **MariaDB add-on** is installed and running (recommended), or provide external DB details.
2. Create the database/user if needed (example):
   ```sql
   CREATE DATABASE booklore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'booklore'@'%' IDENTIFIED BY 'CHANGE_ME';
   GRANT ALL PRIVILEGES ON booklore.* TO 'booklore'@'%';
   FLUSH PRIVILEGES;