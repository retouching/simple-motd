#!/usr/bin/env bash
# Prompt check: the bash, zsh and sh prompts must print the same text in the same places.
# Run inside a test container (tests/run.sh does), with the repository at /opt/simple-motd.
set -u
S=/opt/simple-motd/share
mkdir -p /root/a/b/c/d /srv/app/web/src /srv/app/.git && echo "ref: refs/heads/main" > /srv/app/.git/HEAD
dirs="/root /root/a/b/c /root/a/b/c/d /etc / /srv/app /srv/app/web/src"

strip() { sed 's/\x1b\[[0-9;]*m//g; s/\x01//g; s/\x02//g'; }

for_bash() {
  bash --norc -i 2>/dev/null <<EOF | strip
. $S/prompt.bash
for d in $dirs; do cd "\$d"; true; __smp_prompt; printf '%s|\n' "\${PS1@P}"; done
false; __smp_prompt; printf '%s|\n' "\${PS1@P}"
EOF
}
for_zsh() {
  zsh -f -i 2>/dev/null <<EOF | strip
. $S/prompt.zsh
for d in $dirs; do cd "\$d"; true; __smp_precmd; print -r -- "\${(%)PROMPT}|"; done
false; __smp_precmd; print -r -- "\${(%)PROMPT}|"
EOF
}
for_sh() {
  dash -i 2>/dev/null <<EOF | strip
. $S/prompt.sh
for d in $dirs; do cd "\$d"; true; printf '%s|\n' "\$(__smp_ps1 "\$?")"; done
false; printf '%s|\n' "\$(__smp_ps1 "\$?")"
EOF
}
export HOME=/root USER=root
b=$(for_bash | grep '|$'); z=$(for_zsh | grep '|$'); s=$(for_sh | grep '|$')
printf 'bash:\n%s\n' "$b"
rc=0
[[ $b == "$z" ]] || { echo "zsh differs:"; diff <(echo "$b") <(echo "$z"); rc=1; }
[[ $b == "$s" ]] || { echo "sh differs:"; diff <(echo "$b") <(echo "$s"); rc=1; }
(( rc )) || echo "bash, zsh and sh prompts identical"
exit $rc
