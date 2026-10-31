#!/usr/bin/env bash
# Tests: shellcheck, then install / SSH logins / modes / uninstall in systemd containers.
#
#   tests/run.sh                 every distribution
#   tests/run.sh debian-13 ...   some of them (names of tests/containers/*.Dockerfile)
#
# Needs Docker. Containers run privileged (systemd as PID 1) and are removed at the end.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
fails=0; ok() { printf '  \e[32mok\e[0m   %s\n' "$*"; }; ko() { printf '  \e[31mFAIL\e[0m %s\n' "$*"; fails=$((fails + 1)); }
check() { local what=$1; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else ko "$what"; fi; }

echo "== shellcheck"
if docker run --rm -v "$ROOT:/m:ro" -w /m koalaman/shellcheck:stable \
     bin/simple-motd install.sh uninstall.sh share/prompt.sh tests/run.sh \
   && docker run --rm -v "$ROOT:/m:ro" -w /m koalaman/shellcheck:stable -s sh share/profile.sh; then ok shellcheck
else ko shellcheck; fi

distros=("$@")
if (( ! ${#distros[@]} )); then
  for f in tests/containers/*.Dockerfile; do distros+=("$(basename "$f" .Dockerfile)"); done
fi

for d in "${distros[@]}"; do
  echo "== $d"
  img=simple-motd-test:$d c=simple-motd-test-$d
  docker build -q -t "$img" -f "tests/containers/$d.Dockerfile" tests/containers >/dev/null || { ko "build $d"; continue; }
  docker rm -f "$c" >/dev/null 2>&1
  # A private cgroup namespace: with the host's, journald loses the messages of the units.
  docker run -d --name "$c" --privileged --cgroupns=private --tmpfs /run --tmpfs /run/lock "$img" >/dev/null
  x() { docker exec "$c" bash -c "$*"; }
  for _ in $(seq 30); do x 'systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"' && break; sleep 1; done
  docker cp "$ROOT" "$c:/opt/simple-motd" >/dev/null
  # A key for SSH logins to 127.0.0.1 inside the container.
  x 'ssh-keygen -q -t ed25519 -N "" -f /root/.ssh/id_ed25519 && cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys'
  x 'systemctl start ssh 2>/dev/null || systemctl start sshd'
  x 'find /etc -xdev -type f -print0 | sort -z | xargs -0 md5sum > /root/etc.before; find /etc -xdev -type f -perm -u+x | sort > /root/etc.x.before'

  login() { x 'ssh -tt -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 <<< exit 2>&1'; }
  bad()   { x 'for u in nobodyx root; do ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -i /dev/null $u@127.0.0.1 true 2>/dev/null; done; true'; }

  # --- journal mode, all options
  out=$(x '/opt/simple-motd/install.sh --yes --theme blue --prompt --replace-motd 2>&1')
  check "install (journal, prompt, replace-motd)" grep -q "done. The screen" <<< "$out"
  check "timer active" x 'systemctl is-active -q simple-motd-collect.timer'
  check "lspci and dmidecode installed" x 'command -v lspci && { [ "$(uname -m)" != x86_64 ] || command -v dmidecode; }'
  screen=$(login | sed 's/\x1b\[[0-9;]*m//g')
  check "screen shown at SSH login" grep -q "security" <<< "$screen"
  check "header with user@host" grep -qE -- "-+ .*root.*@" <<< "$screen"
  check "no system motd left" bash -c '! grep -qiE "programs included|Welcome to Ubuntu|Documentation:" <<< "$1"' _ "$screen"
  check "screen is ASCII only" bash -c '! LC_ALL=C grep -qP "[^\x00-\x7F]" <<< "$1"' _ "$screen"
  bad
  x 'sleep 1; simple-motd collect'
  check "journal: 1 ok, 2 failed" x 'simple-motd show | sed "s/\x1b\[[0-9;]*m//g" | grep -q "1 ok | 2 failed (last 24h)"'
  check "no address stored" x '! grep -rqE "([0-9]{1,3}\.){3}[0-9]{1,3}" /var/lib/simple-motd /run/simple-motd'
  check "updates line" x 'simple-motd show | grep -q -e "up to date" -e pending'
  check "prompt in a login shell" bash -c 'grep -q "root .*>" <<< "$1"' _ "$screen"
  check "bash, zsh and sh prompts identical" x 'bash /opt/simple-motd/tests/prompts.sh'
  # Fedora's own /etc/profile.d is bash-only (lang.sh): dash is no login shell there.
  shells="zsh dash"; [[ $d == fedora-* ]] && shells=zsh
  for sh in $shells; do
    x "usermod -s \$(command -v $sh) root"
    s2=$(login | sed 's/\x1b\[[0-9;]*m//g')
    check "$sh login: screen" grep -q "security" <<< "$s2"
    check "$sh login: screen once" test "$(grep -c '^security' <<< "$s2")" -eq 1
    check "$sh login: prompt" grep -q "root ~ >" <<< "$s2"
  done
  x 'usermod -s /bin/bash root'
  check "theme command" x 'simple-motd theme green && grep -q THEME=green /etc/simple-motd.conf'
  check "show as a normal user" x 'useradd -m t 2>/dev/null; su t -c "simple-motd show" | grep -q usage'
  t0=$(date +%s%N); x 'simple-motd show >/dev/null'; ms=$(( ($(date +%s%N) - t0) / 1000000 ))
  check "show is fast (${ms} ms incl. docker exec)" test "$ms" -lt 600

  # --- private mode
  out=$(x '/opt/simple-motd/install.sh --yes --ssh private 2>&1')
  if grep -q "done. The screen" <<< "$out"; then
    ok "install --ssh private"
    x 'sleep 1; journalctl --rotate -q; journalctl --vacuum-time=1s -q' >/dev/null 2>&1
    since=$(x 'date "+%Y-%m-%d %H:%M:%S"')
    login >/dev/null; bad; x 'sleep 1; simple-motd collect'
    check "private: 1 ok, 2 failed" x 'simple-motd show | sed "s/\x1b\[[0-9;]*m//g" | grep -q "1 ok | 2 failed"'
    check "private: sshd log emptied" x '! test -s /run/simple-motd/ssh/sshd.log'
    check "private: no address in the journal" x "! journalctl --since '$since' -q | grep -qE '127\.0\.0\.1'"
  else
    printf '%s\n' "$out" | tail -3 | sed 's/^/       /'
    if grep -q "LogFilterPatterns needs" <<< "$out"; then ok "private refused cleanly (old systemd)"; else ko "install --ssh private"; fi
  fi

  # --- uninstall gives /etc back
  x '/opt/simple-motd/uninstall.sh >/dev/null'
  x 'userdel -r t 2>/dev/null; find /etc -xdev -type f -print0 | sort -z | xargs -0 md5sum > /root/etc.after; find /etc -xdev -type f -perm -u+x | sort > /root/etc.x.after'
  diff=$(x 'diff /root/etc.before /root/etc.after | grep "^[<>]" | grep -vE "/etc/(ld.so.cache|machine-id|shadow-?|gshadow-?|passwd-?|group-?|subuid-?|subgid-?|\.pwd\.lock|apt/|dnf/|pki/|ssl/|alternatives/|arch-audit/|conf.d/pacman-contrib|systemd/system/(multi-user|sockets|timers)\.target\.wants/|systemd/system/ssh)" ; diff /root/etc.x.before /root/etc.x.after')
  if [[ -z $diff ]]; then ok "uninstall gives /etc back"; else ko "uninstall gives /etc back"; printf '       %s\n' "${diff//$'\n'/$'\n       '}" | head -10; fi
  check "nothing left" x '! ls /usr/local/bin/simple-motd /var/lib/simple-motd /etc/simple-motd.conf 2>/dev/null | grep -q .'

  # --- journal kept nowhere: fall back to /var/log/auth.log (rsyslog), on one Debian
  if [[ $d == debian-12 ]]; then
    x 'apt-get install -y -q rsyslog >/dev/null 2>&1; mkdir -p /etc/systemd/journald.conf.d
       printf "[Journal]\nStorage=none\n" > /etc/systemd/journald.conf.d/none.conf
       journalctl --rotate -q; journalctl --vacuum-time=1s -q; systemctl restart systemd-journald rsyslog ssh; sleep 1'
    x '/opt/simple-motd/install.sh --yes >/dev/null 2>&1'
    login >/dev/null; bad; x 'sleep 2; simple-motd collect'
    check "auth.log fallback: source file" x 'simple-motd status | grep -q "ssh source  file"'
    check "auth.log fallback: 1 ok, 2 failed" x 'simple-motd show | sed "s/\x1b\[[0-9;]*m//g" | grep -q "1 ok | 2 failed"'
    x '/opt/simple-motd/uninstall.sh >/dev/null'
  fi

  docker rm -f "$c" >/dev/null
done

echo
if (( fails )); then echo "$fails failure(s)"; exit 1; fi
echo "all good"
