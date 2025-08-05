# BookLore Add-on (image-only)

This add-on wraps the upstream BookLore container and integrates it into Home Assistant via Ingress.

- Project: https://github.com/booklore-app/BookLore
- Image: `ghcr.io/adityachandelgit/booklore-app:latest`
- Ingress: **Open Web UI** from the add-on page (port 6060 internal)

## Requirements
- Home Assistant OS
- MariaDB server:
  - Recommended: **MariaDB add-on** on the same HA host
  - Or any external MariaDB/MySQL instance you can reach

## Configure the database
Edit the environment values in `config.yaml` **before installing** (or fork your repo and adjust):