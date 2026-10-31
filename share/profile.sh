# simple-motd: show the login screen once per SSH session, in interactive shells only.
# Installed as /etc/profile.d/simple-motd.sh. Skipped with ~/.hushlogin.
case $- in
  *i*)
    if [ -n "${SSH_CONNECTION-}" ] && [ -z "${SIMPLE_MOTD_SHOWN-}" ] \
       && [ ! -e "${HOME-}/.hushlogin" ] && [ -x /usr/local/bin/simple-motd ]; then
      SIMPLE_MOTD_SHOWN=1
      export SIMPLE_MOTD_SHOWN
      /usr/local/bin/simple-motd show
    fi
    ;;
esac
