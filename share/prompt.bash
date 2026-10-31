# simple-motd prompt for bash: "user dir (branch) >" in pure bash (no starship, no git, no special font).
# Installed as /usr/local/lib/simple-motd/prompt.bash and sourced by interactive bash shells.
#   - user name in the theme colour, directory (~, and .../ past three levels)
#   - git branch read straight from .git/HEAD (git is never run)
#   - exit status in red, and a red >, after a failed command
# shellcheck shell=bash
[ -n "${BASH_VERSION-}" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac

__smp_theme=$(sed -n 's/^THEME=//p' /etc/simple-motd.conf "${HOME-}/.config/simple-motd.conf" 2>/dev/null | tail -1)
case ${__smp_theme:-pink} in
  blue)   __smp_a=111 __smp_h=33  __smp_l=153 ;;
  green)  __smp_a=114 __smp_h=35  __smp_l=157 ;;
  orange) __smp_a=215 __smp_h=208 __smp_l=223 ;;
  *)      __smp_a=213 __smp_h=205 __smp_l=218 ;;
esac

__smp_branch() {
  local d=$PWD head="" g
  while :; do
    if [[ -f $d/.git/HEAD ]]; then head=$(<"$d/.git/HEAD"); break
    elif [[ -f $d/.git ]]; then          # worktree or submodule: "gitdir: <path>"
      g=$(<"$d/.git"); g=${g#gitdir: }; [[ $g != /* ]] && g=$d/$g
      [[ -f $g/HEAD ]] && head=$(<"$g/HEAD"); break
    fi
    [[ -z $d ]] && break
    d=${d%/*}
  done
  [[ -z $head ]] && return
  if [[ $head == ref:* ]]; then printf '%s' "${head#ref: refs/heads/}"; else printf '%s' "${head:0:7}"; fi
}

__smp_dir() {
  local p=${PWD/#$HOME/\~} n
  local -a parts
  IFS=/ read -ra parts <<< "$p"; n=${#parts[@]}
  # "" or "~" first, then the levels: past three, keep the last three.
  if (( n > 4 )); then printf '.../%s/%s/%s' "${parts[n-3]}" "${parts[n-2]}" "${parts[n-1]}"
  else printf '%s' "$p"; fi
}

__smp_prompt() {
  local st=$? e=$'\e[' r
  r="\[${e}0m\]"
  # The branch goes through a variable: PS1 expands it once, never as code.
  __smp_b=$(__smp_branch)
  PS1="\[${e}1;38;5;${__smp_a}m\]\u${r} \[${e}38;5;${__smp_l}m\]\$(__smp_dir)${r}"
  [[ -n $__smp_b ]] && PS1+=" \[${e}38;5;222m\](\${__smp_b})${r}"
  if (( st )); then PS1+=" \[${e}38;5;203m\]${st}${r} \[${e}1;38;5;203m\]>${r} "
  else PS1+=" \[${e}1;38;5;${__smp_h}m\]>${r} "; fi
}

case ${PROMPT_COMMAND-} in
  *__smp_prompt*) ;;
  *) PROMPT_COMMAND="__smp_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac
