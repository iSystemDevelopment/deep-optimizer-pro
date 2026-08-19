# Deep Optimizer Pro

**Linux / Ubuntu VPS optimizer** — clean, update, and harden servers with one command.

[![Version](https://img.shields.io/badge/version-2.2.0-blue.svg)](https://github.com/iSystemDevelopment/deep-optimizer-pro)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange.svg)](https://ubuntu.com)

Built for people running **VPS / cloud Ubuntu** (DigitalOcean, Hetzner, Linode, AWS, your own box) — but also works on desktop/workstation Linux.

---

## Quick start (Ubuntu VPS)

### A) One-liner (no install)

```bash
curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh | sudo bash
```

Defaults to **`--vps`** (update + clean + harden). Preview first:

```bash
curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh | sudo bash -s -- --vps --dry-run
```

### B) Clone + install (recommended)

```bash
git clone https://github.com/iSystemDevelopment/deep-optimizer-pro.git
cd deep-optimizer-pro
sudo ./install.sh
sudo deep-optimizer --vps --dry-run   # preview
sudo deep-optimizer --vps             # apply
```

### C) Interactive menu

```bash
sudo deep-optimizer
# or without install:
sudo ./deep-optimizer-pro.sh
```

---

## What `--vps` does

| Step | Action |
|------|--------|
| Backup | Config tarball under `/var/backups/deep-optimizer-pro` |
| Update | `apt`/`dnf`/`yum` upgrade |
| Clean | package caches, old kernels, temp, journal, Docker/Snap (no volume wipe by default) |
| Tune | sysctl persistence (`/etc/sysctl.d/99-deep-optimizer.conf`), memory/network flush |
| Harden | SSH (key-root friendly), UFW (detects SSH port), Fail2ban, safe file modes |

**Safe by default for remote SSH:**

- Detects custom SSH ports before opening UFW
- Does **not** force `PermitRootLogin no` (uses `prohibit-password` unless `SSH_DISABLE_ROOT=true`)
- Skips full-filesystem permission walks and ClamAV unless opted in
- Docker volume prune is off unless `DOCKER_PRUNE_VOLUMES=true`

---

## Commands

```bash
sudo deep-optimizer --vps              # recommended on servers
sudo deep-optimizer --vps --dry-run
sudo deep-optimizer --update           # packages only
sudo deep-optimizer --harden           # SSH / UFW / Fail2ban / sysctl
sudo deep-optimizer --quick            # fast clean
sudo deep-optimizer --full             # broader workstation-style run
sudo deep-optimizer --module storage
sudo deep-optimizer --module performance
sudo deep-optimizer --module security
sudo deep-optimizer --help
```

Useful flags: `--yes` (non-interactive), `--quiet`, `--verbose`, `--profile vps|desktop|full|auto`.

---

## Weekly timer (optional)

After `install.sh`:

```bash
sudo systemctl enable --now deep-optimizer.timer   # Sundays ~03:30 --quick
```

---

## Requirements

- Linux (Ubuntu 20.04+ / Debian 11+ recommended; Fedora/RHEL/Arch also detected)
- Bash 4+
- Root (`sudo`)

---

## Layout

```
deep-optimizer-pro.sh   # main entry
run.sh                  # curl|bash / local launcher
install.sh              # install to /opt + PATH symlink
lib/common.sh           # logging, distro/VPS detect, sysctl helpers
modules/
  storage_optimizer.sh
  performance_optimizer.sh
  security_hardening.sh
```

Config (after install): `/etc/deep-optimizer-pro/config.conf`  
Logs: `/var/log/deep-optimizer-pro/`  
Backups: `/var/backups/deep-optimizer-pro/`

---

## Docs

| Doc | Purpose |
|-----|---------|
| [QUICK_START.md](QUICK_START.md) | Install + first run on a VPS |
| [SECURITY.md](SECURITY.md) | Reporting + hardening notes |
| [LICENSE](LICENSE) | MIT |

---

## Warnings

- Always run **`--dry-run`** on a production VPS the first time.
- Keep an out-of-band console (provider VNC/serial) before changing SSH/UFW.
- Optimization and hardening can still break unusual setups — backups are created, but you own the risk.

---

## Support

- Issues: https://github.com/iSystemDevelopment/deep-optimizer-pro/issues  
- Email: support@isystem.app  
- Site: https://isystem.app  

Made by [iSystem Development](https://isystem.app)
