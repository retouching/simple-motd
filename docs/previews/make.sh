#!/usr/bin/env bash
# Make the previews of docs/previews/ again: prints the screen in each theme and a prompt session
# as ANSI files, then turns them into HTML pages (render.py) to screenshot.
#
#   docs/previews/make.sh            -> docs/previews/build/*.ansi and *.html
#
# Then take a screenshot of each page (element <pre>) as WebP, for example:
#   chromium --headless --screenshot=pink.webp --window-size=760,560 build/pink.html
# Needs Docker (Debian 13 test image) and Python 3 with pyte (pip install pyte).
set -euo pipefail
cd "$(dirname "$0")"
REPO=$(cd ../.. && pwd)
mkdir -p build
img=simple-motd-test:debian-13
docker build -q -t "$img" -f "$REPO/tests/containers/debian-13.Dockerfile" "$REPO/tests/containers" >/dev/null

for t in pink blue green orange; do
  docker run --rm --hostname atlas -e USER=root -e SIMPLE_MOTD_CONF=/dev/null -e SIMPLE_MOTD_THEME="$t" \
    -e SIMPLE_MOTD_RUN=/m/share/demo -v "$REPO:/m:ro" "$img" bash /m/bin/simple-motd show > "build/$t.ansi"
done

# A short session with the prompt: home, a git repository deep down, a failed command.
docker run --rm --hostname atlas -e USER=root -e HOME=/root -v "$REPO:/m:ro" "$img" bash -ic '
  set +e
  mkdir -p /srv/app/web/src && git_head=/srv/app/.git && mkdir -p $git_head && echo "ref: refs/heads/main" > $git_head/HEAD
  cd /root
  . /m/share/prompt.sh
  __smp_prompt_demo() { __smp_prompt; printf "%s%s\n" "${PS1@P}" "$1"; }
  # PS1 brackets \[ \] become \001 \002 once expanded: drop them.
  { true;  __smp_prompt_demo "cd /srv/app/web/src"
    cd /srv/app/web/src; true; __smp_prompt_demo "make test"
    false; __smp_prompt_demo "cd /etc"
    cd /etc; true; __smp_prompt_demo ""; } | tr -d "\001\002"
' > build/prompt.ansi 2>/dev/null

python3 render.py build/*.ansi
echo "pages in $(pwd)/build: screenshot each <pre> as ../<name>.webp"
