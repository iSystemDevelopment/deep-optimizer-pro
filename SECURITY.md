# Security Policy — Deep Optimizer Pro

## Supported versions

| Version | Supported |
| --- | --- |
| 2.2.x | Yes |
| 2.1.x | Best effort |
| < 2.1 | No |

## Reporting a vulnerability

Do **not** open a public GitHub issue for security bugs.

Email **support@isystem.app** with subject:  
`SECURITY — Deep Optimizer Pro`

Or use GitHub private advisories on:  
https://github.com/iSystemDevelopment/deep-optimizer-pro/security/advisories/new

Include OS/version, tool version, repro steps, and impact.

We aim to acknowledge within **48 hours**.

## Hardening notes (operators)

- `--harden` / `--vps` open UFW for the **detected SSH port**, then HTTP/HTTPS.
- Root SSH defaults to **`prohibit-password`** (keys allowed). Set `SSH_DISABLE_ROOT=true` only after another sudo account works.
- Full rootkit / ClamAV / password-policy passes require opt-in (`SECURITY_FULL=true`, `ENABLE_ANTIVIRUS=true`).
- Always keep provider console access before applying firewall or SSH changes.
