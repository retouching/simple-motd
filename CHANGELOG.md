# Changelog

## 0.1.0

First version.

- The login screen: system, usage and security, aligned, ASCII only, in four themes (pink, blue, green, orange).
- A cache refreshed every minute by a systemd timer; the update list is recomputed only when the packages change.
- Updates from apt or dnf, security ones apart.
- SSH logins over 24 hours, in three modes: `journal` (with the auth.log / secure fallback), `private` (no address kept anywhere) and `off`.
- RAM, GPU and VRAM details from dmidecode, lspci, nvidia-smi and amdgpu.
- The optional bash prompt.
- `install.sh` (Debian, Ubuntu, Fedora; `--dry-run`, backups) and `uninstall.sh`.
