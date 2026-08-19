# Deep Optimizer Pro — Quick Start (Ubuntu VPS)

Version **2.2.0**

## 1. Preview on your server

```bash
curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh \
  | sudo bash -s -- --vps --dry-run
```

## 2. Apply VPS optimize

```bash
curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh \
  | sudo bash -s -- --vps
```

Or install once:

```bash
git clone https://github.com/iSystemDevelopment/deep-optimizer-pro.git
cd deep-optimizer-pro
sudo ./install.sh
sudo deep-optimizer --vps
```

## 3. Everyday commands

| Goal | Command |
|------|---------|
| Interactive menu | `sudo deep-optimizer` |
| Update packages | `sudo deep-optimizer --update` |
| Harden only | `sudo deep-optimizer --harden` |
| Quick clean | `sudo deep-optimizer --quick` |
| Preview anything | add `--dry-run` |

## 4. After hardening — check SSH

```bash
sudo ufw status
sudo ss -tlnp | grep ssh
sudo systemctl status fail2ban --no-pager
```

If you use a non-22 SSH port, confirm UFW allowed it (the tool reads `Port` from `sshd_config`).

## 5. Safety checklist

1. Snapshot / backup the VPS in your provider panel first.
2. Run `--dry-run` once.
3. Keep provider console access available.
4. Do not enable `SSH_DISABLE_ROOT=true` until a sudo user + key login works.

## 6. Logs & backups

```bash
sudo tail -f /var/log/deep-optimizer-pro/optimization.log
ls -la /var/backups/deep-optimizer-pro/
```

## 7. Uninstall

```bash
cd /path/to/deep-optimizer-pro   # or /opt/deep-optimizer-pro-src
sudo ./install.sh --uninstall
```

---

Created by iSystem Development · MIT License
