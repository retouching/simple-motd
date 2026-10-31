# Changelog

## 0.2.0

- Arch Linux: updates from `checkupdates` (pacman-contrib), security from `arch-audit`, `--ssh private` with an sshd unit that has no option variable.
- zsh and POSIX sh: the screen at login (zsh through the system `zprofile`), and the prompt in all three shells, line for line the same.
- The directory in the prompt keeps its last three levels behind `.../` only past three levels (`/a/b/c` stays whole).
- `sshd -T` read whatever the case of its keys (Arch prints `LogLevel`).

## 0.1.0

First version.

- The login screen: system, usage and security, aligned, ASCII only, in four themes (pink, blue, green, orange).
- A cache refreshed every minute by a systemd timer; the update list is recomputed only when the packages change.
- Updates from apt or dnf, security ones apart.
- SSH logins over 24 hours, in three modes: `journal` (with the auth.log / secure fallback), `private` (no address kept anywhere) and `off`.
- RAM, GPU and VRAM details from dmidecode, lspci, nvidia-smi and amdgpu.
- The optional bash prompt.
- `install.sh` (Debian, Ubuntu, Fedora; `--dry-run`, backups) and `uninstall.sh`.
