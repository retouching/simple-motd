#!/usr/bin/env bash
# simple-motd uninstaller: removes every file install.sh put in place and gives back what it
# changed (system login messages, /etc/bash.bashrc, the sshd set-up of --ssh private).
#
#   sudo ./uninstall.sh [--dry-run]
set -euo pipefail

DRY=0
case ${1-} in --dry-run|-n) DRY=1 ;; "") ;; -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "unknown option: $1" >&2; exit 2 ;; esac

c_ok=$'\e[38;5;156m'; c_dim=$'\e[38;5;244m'; c_r=$'\e[0m'
step() { printf '%s==>%s %s\n' "$c_ok" "$c_r" "$*"; }
run()  { if (( DRY )); then printf '%s   would run:%s %s\n' "$c_dim" "$c_r" "$*"; else "$@"; fi; }

[[ $EUID -eq 0 ]] || { echo "run it as root: sudo ./uninstall.sh" >&2; exit 1; }

STATE_DIR=/var/lib/simple-motd
MOTD_DISABLED=""; BACKUP_DIR=""; SSH_UNIT=""
[[ -r $STATE_DIR/install.state ]] && . "$STATE_DIR/install.state"

step "timer"
if systemctl cat simple-motd-collect.timer >/dev/null 2>&1; then
  run systemctl disable --now -q simple-motd-collect.timer
fi

if [[ -e /etc/simple-motd-sshd.env || -e /etc/ssh/sshd_config.d/00-simple-motd.conf ]]; then
  step "ssh: back to the system's own logging"
  for u in ${SSH_UNIT:-ssh.service sshd.service}; do run rm -f "/etc/systemd/system/$u.d/50-simple-motd.conf"; done
  run rm -f /etc/simple-motd-sshd.env /etc/ssh/sshd_config.d/00-simple-motd.conf
  run systemctl daemon-reload
  for u in ${SSH_UNIT:-ssh.service sshd.service}; do
    if systemctl is-active -q "$u"; then run systemctl restart "$u"; fi
  done
fi

if [[ -n $MOTD_DISABLED ]]; then
  step "system login messages given back"
  for f in $MOTD_DISABLED; do [[ -f $f ]] && run chmod +x "$f"; done
fi
for f in /etc/motd /etc/legal; do
  if [[ -n $BACKUP_DIR && -f $BACKUP_DIR$f ]]; then run cp -a "$BACKUP_DIR$f" "$f"; fi
done

# Marked blocks in the system shell files (prompt, zsh login).
for f in /etc/bash.bashrc /etc/zsh/zshrc /etc/zshrc /etc/zsh/zprofile /etc/zprofile; do
  if ! { [[ -f $f ]] && grep -q '^# >>> simple-motd ' "$f"; }; then continue; fi
  step "shell hooks removed from $f"
  # Drop each block and the blank line install.sh put before it; nothing else moves.
  if (( DRY )); then printf '%s   would remove:%s the simple-motd blocks of %s\n' "$c_dim" "$c_r" "$f"; continue; fi
  awk '
    function flush() { while (blank > 0) { print ""; blank-- } }
    /^# >>> simple-motd .* >>>$/ { if (blank > 0) blank--; flush(); skip = 1; next }
    skip { if ($0 ~ /^# <<< simple-motd .* <<<$/) skip = 0; next }
    /^$/ { blank++; next }
    { flush(); print }
    END { flush() }' "$f" > "$f.simple-motd.tmp" && cat "$f.simple-motd.tmp" > "$f" && rm -f "$f.simple-motd.tmp"
done

step "files"
run rm -f /usr/local/bin/simple-motd /etc/profile.d/simple-motd.sh /etc/profile.d/simple-motd-prompt.sh \
  /etc/systemd/system/simple-motd-collect.service /etc/systemd/system/simple-motd-collect.timer \
  /etc/tmpfiles.d/simple-motd.conf /etc/simple-motd.conf
run rm -rf /usr/local/lib/simple-motd /run/simple-motd "$STATE_DIR"
run systemctl daemon-reload

if (( DRY )); then step "dry run: nothing was changed"
else
  step "simple-motd removed"
  [[ -n $BACKUP_DIR && -d $BACKUP_DIR ]] && printf '%sThe copies made at install time stay in %s%s\n' "$c_dim" "$BACKUP_DIR" "$c_r"
fi
exit 0
