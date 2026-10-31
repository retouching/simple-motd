#!/usr/bin/env bash
# simple-motd installer. Run from a clone of the repository, as root:
#
#   sudo ./install.sh [options]
#
#   --theme NAME        pink, blue, green or orange (asked when run in a terminal, pink otherwise)
#   --ssh MODE          journal (default), private or off: where SSH attempts are counted from
#   --prompt            also install the "user dir >" prompt (bash, zsh, sh)
#   --local             also show the screen in every new local terminal (Konsole, GNOME Terminal...)
#   --no-local          back to SSH sessions only
#   --replace-motd      hide the system's own login messages (update-motd.d, /etc/motd, /etc/legal)
#   --yes               no question: install missing packages, keep the defaults
#   --dry-run           print what would be done, change nothing
#   --force             go on with a distribution that was not tested
#
# Running it again updates the files and applies the new options. ./uninstall.sh undoes it all.
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN=/usr/local/bin/simple-motd
LIB=/usr/local/lib/simple-motd
CONF=/etc/simple-motd.conf
STATE_DIR=/var/lib/simple-motd
STATE=$STATE_DIR/install.state
UNIT_DIR=/etc/systemd/system
SSHD_ENV=/etc/simple-motd-sshd.env
SSHD_CONF=/etc/ssh/sshd_config.d/00-simple-motd.conf
PRIVATE_LOG=/run/simple-motd/ssh/sshd.log

THEME=""; SSH_MODE=""; PROMPT=0; REPLACE_MOTD=0; YES=0; DRY=0; FORCE=0; LOCAL=""

c_ok=$'\e[38;5;156m'; c_warn=$'\e[38;5;222m'; c_bad=$'\e[38;5;203m'; c_dim=$'\e[38;5;244m'; c_r=$'\e[0m'
say()  { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "$c_ok" "$c_r" "$*"; }
warn() { printf '%swarning:%s %s\n' "$c_warn" "$c_r" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$c_bad" "$c_r" "$*" >&2; exit 1; }
run()  { if (( DRY )); then printf '%s   would run:%s %s\n' "$c_dim" "$c_r" "$*"; else "$@"; fi; }
put()  { # put SRC DEST MODE: install a file, saying so in dry-run
  if (( DRY )); then printf '%s   would install:%s %s (%s)\n' "$c_dim" "$c_r" "$2" "$3"; else install -D -m "$3" "$1" "$2"; fi
}
write() { # write DEST MODE <<< content
  local dest=$1 mode=$2 tmp
  tmp=$(mktemp); cat > "$tmp"
  put "$tmp" "$dest" "$mode"; rm -f "$tmp"
}

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while (( $# )); do
  case $1 in
    --theme) THEME=${2-}; shift ;;
    --theme=*) THEME=${1#*=} ;;
    --ssh) SSH_MODE=${2-}; shift ;;
    --ssh=*) SSH_MODE=${1#*=} ;;
    --prompt) PROMPT=1 ;;
    --local) LOCAL=1 ;;
    --no-local) LOCAL=0 ;;
    --replace-motd) REPLACE_MOTD=1 ;;
    --yes|-y) YES=1 ;;
    --dry-run|-n) DRY=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage 0 ;;
    *) warn "unknown option: $1"; usage 2 ;;
  esac
  shift
done

# --------------------------------------------------------------------------- checks

[[ $EUID -eq 0 ]] || die "run it as root: sudo ./install.sh"
(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )) || die "bash 4.2 or later is needed"
[[ -d /run/systemd/system ]] || die "systemd is needed (the cache is refreshed by a systemd timer)"
[[ -f $SRC/bin/simple-motd ]] || die "run install.sh from the simple-motd repository"

. /etc/os-release
FAMILY=""
case " ${ID-} ${ID_LIKE-} " in
  *" debian "*|*" ubuntu "*) FAMILY=debian ;;
  *" fedora "*|*" rhel "*|*" centos "*) FAMILY=fedora ;;
  *" arch "*) FAMILY=arch ;;
esac
if [[ -z $FAMILY ]]; then
  (( FORCE )) || die "${PRETTY_NAME:-this system} was not tested (Debian, Ubuntu, Fedora and Arch are). --force to go on"
  warn "${PRETTY_NAME:-unknown system}: not tested, going on (--force)"
fi

PREV_SSH_MODE=""; PREV_PROMPT=0; PREV_REPLACE=0; PREV_LOCAL=0; CREATED=""; MOTD_DISABLED=""; BACKUP_DIR=""; SSH_UNIT=""
[[ -r $STATE ]] && . "$STATE"
[[ -r $CONF ]] && CUR_THEME=$(sed -n 's/^THEME=//p' "$CONF" | tail -1) || CUR_THEME=""

