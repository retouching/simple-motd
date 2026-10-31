# Configuration

## /etc/simple-motd.conf

```bash
THEME=pink        # pink, blue, green or orange (the screen and the prompt)
SSH_MODE=journal  # journal, private or off
WIDTH=66          # width of the header line, in columns
DISKS=""          # mount points in the usage part; empty: every local data file system
MAX_DISKS=6       # at most this many disk lines, the others counted on one line
```

`THEME`, `WIDTH`, `DISKS` and `MAX_DISKS` apply at the next login. `SSH_MODE` changes what sshd does in `private` mode: switch it with `sudo ./install.sh --ssh <mode>` rather than by hand.

## Themes

Each theme sets three colours of the 256-colour palette: the accent (bullets, bars, `@`), the section titles and the labels. The state colours stay the same in every theme: green when all is well, yellow for what waits (pending updates, a bar past 70 %), red for what needs you (security updates, failed logins, a bar past 90 %).

| Theme | Accent | Titles | Labels |
| --- | --- | --- | --- |
| pink | 213 | 205 | 218 |
| blue | 111 | 33 | 153 |
| green | 114 | 35 | 157 |
| orange | 215 | 208 | 223 |

## The simple-motd command

| Command | What it does |
| --- | --- |
| `simple-motd` or `simple-motd show` | Print the screen |
| `simple-motd collect` | Refresh the cache now (root; the timer does it every minute) |
| `simple-motd theme` | Print the theme; `simple-motd theme blue` sets it (root) |
| `simple-motd status` | The configuration, the age of the cache, the timer, the package manager and the SSH source in use |
| `simple-motd version` | The version |

## Hiding the screen

- For one user: `touch ~/.hushlogin` (it also hides the system's messages).
- For a session: the screen only shows in interactive SSH logins; `ssh host command`, `scp` and `rsync` never see it.
