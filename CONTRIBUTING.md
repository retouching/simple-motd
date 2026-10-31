# Contributing

## Layout

| Path | What |
| --- | --- |
| `bin/simple-motd` | The command: `show`, `collect`, `theme`, `status` |
| `share/profile.sh` | Prints the screen at SSH login (installed in `/etc/profile.d`) |
| `share/prompt.{bash,zsh,sh}`, `share/profile-prompt.sh` | The optional prompt, one per shell, and what loads it |
| `share/demo/state` | A sample cache, for the theme previews of the installer and the README |
| `etc/simple-motd.conf` | The default configuration |
| `systemd/` | The timer, its service and the tmpfiles rules |
| `install.sh`, `uninstall.sh` | Installation and removal |
| `tests/run.sh`, `tests/containers/` | The tests and the systemd containers they run in |
| `docs/` | The documentation; `docs/previews/` the README pictures and how to make them |

The tools are bash (4.2+); what runs in the user's shell is POSIX sh (`share/profile.sh`, `share/profile-prompt.sh`, `share/prompt.sh`) or that shell's own (`prompt.bash`, `prompt.zsh`). No other language at run time, and no symbol outside ASCII in what the terminal shows.

## Tests

```bash
tests/run.sh                  # shellcheck, then every distribution
tests/run.sh debian-13        # one of them (a name of tests/containers/*.Dockerfile)
```

They need Docker. For each distribution, a container boots systemd, runs sshd, and the script checks: the install with every option and the packages it adds, the screen at a real SSH login (ASCII only, without the distribution's messages), one good and two refused logins counted in `journal` then in `private` mode with no address in the journal or in simple-motd's files, the three prompts printing the same lines (`tests/prompts.sh`), zsh and dash logins (screen once, prompt), `simple-motd theme`, the screen for a normal user, and that `uninstall.sh` gives `/etc` back file for file. The docker part is checked with a fake `docker` (`tests/fake/docker`: swarm manager, no swarm, daemon down), local terminals with `docker exec -t` (bash, zsh, dash, a subshell, VS Code, sudo, a pipe, one user's own setting). On Debian 12 it also checks the `/var/log/auth.log` fallback with a journal that keeps nothing.

Run them before each push. There is no CI.

## Previews

```bash
docs/previews/make.sh
```

It prints the screen in each theme from `share/demo/state` (whose `demo_*` values also replace the live uptime, load, memory, swap and disk) and a short prompt session, in the Debian 13 test container, then turns each capture into an HTML page (`render.py`, which needs `pyte`). Take a screenshot of each page's `<pre>` at twice the scale, as WebP, into `docs/previews/<name>.webp`.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/), in English: `feat:`, `fix:`, `docs:`, `test:`, `chore:`.
- One commit per change that stands on its own, with the tests passing.
- A version: `VERSION` in `bin/simple-motd` and a section in `CHANGELOG.md`. No tags.