case ${SSH_MODE:=${PREV_SSH_MODE:-journal}} in journal|private|off) ;; *) die "--ssh: journal, private or off" ;; esac
(( PREV_PROMPT )) && PROMPT=1
[[ -z $LOCAL ]] && LOCAL=$PREV_LOCAL
if (( LOCAL )); then SHOW="ssh local"; else SHOW="ssh"; fi
(( PREV_REPLACE )) && REPLACE_MOTD=1

# --------------------------------------------------------------------------- packages

need=()
command -v lspci >/dev/null 2>&1 || need+=(pciutils)
case $(uname -m) in x86_64|i?86) command -v dmidecode >/dev/null 2>&1 || need+=(dmidecode) ;; esac
command -v lscpu >/dev/null 2>&1 || need+=(util-linux)
command -v awk >/dev/null 2>&1 || need+=(gawk)
# Arch: checkupdates (pacman-contrib) for an up-to-date count, arch-audit for the security one.
if [[ $FAMILY == arch ]]; then
  command -v checkupdates >/dev/null 2>&1 || need+=(pacman-contrib)
  command -v arch-audit >/dev/null 2>&1 || need+=(arch-audit)
fi
if (( ${#need[@]} )); then
  step "packages to install: ${need[*]} (CPU, RAM and GPU details)"
  if (( ! YES )) && [[ -t 0 ]]; then
    read -r -p "    install them? [Y/n] " a; [[ ${a:-y} =~ ^[Yy] ]] || { warn "skipped: those lines will be shorter"; need=(); }
  fi
  if (( ${#need[@]} )); then
    case $FAMILY in
      debian) run env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${need[@]}" >/dev/null ;;
      fedora) run dnf -y -q install "${need[@]}" >/dev/null ;;
      arch) run pacman -S --needed --noconfirm -q "${need[@]}" >/dev/null ;;
      *) warn "install ${need[*]} by hand" ;;
    esac
  fi
fi

# --------------------------------------------------------------------------- theme

if [[ -z $THEME ]]; then
  if [[ -n $CUR_THEME ]]; then THEME=$CUR_THEME
  elif (( YES )) || [[ ! -t 0 ]]; then THEME=pink
  else
    step "pick a theme"
    for t in pink blue green orange; do
      printf '\n  %s%s%s\n' "$c_dim" "$t" "$c_r"
      SIMPLE_MOTD_CONF=/dev/null SIMPLE_MOTD_THEME=$t SIMPLE_MOTD_RUN=$SRC/share/demo \
        bash "$SRC/bin/simple-motd" show 2>/dev/null | sed -n '2,9p'
    done
    echo
    read -r -p "    theme [pink/blue/green/orange] (pink): " THEME
    THEME=${THEME:-pink}
  fi
fi
case $THEME in pink|blue|green|orange) ;; *) die "--theme: pink, blue, green or orange" ;; esac

# --------------------------------------------------------------------------- backups

if [[ -z $BACKUP_DIR ]]; then BACKUP_DIR=/var/backups/simple-motd/$(date +%Y%m%d-%H%M%S); fi
backup() { # copy a file once into the backup folder, with its path
  local f=$1
  [[ -e $f && ! -e $BACKUP_DIR$f ]] || return 0
  run mkdir -p "$BACKUP_DIR$(dirname "$f")"
  run cp -a "$f" "$BACKUP_DIR$f"
}

# --------------------------------------------------------------------------- files

step "simple-motd $(sed -n 's/^VERSION=//p' "$SRC/bin/simple-motd") (theme $THEME, ssh $SSH_MODE, shown in: $SHOW)"
put "$SRC/bin/simple-motd" "$BIN" 755
put "$SRC/systemd/simple-motd-collect.service" "$UNIT_DIR/simple-motd-collect.service" 644
put "$SRC/systemd/simple-motd-collect.timer" "$UNIT_DIR/simple-motd-collect.timer" 644
put "$SRC/systemd/simple-motd.tmpfiles.conf" /etc/tmpfiles.d/simple-motd.conf 644
put "$SRC/share/profile.sh" /etc/profile.d/simple-motd.sh 644

