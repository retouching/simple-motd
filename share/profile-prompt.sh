# simple-motd prompt: the one of the running shell (bash, zsh, or POSIX sh: dash, ash, ksh).
# Installed as /etc/profile.d/simple-motd-prompt.sh.
if [ -n "${BASH_VERSION-}" ]; then
  . /usr/local/lib/simple-motd/prompt.bash
elif [ -n "${ZSH_VERSION-}" ]; then
  . /usr/local/lib/simple-motd/prompt.zsh
else
  . /usr/local/lib/simple-motd/prompt.sh
fi
