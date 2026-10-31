#!/usr/bin/env python3
"""Turn ANSI captures (256 colours) into HTML pages ready to screenshot.

    python3 render.py build/pink.ansi [...]   -> build/pink.html [...]

Needs pyte (pip install pyte): it plays the escape codes on a virtual terminal.
"""
import html
import sys
from pathlib import Path

import pyte

COLUMNS, LINES = 80, 40
BACKGROUND = "#1a1b26"
FOREGROUND = "#e8e8e8"


def colour(name: str) -> str:
    if len(name) == 6:  # pyte gives 256-colour cells as hex
        return "#" + name
    return FOREGROUND


def render(path: Path) -> None:
    screen = pyte.Screen(COLUMNS, LINES)
    pyte.Stream(screen).feed(path.read_text(encoding="utf-8").replace("\n", "\r\n"))
    used = [y for y in range(LINES) if screen.display[y].strip()]
    rows = []
    for y in range(used[0], used[-1] + 1):
        cells = []
        for x in range(COLUMNS):
            c = screen.buffer[y][x]
            weight = "font-weight:bold;" if c.bold else ""
            cells.append(f'<span style="color:{colour(c.fg)};{weight}">{html.escape(c.data)}</span>')
        rows.append("".join(cells).rstrip())
    page = (
        f'<html><body style="margin:0;background:{BACKGROUND}">'
        f'<pre style="font:15px/1.4 \'DejaVu Sans Mono\',monospace;padding:20px 24px;margin:0;'
        f'display:inline-block;background:{BACKGROUND}">' + "\n".join(rows) + "</pre></body></html>"
    )
    path.with_suffix(".html").write_text(page, encoding="utf-8")


for arg in sys.argv[1:]:
    render(Path(arg))