# The configuration: kept on a new run, with THEME, SSH_MODE and SHOW set; keys added by a newer
# version are appended with their comments.
[[ -e $CONF ]] || put "$SRC/etc/simple-motd.conf" "$CONF" 644
if (( DRY )); then say "${c_dim}   would set:${c_r} THEME=$THEME SSH_MODE=$SSH_MODE SHOW=\"$SHOW\" in $CONF"
else
  awk -v conf="$CONF" 'BEGIN { while ((getline l < conf) > 0) if (l ~ /^[A-Z_]+=/) { split(l, k, "="); have[k[1]] = 1 } }
       /^#/ || /^$/ { block = block $0 "\n"; next }
       /^[A-Z_]+=/ { split($0, k, "="); if (!(k[1] in have)) printf "\n%s%s\n", block, $0; block = "" }' \
    "$SRC/etc/simple-motd.conf" | sed '/^$/N;/^\n$/D' >> "$CONF"
  sed -i "s/^THEME=.*/THEME=$THEME/; s/^SSH_MODE=.*/SSH_MODE=$SSH_MODE/; s/^SHOW=.*/SHOW=\"$SHOW\"/" "$CONF"
fi

# --------------------------------------------------------------------------- shell hooks

# A marked block in a system shell file, written again on each run (removed by uninstall.sh).
set_block() { # set_block FILE NAME LINE
  local f=$1 begin="# >>> simple-motd $2 >>>" end="# <<< simple-motd $2 <<<"
  if grep -qxF "$begin" "$f" 2>/dev/null && \
     [[ $(sed -n "/^$begin\$/,/^$end\$/p" "$f" | sed -n 2p) == "$3" ]]; then return 0; fi
  backup "$f"
  if (( DRY )); then say "${c_dim}   would set:${c_r} the $2 block of $f"; return 0; fi
  sed -i "/^$begin\$/,/^$end\$/d" "$f"
  printf '\n%s\n%s\n%s\n' "$begin" "$3" "$end" >> "$f"
}
unset_block() { # unset_block FILE NAME: remove a block and the blank line before it
  local f=$1
  grep -qxF "# >>> simple-motd $2 >>>" "$f" 2>/dev/null || return 0
  if (( DRY )); then say "${c_dim}   would remove:${c_r} the $2 block of $f"; return 0; fi
  awk -v b="# >>> simple-motd $2 >>>" -v e="# <<< simple-motd $2 <<<" '
    function flush() { while (blank > 0) { print ""; blank-- } }
    $0 == b { if (blank > 0) blank--; flush(); skip = 1; next }
    skip { if ($0 == e) skip = 0; next }
    /^$/ { blank++; next }
    { flush(); print }
    END { flush() }' "$f" > "$f.simple-motd.tmp" && cat "$f.simple-motd.tmp" > "$f" && rm -f "$f.simple-motd.tmp"
}

# zsh does not read /etc/profile.d on every system (Debian, Ubuntu): show the screen from zprofile.
ZPROFILE=""; ZSHRC=""
for f in /etc/zsh/zprofile /etc/zprofile; do [[ -f $f ]] && { ZPROFILE=$f; break; }; done
for f in /etc/zsh/zshrc /etc/zshrc; do [[ -f $f ]] && { ZSHRC=$f; break; }; done
# zsh without a system zshrc (Arch ships only /etc/zsh/zprofile): create it next to zprofile, so
# that non-login zsh shells get the prompt and local terminals; uninstall.sh removes it if empty.
CREATED=${CREATED-}
if [[ -z $ZSHRC && -n $ZPROFILE ]] && command -v zsh >/dev/null 2>&1 && (( PROMPT || LOCAL )); then
  ZSHRC=$(dirname "$ZPROFILE")/zshrc
  if (( DRY )); then say "${c_dim}   would create:${c_r} $ZSHRC"
  else : > "$ZSHRC"; chmod 644 "$ZSHRC"; fi
  [[ " $CREATED " == *" $ZSHRC "* ]] || CREATED+="${CREATED:+ }$ZSHRC"
fi
if [[ -n $ZPROFILE ]]; then
  set_block "$ZPROFILE" login "[ -r /etc/profile.d/simple-motd.sh ] && . /etc/profile.d/simple-motd.sh"
fi

# Local terminals (Konsole...) open non-login shells: they read the system bashrc and zshrc.
# Fedora's /etc/bashrc already reads /etc/profile.d.
LOCAL_LINE="[ -r /etc/profile.d/simple-motd.sh ] && . /etc/profile.d/simple-motd.sh"
if (( LOCAL )); then
  step "local terminals: the screen in every new terminal"
  [[ -f /etc/bash.bashrc ]] && set_block /etc/bash.bashrc local "$LOCAL_LINE"
  [[ -n $ZSHRC ]] && set_block "$ZSHRC" local "$LOCAL_LINE"
