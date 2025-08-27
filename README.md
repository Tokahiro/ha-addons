<div align="center">

# 🏠 Tokahiro's Home Assistant Add-ons

*High-quality add-ons for your Home Assistant setup*

[![GitHub stars](https://img.shields.io/github/stars/Tokahiro/ha-addons?style=flat-square)](https://github.com/Tokahiro/ha-addons/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/Tokahiro/ha-addons?style=flat-square)](https://github.com/Tokahiro/ha-addons/issues)
[![GitHub license](https://img.shields.io/github/license/Tokahiro/ha-addons?style=flat-square)](https://github.com/Tokahiro/ha-addons/blob/main/LICENSE)

**Transform your Home Assistant with powerful, easy-to-use add-ons**

</div>

---

## 🚀 Quick Start

Ready to enhance your Home Assistant? Add this repository in one click:

<div align="center">

[![Add Repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FTokahiro%2Fha-addons)

*Click the button above for instant installation*

</div>

### Manual Installation
1. Go to **Settings** → **Add-ons** → **Add-on Store** in Home Assistant
2. Click **⋮** (three dots) → **Repositories**
3. Add: `https://github.com/Tokahiro/ha-addons`
4. Find your add-on and install!

---

## 📚 Available Add-ons

### 📖 BookLore
*Your personal digital library*

Transform your Home Assistant into a powerful book server with automatic organization, beautiful covers, and mobile access.

**✨ What makes it special:**
- 📚 **Smart Library** - Auto-organizes books with covers and metadata
- 💾 **Universal Storage** - USB drives, SATA, NVMe, SD cards
- 🔧 **Hardware Optimized** - Perfect for Raspberry Pi 4 + Argon EON
- 📱 **Mobile Ready** - OPDS support for any reading app
- 👥 **Multi-User** - Personal accounts and reading progress
- 🔒 **Secure** - Home Assistant authentication built-in

**Perfect for:** Book lovers, families, digital library enthusiasts, NAS users

---

## 🛠️ Installation & Setup

### Step 1: Add Repository
Use the one-click button above or manually add the repository URL.

### Step 2: Install Add-on
1. Find your desired add-on in the store
2. Click **Install** and wait for completion
3. Check the **Documentation** tab for setup instructions

### Step 3: Configure & Enjoy
1. Configure any required options (most work with defaults!)
2. Start the add-on
3. Access through Home Assistant sidebar

---

## 💡 Why Choose These Add-ons?

<div align="center">

| 🎯 **Quality First** | 🔒 **Security Focused** | 🚀 **Performance Optimized** |
|:---:|:---:|:---:|
| Thoroughly tested | Home Assistant native auth | Efficient resource usage |
| Regular updates | Secure ingress integration | Optimized Docker images |
| Community feedback | No unnecessary ports | Auto-scaling configs |

</div>

---

## 📋 Requirements

- **Home Assistant OS** or **Home Assistant Supervised**
- **Add-on support enabled** (standard in most installations)
- **Sufficient storage space** (varies by add-on)

Individual add-ons may have additional requirements - check their documentation.

---

## 💬 Community & Support

<div align="center">

| 🆘 **Need Help?** | 💡 **Got Ideas?** | 🐛 **Found a Bug?** |
|:---:|:---:|:---:|
| [GitHub Discussions](https://github.com/Tokahiro/ha-addons/discussions) | [Feature Requests](https://github.com/Tokahiro/ha-addons/issues/new?assignees=&labels=enhancement&template=feature_request.md) | [Bug Reports](https://github.com/Tokahiro/ha-addons/issues/new?assignees=&labels=bug&template=bug_report.md) |

</div>

**Note:** This is a hobby project maintained in spare time.

---

## 📄 License & Credits

Licensed under the **MIT License** - see individual add-on directories for details.

### Special Thanks
- 🏠 **Home Assistant Team** - For creating an amazing platform
- 🌟 **Original Project Authors** - Each add-on credits its upstream sources
- 👥 **Community Contributors** - For feedback, testing, and improvements

---

<div align="center">

**🌟 Enjoying these add-ons?**

[![Star this repository](https://img.shields.io/badge/⭐-Star%20this%20repo-yellow?style=for-the-badge)](https://github.com/Tokahiro/ha-addons/stargazers)

*Your support helps maintain and improve these add-ons!*

---

## ⚠️ Disclaimer

**Use at your own risk.** This is a hobby project with no guarantees of support or response times. Community contributions are welcomed.

---

*Made with ❤️ for the Home Assistant community by [Tokahiro](https://github.com/Tokahiro)*

</div>

---
## Automated Booklore add-on version bumps

This repository automatically updates the Booklore Home Assistant add-on whenever a new upstream release is published at https://github.com/booklore-app/booklore/releases and opens a pull request with the changes.

Workflow
- Action file: [.github/workflows/update-booklore.yml](.github/workflows/update-booklore.yml)
- Updater script: [.github/scripts/update_booklore.py](.github/scripts/update_booklore.py)
- Triggers:
  - Scheduled daily at 06:00 UTC
  - Manual: Actions → “Update Booklore Version” → Run workflow
  - Optional: repository_dispatch with type: upstream_release
- Permissions: contents: write; pull-requests: write
- Concurrency: only one run at a time; overlapping runs are canceled

What gets updated
- [booklore/build.yaml](booklore/build.yaml): BOOKLORE_REF → set to the latest upstream tag (e.g., "vX.Y.Z")
- [booklore/config.yaml](booklore/config.yaml): version → set to "X.Y.Z" (no leading v)
- [booklore/DOCS.md](booklore/DOCS.md): human text occurrences of “Version X.Y.Z”
- [booklore/README.md](booklore/README.md): human text “Version X.Y.Z” and the shields.io badge “version-X.Y.Z-”

Intentionally not changed
- [booklore/Dockerfile](booklore/Dockerfile): ARG BASHIO_VERSION (tooling dependency)
- [booklore/config.yaml](booklore/config.yaml): homeassistant minimum version

Pull request details
- Branch: chore/bump-booklore-vX.Y.Z
- Commit message and title: chore(booklore): bump to vX.Y.Z
- Labels: dependencies, booklore, automated
- PR body includes links to the upstream release and compare, and a list of changed files

How it works
- The script fetches the latest non-prerelease upstream tag via the GitHub API (/releases/latest)
- Current versions are read from:
  - [booklore/build.yaml](booklore/build.yaml) → BOOKLORE_REF (primary)
  - [booklore/config.yaml](booklore/config.yaml) → version (fallback)
- If already on the latest version: no changes and no PR
- If updates are needed: targeted regex rewrites are applied only to the files listed above

Manual and local runs
- In the GitHub UI: use the “Run workflow” button on the “Update Booklore Version” workflow
- Locally (optional), with a GitHub token for higher API rate limits:
  - export GH_TOKEN=&lt;your_token&gt;
  - python .github/scripts/update_booklore.py --repo booklore-app/booklore

Edge cases
- Prereleases/drafts are ignored (only stable releases are considered)
- Formatting (quotes, line structure) is preserved where possible
- Network or API errors will cause the job to fail and report logs in the Actions run
- Adding new targets in the future: adjust [.github/scripts/update_booklore.py](.github/scripts/update_booklore.py) with an additional file-specific rewrite rule
