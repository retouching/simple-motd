# simple-motd prompt for zsh: "user dir (branch) >".
# Installed as /usr/local/lib/simple-motd/prompt.zsh, sourced from the system zshrc.
# Same look as the bash and sh prompts: theme colour, ~ and .../ past three levels,
# git branch read from .git/HEAD (git is never run), exit status in red after a failure.
[[ -o interactive ]] || return 0

typeset -g __smp_theme=${$(sed -n 's/^THEME=//p' /etc/simple-motd.conf "${HOME-}/.config/simple-motd.conf" 2>/dev/null | tail -n 1):-pink}
typeset -g __smp_a __smp_h __smp_l
case $__smp_theme in
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
  if [[ $head == ref:* ]]; then print -rn -- "${head#ref: refs/heads/}"; else print -rn -- "${head[1,7]}"; fi
}

__smp_dir() {
  local p=${PWD/#$HOME/\~}
  local -a parts=("${(@s:/:)p}")          # "" or "~" first, then one field per level
  if (( ${#parts} > 4 )); then print -rn -- ".../${(j:/:)parts[-3,-1]}"
  else print -rn -- "$p"; fi
}

__smp_precmd() {
  local st=$? b d
  b=$(__smp_branch); d=$(__smp_dir)
  # % in a name would be read as a prompt escape: double it.
  b=${b//\%/%%}; d=${d//\%/%%}
  PROMPT="%B%F{$__smp_a}%n%f%b %F{$__smp_l}${d}%f"
  [[ -n $b ]] && PROMPT+=" %F{222}(${b})%f"
  if (( st )); then PROMPT+=" %F{203}${st}%f %B%F{203}>%f%b "
  else PROMPT+=" %B%F{$__smp_h}>%f%b "; fi
}

setopt no_prompt_subst 2>/dev/null
autoload -Uz add-zsh-hook && add-zsh-hook precmd __smp_precmd
