# simple-motd prompt for POSIX sh (dash, busybox ash, ksh): "user dir (branch) >".
# Installed as /usr/local/lib/simple-motd/prompt.sh, sourced by interactive login shells.
# Same look as the bash and zsh prompts: theme colour, ~ and .../ past three levels,
# git branch read from .git/HEAD (git is never run), exit status in red after a failure.
# The shell runs __smp_ps1 at each prompt (command substitution in PS1).
# shellcheck shell=sh
case $- in *i*) ;; *) return 0 ;; esac

__smp_theme=$(sed -n 's/^THEME=//p' /etc/simple-motd.conf 2>/dev/null | tail -n 1)
case ${__smp_theme:-pink} in
  blue)   __smp_a=111 __smp_h=33  __smp_l=153 ;;
  green)  __smp_a=114 __smp_h=35  __smp_l=157 ;;
  orange) __smp_a=215 __smp_h=208 __smp_l=223 ;;
  *)      __smp_a=213 __smp_h=205 __smp_l=218 ;;
esac
__smp_e=$(printf '\033')

__smp_branch() {
  __smp_d=$PWD
  while :; do
    if [ -f "$__smp_d/.git/HEAD" ]; then __smp_f=$__smp_d/.git/HEAD; break
    elif [ -f "$__smp_d/.git" ]; then          # worktree or submodule: "gitdir: <path>"
      IFS= read -r __smp_g < "$__smp_d/.git"; __smp_g=${__smp_g#gitdir: }
      case $__smp_g in /*) ;; *) __smp_g=$__smp_d/$__smp_g ;; esac
      __smp_f=$__smp_g/HEAD; break
    fi
    [ -z "$__smp_d" ] && return 0
    __smp_d=${__smp_d%/*}
  done
  [ -f "$__smp_f" ] || return 0
  IFS= read -r __smp_head < "$__smp_f" || [ -n "$__smp_head" ] || return 0
  case $__smp_head in
    "ref: refs/heads/"*) printf '%s' "${__smp_head#ref: refs/heads/}" ;;
    ref:*) printf '%s' "${__smp_head##*/}" ;;
    *) printf '%.7s' "$__smp_head" ;;
  esac
}

__smp_dir() {
  __smp_p=$PWD
  case $__smp_p in "$HOME") __smp_p="~" ;; "$HOME"/*) __smp_p="~${__smp_p#"$HOME"}" ;; esac
  # Past three levels: .../last/three/levels
  __smp_rest=$__smp_p __smp_out="" __smp_n=0
  while [ "$__smp_n" -lt 3 ] && [ -n "$__smp_rest" ] && [ "$__smp_rest" != "/" ]; do
    __smp_out="/${__smp_rest##*/}$__smp_out"; __smp_rest=${__smp_rest%/*}; __smp_n=$((__smp_n + 1))
  done
  case $__smp_rest in ""|"~"|"/") printf '%s' "$__smp_p" ;; *) printf '...%s' "$__smp_out" ;; esac
}

__smp_ps1() { # $1: exit status of the last command
  __smp_b=$(__smp_branch)
  printf '%s[1;38;5;%sm%s%s[0m %s[38;5;%sm%s%s[0m' "$__smp_e" "$__smp_a" "${USER:-$(id -un)}" "$__smp_e" \
    "$__smp_e" "$__smp_l" "$(__smp_dir)" "$__smp_e"
  [ -n "$__smp_b" ] && printf ' %s[38;5;222m(%s)%s[0m' "$__smp_e" "$__smp_b" "$__smp_e"
  if [ "$1" != 0 ]; then printf ' %s[38;5;203m%s %s[1;38;5;203m>%s[0m ' "$__smp_e" "$1" "$__smp_e" "$__smp_e"
  else printf ' %s[1;38;5;%sm>%s[0m ' "$__smp_e" "$__smp_h" "$__smp_e"; fi
}

PS1='$(__smp_ps1 "$?")'
