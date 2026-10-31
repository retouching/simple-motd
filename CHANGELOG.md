# Changelog

## 0.4.1

- The line of dashes around `user@host` takes the whole width of the terminal, and a second one closes the screen at the bottom (`WIDTH` when the width is unknown).

## 0.4.0

- Local terminals: `install.sh --local` shows the screen in every new tab or window of Konsole, GNOME Terminal, kitty... (once per terminal, not in subshells, tmux, IDE terminals or after `sudo -s`); `SHOW` in the configuration, and per user in `~/.config/simple-motd.conf` (with `THEME`).
- Docker part: version, swarm role and nodes, containers (running, stopped, paused, unhealthy), images, volumes, networks, stacks (or compose projects); `DOCKER=auto|off`.
- The screen fits narrow terminals (header, bars, long lines cut).
- Labels 10 characters wide.
- A new run of `install.sh` appends the configuration keys added since, with their comments.

## 0.3.0

- System: one line per physical disk (size, NVMe/SSD/HDD/virtual, model), one line per GPU.
- Usage: one VRAM line per card that reports it, one disk line per local file system (with its mount point), `DISKS` and `MAX_DISKS` in the configuration.
- SSH, journal mode: a journald set to `Storage=none` sends the count to auth.log / secure even when older journal files remain.

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
