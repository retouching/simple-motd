# simple-motd: show the screen once per terminal, in interactive shells only:
#   - in SSH sessions;
#   - with SHOW="ssh local" (install.sh --local), in every new local terminal too (Konsole,
#     GNOME Terminal, kitty...), but not in IDE terminals (VS Code, JetBrains) nor after sudo -s/-i.
# Installed as /etc/profile.d/simple-motd.sh; the system bashrc and zshrc source it as well when
# local terminals are on. SIMPLE_MOTD_SHOWN (exported) keeps subshells, su and tmux from showing it
# again. ~/.hushlogin turns it off; ~/.config/simple-motd.conf can set SHOW for one user.
case $- in
  *i*)
    __smd_show=""
    if [ -z "${SIMPLE_MOTD_SHOWN-}" ] && [ -t 1 ] && [ ! -e "${HOME-}/.hushlogin" ] \
       && [ -x /usr/local/bin/simple-motd ]; then
      if [ -n "${SSH_CONNECTION-}" ]; then
        __smd_show=1
      elif [ -z "${SUDO_USER-}" ] && [ "${TERM_PROGRAM-}" != vscode ]; then
        case ${TERMINAL_EMULATOR-} in
          JetBrains*) ;;
          *)
            __smd_conf=$(sed -n 's/^SHOW=//p' /etc/simple-motd.conf "${HOME-}/.config/simple-motd.conf" 2>/dev/null | tail -n 1)
            case $__smd_conf in *local*) __smd_show=1 ;; esac
            ;;
        esac
      fi
    fi
    if [ -n "$__smd_show" ]; then
      SIMPLE_MOTD_SHOWN=1
      export SIMPLE_MOTD_SHOWN
      /usr/local/bin/simple-motd show
    fi
    unset __smd_show __smd_conf
    ;;
esac
