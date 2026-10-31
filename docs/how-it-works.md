# How it works

## The cache

`simple-motd-collect.timer` runs `simple-motd collect` every minute (and 15 seconds after boot). It writes `/run/simple-motd/state`, a short file of `name=value` lines, in one atomic move. At login, `/etc/profile.d/simple-motd.sh` runs `simple-motd show`, which reads that file and adds the values that are instant to read: uptime, load, memory, swap and disk, from `/proc` and `df`. Nothing slow runs at login.

When the cache is more than five minutes old, the screen says so under the security part.

## Where each value comes from

| Line | Source |
| --- | --- |
| os | `/etc/os-release`, `uname -m` |
| uptime | `/proc/uptime` |
| cpu (system) | `/proc/cpuinfo` (model, average frequency), `lscpu` (cores), `nproc` (threads), `systemd-detect-virt` |
| ram | `dmidecode -t memory`: total, DDR type, configured speed, modules used out of slots, maker; virtual machines rarely give more than the size |
| gpu | `lspci` (first VGA, 3D or display controller), and its size of VRAM |
| load | `/proc/loadavg`, as a share of the threads |
| cpu (usage) | `/proc/stat`, average over the last minute (between two runs of the timer) |
| memory, swap | `/proc/meminfo` (used = total minus available) |
| vram | `nvidia-smi`, or `mem_info_vram_*` of amdgpu; shown only when the card tells its use |
| disk | `df` of `/` |
| updates | below |
| ssh | below |

## Updates

- **apt** (Debian, Ubuntu): `apt list --upgradable`; a package is a security update when its suite ends in `-security` (`trixie-security`, `noble-security`). The date is the last `Start-Date` of `/var/log/apt/history.log`.
- **dnf** (Fedora): `dnf -C check-update` and `dnf -C updateinfo list --security --updates`, from the metadata cache only (`dnf-makecache.timer` refreshes it). The date is the last install time in the rpm database.

- **pacman** (Arch): `checkupdates` (pacman-contrib), which syncs a copy of the databases into a temporary folder, so the system's stay untouched and no partial upgrade can follow; without it, `pacman -Qu` on the local databases, as fresh as the last `pacman -Sy`. Security: the number of upgradable packages `arch-audit -u` lists with a fixed vulnerability (0 without arch-audit). The date is the last `transaction completed` of `/var/log/pacman.log`. On Arch, these two queries go to the network, at most every six hours.

The list is recomputed only when the package database or the metadata change (their modification times), or after six hours, so a minute-long timer costs almost nothing. On Debian, Ubuntu and Fedora simple-motd never refreshes the metadata itself: `apt-daily.timer` and `dnf-makecache.timer` do.

## SSH logins

One line: logins that worked, logins that failed, over the last 24 hours. A login that worked is an `Accepted …` line of sshd; one that failed is a connection that ended before authenticating (`Connection closed by` or `Disconnected from` an `authenticating` or `invalid user`, or `maximum authentication attempts exceeded`): one per connection, whatever the number of keys or passwords tried in it.

Each one is stored as `<time> ok` or `<time> fail` in `/var/lib/simple-motd/ssh-events` (root only), and lines older than 24 hours are dropped. No address and no user name are ever written by simple-motd.

### journal (default)

sshd is left as it is. simple-motd reads the journal of the sshd unit (`ssh.service` or `sshd.service`) from where it stopped the previous minute (a saved cursor), going back 24 hours on the first run. When the journal keeps nothing for the unit (no persistent or volatile journal), it reads `/var/log/auth.log` (Debian, Ubuntu with rsyslog) or `/var/log/secure` (Fedora with rsyslog) from a saved offset, starting at the end of the file on the first run and from the top after a rotation.

The addresses stay in the system's logs as before: simple-motd only reads them. If sshd runs with `LogLevel QUIET` (or lower), there is nothing to count and the line says so.

### private

For servers where no SSH address should be kept:

- sshd writes its log, with `-E`, to `/run/simple-motd/ssh/sshd.log` only: a file in RAM, readable by root only, never in the journal or on disk;
- every minute, `simple-motd collect` turns its lines into `ok`/`fail` counts and empties it, so an address stays at most a minute in RAM;
- the PAM modules (which log through syslog, with the address) are dropped from the journal by `LogFilterPatterns` on the sshd unit (systemd 253 or later; on older systems the installer warns that they still reach it);
- `LogLevel INFO` is set, since a silent sshd would leave nothing to count.

sshd's own errors go to the same file and are emptied with it: in this mode, read them with `sshd -t` or by running `sshd -d` on another port.

### off

No line, and nothing read.

## Login shells

The screen is printed by `/etc/profile.d/simple-motd.sh`, a POSIX file: bash and sh (dash, ash, ksh) read it as login shells, and zsh reads it through a block the installer adds to the system `zprofile` (`/etc/zsh/zprofile` or `/etc/zprofile`), since zsh does not read `/etc/profile.d` everywhere. `SIMPLE_MOTD_SHOWN` keeps it to once per session when both paths run.

## The prompt

Three versions print the same thing, checked by the tests line for line:

| Shell | File | How it runs |
| --- | --- | --- |
| bash | `prompt.bash` | `PROMPT_COMMAND` rebuilds `PS1` before each prompt |
| zsh | `prompt.zsh` | a `precmd` hook rebuilds `PROMPT`; `%` in a name is escaped |
| sh (dash, ash, ksh) | `prompt.sh` | `PS1` calls a function at each prompt (command substitution) |

They live in `/usr/local/lib/simple-motd/`. `/etc/profile.d/simple-motd-prompt.sh` loads the one of the running shell in login shells; blocks in `/etc/bash.bashrc` and the system `zshrc` (`/etc/zsh/zshrc` or `/etc/zshrc`) load it in the other interactive shells. A non-login sh only reads the file named by `$ENV`.

```
root ~ >
root .../src/app/web (main) >
root .../src/app/web (main) 1 >
```

- the user, in the accent colour;
- the directory, with `~` for the home folder, and only its last three levels behind `.../` past that;
- the git branch, read from `.git/HEAD` in the directory or its parents (worktrees and submodules too), or the first seven characters of the commit when detached; git itself is never run, and the branch name is never run as code;
- after a failed command, its exit status in red, and a red `>`.

The colours come from the theme in `/etc/simple-motd.conf`, read when the shell starts.