else
  [[ -f /etc/bash.bashrc ]] && unset_block /etc/bash.bashrc local
  [[ -n $ZSHRC ]] && unset_block "$ZSHRC" local
fi

if (( PROMPT )); then
  step "prompt (bash, zsh and sh)"
  put "$SRC/share/prompt.bash" "$LIB/prompt.bash" 644
  put "$SRC/share/prompt.zsh" "$LIB/prompt.zsh" 644
  put "$SRC/share/prompt.sh" "$LIB/prompt.sh" 644
  put "$SRC/share/profile-prompt.sh" /etc/profile.d/simple-motd-prompt.sh 644
  # Login shells read /etc/profile.d; the others read these files.
  [[ -f /etc/bash.bashrc ]] && set_block /etc/bash.bashrc prompt "[ -r $LIB/prompt.bash ] && . $LIB/prompt.bash"
  [[ -n $ZSHRC ]] && set_block "$ZSHRC" prompt "[ -r $LIB/prompt.zsh ] && . $LIB/prompt.zsh"
  home=""; [[ -n ${SUDO_USER-} ]] && home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  for rc in /root/.bashrc /root/.zshrc ${home:+$home/.bashrc $home/.zshrc}; do
    [[ -r $rc ]] && grep -qE '^[^#]*(starship init|oh-my-posh|oh-my-zsh|powerlevel|PROMPT_COMMAND=|PS1=|PROMPT=)' "$rc" \
      && warn "$rc sets its own prompt (starship, oh-my-zsh, PS1...): it runs after simple-motd's and wins. Comment it out to use simple-motd's."
  done
  [[ -z $ZSHRC ]] && command -v zsh >/dev/null 2>&1 && warn "no system zshrc found: zsh gets the prompt in login shells only"
fi

# --------------------------------------------------------------------------- system login messages

