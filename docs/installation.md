# Installation

simple-motd installs from a clone of the repository, as root:

```bash
git clone <repository> simple-motd && cd simple-motd
sudo ./install.sh [options]
```

## Options

| Option | Effect |
| --- | --- |
| `--theme NAME` | `pink`, `blue`, `green` or `orange`. Without it, the installer shows the four and asks (in a terminal), keeps the current one (on a new run), or takes `pink`. |
| `--ssh MODE` | `journal` (default), `private` or `off`: where SSH logins are counted from ([how it works](how-it-works.md#ssh-logins)). |
| `--prompt` | Also install the bash prompt (`root ~ >`). |
| `--local` / `--no-local` | Also show the screen in every new local terminal (`SHOW="ssh local"`), or back to SSH logins only. |
| `--replace-motd` | Hide the distribution's own login messages, so the screen is the only one. |
| `--yes` | Ask nothing: install the missing packages, keep the defaults. |
| `--dry-run` | Print every file and command the run would install or run; change nothing. |
| `--force` | Go on with a distribution outside the Debian, Ubuntu, Fedora and Arch families. |

Running `install.sh` again updates the installed files and applies the options given; the options of the last run (`--ssh`, `--prompt`, `--local`, `--replace-motd`, the theme) are kept when not given again. Keys that a newer version adds to the configuration are appended to it, with their comments; your values stay.

## What it changes

Always:

| Path | What |
| --- | --- |
| `/usr/local/bin/simple-motd` | The command ([configuration](configuration.md#the-simple-motd-command)) |
| `/etc/simple-motd.conf` | The configuration, kept on a new run (only `THEME` and `SSH_MODE` are set) |
| `/etc/systemd/system/simple-motd-collect.{service,timer}` | The cache refresh, every minute |
| `/etc/tmpfiles.d/simple-motd.conf` | `/run/simple-motd` (cache), `/run/simple-motd/ssh` (root only), `/var/lib/simple-motd` (root only) |
| `/etc/profile.d/simple-motd.sh` | Prints the screen once per SSH session, in interactive shells, unless `~/.hushlogin` exists |
| `/etc/zsh/zprofile` or `/etc/zprofile` | A marked block that loads the line above, for zsh logins (when zsh is installed; run the installer again after installing zsh) |
| `pciutils`, `dmidecode` (and on Arch `pacman-contrib`, `arch-audit`) | Installed when missing, after asking |

With `--local`: a marked block in `/etc/bash.bashrc` and in the system zshrc (`/etc/zsh/zshrc` or `/etc/zshrc`) sources `/etc/profile.d/simple-motd.sh`, since local terminals open non-login shells (Fedora's `/etc/bashrc` already reads `/etc/profile.d`). `--no-local` removes them.

With `--prompt`:

| Path | What |
| --- | --- |
| `/usr/local/lib/simple-motd/prompt.{bash,zsh,sh}` | The prompt, one file per shell |
| `/etc/profile.d/simple-motd-prompt.sh` | Loads the one of the running shell in login shells |
| `/etc/bash.bashrc` | A marked block that loads it in the other bash shells (Debian, Ubuntu, Arch) |
| `/etc/zsh/zshrc` or `/etc/zshrc` | The same for zsh |

A prompt set later by a user's own `~/.bashrc` or `~/.zshrc` (starship, oh-my-zsh, `PS1=`, `PROMPT=`) wins; the installer names those files.

With `--replace-motd`: the executable scripts of `/etc/update-motd.d` lose their execute bit (Debian, Ubuntu: Ubuntu's news, help links, Landscape…), and `/etc/motd` and `/etc/legal` (Ubuntu's notice) are emptied. All are given back by `uninstall.sh`.

With `--ssh private` (see [how it works](how-it-works.md#ssh-logins)):

| Path | What |
| --- | --- |
| `/etc/ssh/sshd_config.d/00-simple-motd.conf` | `LogLevel INFO`, so that logins are written at all |
| `/etc/simple-motd-sshd.env` | The unit's option variable (`SSHD_OPTS` or `OPTIONS`) with `-E /run/simple-motd/ssh/sshd.log` added to its current value |
| `/etc/systemd/system/<ssh unit>.d/50-simple-motd.conf` | Loads that file, creates the log folder, and drops the unit's messages from the journal (`LogFilterPatterns`, systemd 253+). When the unit has no option variable (Arch), it replaces `ExecStart` with the same command plus `-E` |

sshd is checked (`sshd -t`, and the `LogLevel` it ends up with) before it is restarted; open sessions stay open. If another file of `sshd_config.d` sets a `LogLevel` first (the first value wins), the installer stops, removes what it wrote and names that file. Switching back to `journal` or `off` removes the three files and restarts sshd.

## Backups

Before changing a shell file (`bash.bashrc`, `zshrc`, `zprofile`), `/etc/motd` or `/etc/legal`, the installer copies them to `/var/backups/simple-motd/<date>/`, with their path. What it changed is noted in `/var/lib/simple-motd/install.state`, which `uninstall.sh` reads.

## Updating

```bash
cd simple-motd && git pull && sudo ./install.sh
```

## Removing

```bash
sudo ./uninstall.sh            # or --dry-run first
```

It stops the timer, removes every file listed above, removes its blocks from the shell files, gives back the update-motd scripts, `/etc/motd` and `/etc/legal`, and restores sshd's own logging (restarting it) when `--ssh private` was used. The backups stay in `/var/backups/simple-motd/`.