if (( REPLACE_MOTD )); then
  step "system login messages hidden"
  if [[ -d /etc/update-motd.d ]]; then
    for f in /etc/update-motd.d/*; do
      [[ -f $f && -x $f ]] || continue
      run chmod -x "$f"
      MOTD_DISABLED+="${MOTD_DISABLED:+ }$f"
    done
  fi
  # /etc/legal: Ubuntu's notice, shown until a user has seen it once.
  for f in /etc/motd /etc/legal; do
    if [[ -s $f ]]; then backup "$f"; run truncate -s 0 "$f"; fi
  done
fi

# --------------------------------------------------------------------------- ssh

ssh_unit() {
  local u
  for u in ssh.service sshd.service; do
    if systemctl cat "$u" >/dev/null 2>&1; then echo "$u"; return 0; fi
  done
  return 0
}

remove_private() {
  [[ -n $SSH_UNIT ]] || SSH_UNIT=$(ssh_unit)
  local changed=0
  [[ -e $UNIT_DIR/$SSH_UNIT.d/50-simple-motd.conf ]] && { run rm -f "$UNIT_DIR/$SSH_UNIT.d/50-simple-motd.conf"; changed=1; }
  [[ -e $SSHD_ENV ]] && { run rm -f "$SSHD_ENV"; changed=1; }
  [[ -e $SSHD_CONF ]] && { run rm -f "$SSHD_CONF"; changed=1; }
  if (( changed )); then
    run systemctl daemon-reload
    systemctl is-active -q "$SSH_UNIT" && run systemctl restart "$SSH_UNIT"
    step "ssh: private mode removed, sshd logs as before"
  fi
}

setup_private() {
  SSH_UNIT=$(ssh_unit); [[ -n $SSH_UNIT ]] || die "--ssh private: no ssh.service or sshd.service"
  grep -qsE '^\s*Include\s+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config \
    || die "--ssh private: /etc/ssh/sshd_config does not include sshd_config.d"
  local exec var envfiles cur=""
  exec=$(systemctl show -p ExecStart --value "$SSH_UNIT")
  var=$(grep -oE '\$\{?[A-Z_]+' <<< "$exec" | head -1 | tr -d '${' || true)
  # No option variable (Arch: ExecStart=/usr/bin/sshd -D): ExecStart is replaced instead.
  local exec_line=""
  if [[ -z $var ]]; then
    local argv; argv=$(sed -nE 's/.*argv\[\]=([^;]*[^ ;]) *;.*/\1/p' <<< "$exec" | head -1)
    [[ $argv == */sshd* ]] || die "--ssh private: cannot read the ExecStart of $SSH_UNIT"
    exec_line=$'ExecStart=\nExecStart='"$argv -E $PRIVATE_LOG"
    var=SIMPLE_MOTD_UNUSED
  fi
  envfiles=$(systemctl show -p EnvironmentFiles --value "$SSH_UNIT" | awk '{print $1}')
  for f in $envfiles; do
    [[ -r $f ]] && cur=$(set +u; . "$f" >/dev/null 2>&1; eval "printf '%s' \"\${$var-}\"")
  done
  cur=${cur//-E $PRIVATE_LOG/}

  step "ssh: private mode ($SSH_UNIT logs only to $PRIVATE_LOG, in RAM)"
  printf '# simple-motd: sshd logs to RAM only (see install.sh --ssh private)\n%s="%s"\n' \
    "$var" "$(echo "$cur -E $PRIVATE_LOG" | sed 's/^ *//')" | write "$SSHD_ENV" 644
  local filter=""
  local sdv; sdv=$(systemctl --version | awk 'NR==1{print $2}')
  if (( ${sdv%%.*} >= 253 )); then
    filter=$'# PAM modules log through syslog, with the address: keep them out of the journal.\nLogFilterPatterns=~.'
  else
    warn "systemd $sdv: PAM messages (with the address) still reach the journal (LogFilterPatterns needs 253+)"
  fi
  write "$UNIT_DIR/$SSH_UNIT.d/50-simple-motd.conf" 644 <<EOF
# simple-motd --ssh private: sshd writes its log to $PRIVATE_LOG (RAM, 0600) only;
# simple-motd collect turns it into "ok"/"fail" counts every minute and empties it.
[Service]
ExecStartPre=/bin/mkdir -p -m 0700 /run/simple-motd/ssh
EnvironmentFile=$SSHD_ENV
$exec_line
$filter
EOF
  write "$SSHD_CONF" 644 <<'EOF'
# simple-motd --ssh private: sshd must log the attempts for them to be counted.
# They go to /run/simple-motd/ssh/sshd.log only (see the ssh unit drop-in), not to the journal.
LogLevel INFO
EOF
  (( DRY )) && return
  local lvl; lvl=$(sshd -T 2>/dev/null | awk 'tolower($1)=="loglevel"{print toupper($2)}')
  if [[ $lvl != INFO && $lvl != VERBOSE ]]; then
    local who; who=$(grep -lisE '^\s*LogLevel' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf | grep -v "$SSHD_CONF" | paste -sd' ' - || true)
    remove_private
    die "--ssh private: sshd keeps LogLevel $lvl, set first in: $who (the first value wins). Remove that line and run again."
  fi
  sshd -t || { remove_private; die "--ssh private: sshd -t failed, nothing changed"; }
  systemctl daemon-reload
  if systemctl is-active -q "$SSH_UNIT"; then
    systemctl restart "$SSH_UNIT"
    sleep 1
    local pid; pid=$(systemctl show -p MainPID --value "$SSH_UNIT")
    tr '\0' ' ' < "/proc/$pid/cmdline" | grep -qF -- "-E $PRIVATE_LOG" \
      || warn "$SSH_UNIT restarted without -E $PRIVATE_LOG: check $SSHD_ENV"
  fi
}

case $SSH_MODE in
  private) setup_private ;;
  *) [[ $PREV_SSH_MODE == private ]] && remove_private ;;
esac

# --------------------------------------------------------------------------- start

step "timer"
run systemd-tmpfiles --create /etc/tmpfiles.d/simple-motd.conf
run systemctl daemon-reload
run systemctl enable --now -q simple-motd-collect.timer
if (( ! DRY )); then
  mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
  # A new mode starts its counts from zero.
  [[ $PREV_SSH_MODE != "$SSH_MODE" ]] && rm -f "$STATE_DIR/ssh-events" "$STATE_DIR/journal.cursor" "$STATE_DIR/authfile.pos"
  {
    echo "# written by install.sh, read by uninstall.sh"
    echo "PREV_SSH_MODE=$SSH_MODE"; echo "PREV_PROMPT=$PROMPT"; echo "PREV_LOCAL=$LOCAL"; echo "CREATED=$(printf '%q' "$CREATED")"; echo "PREV_REPLACE=$REPLACE_MOTD"
    echo "MOTD_DISABLED=$(printf '%q' "$MOTD_DISABLED")"; echo "BACKUP_DIR=$(printf '%q' "$BACKUP_DIR")"
    echo "SSH_UNIT=$(printf '%q' "$SSH_UNIT")"
  } > "$STATE"
  "$BIN" collect
  step "done. The screen, as the next SSH login will show it:"
  "$BIN" show
  [[ -d $BACKUP_DIR ]] && say "${c_dim}Files replaced are kept in $BACKUP_DIR${c_r}"
else
  step "dry run: nothing was changed"
fi
