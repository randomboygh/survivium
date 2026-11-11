"""Renames the game: writes the new name where players and readers see it. Run from the
project folder:

    python3 tools/rename.py "New Name"            change the files, print what changed
    python3 tools/rename.py "New Name" --dry-run  only print what would change

The name lives in one place, `config/name` in project.godot: the main menu, the server's
default title and log, the «Данные для теста» report, the window and the web page's title
read it, and CI names the PC builds by it. This script changes that line and the copies
code cannot read: the link preview tags and the PC export paths in export_presets.cfg,
and the name in the README and the docs (not in docs/audit/, docs/planning/: dated
history). Then it draws the splash and the icon card again (tools/make_splash.py,
tools/make_icon.py, which take the name from project.godot).

It leaves alone what must not change with the name (docs/RENAMING.md): the saves' folder
(`config/custom_user_dir_name`), the repository and the web address
(randomboygh.github.io/survivium), the release `pc-latest`, the JavaScript names the
page and the game share (`window.survivium_*`), the Android package id.
"""

import re
import subprocess
import sys
from pathlib import Path

OLD_FROM = "project.godot"
# Text files whose copies of the name are rewritten, besides project.godot.
FILES = ["export_presets.cfg", "README.md", "CLAUDE.md"]
DOCS = "docs"
# Dated history keeps the name of its day; RENAMING.md names the saves' folder.
SKIP = ("docs/audit/", "docs/planning/", "docs/generated/", "docs/RENAMING.md")


def current_name() -> str:
	for line in Path(OLD_FROM).read_text(encoding="utf-8").splitlines():
		if line.startswith("config/name="):
			return line.split("=", 1)[1].strip().strip('"')
	sys.exit("project.godot has no config/name")


def replace_name(text: str, old: str, new: str) -> str:
	"""`old` as a whole word, as written and in capitals; never lowercase (addresses, ids)."""
	for a, b in ((old, new), (old.upper(), new.upper())):
		text = re.sub(r"(?<!\w)" + re.escape(a) + r"(?!\w)", b, text)
	return text


def main() -> None:
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	dry = "--dry-run" in sys.argv
	if len(args) != 1 or not args[0].strip() or '"' in args[0]:
		sys.exit(__doc__)
	new = args[0].strip()
	old = current_name()
	if new == old:
		sys.exit("the game is already called " + old)

	changed = []
	godot = Path(OLD_FROM).read_text(encoding="utf-8")
	godot = godot.replace('config/name="%s"' % old, 'config/name="%s"' % new, 1)
	paths = [Path(f) for f in FILES] + sorted(Path(DOCS).rglob("*.md"))
	edits = {Path(OLD_FROM): godot}
	for p in paths:
		if str(p).startswith(SKIP) or not p.exists():
			continue
		edits[p] = replace_name(p.read_text(encoding="utf-8"), old, new)
	for p, text in edits.items():
		if text != p.read_text(encoding="utf-8"):
			changed.append(str(p))
			if not dry:
				p.write_text(text, encoding="utf-8")
	print(("would change" if dry else "changed") + ": " + (", ".join(changed) or "nothing"))
	if dry:
		return
	for tool in ("tools/make_splash.py", "tools/make_icon.py"):
		subprocess.run([sys.executable, tool], check=True)
	print("now: python3 tools/doc_index.py, look at assets/splash.png (the sparrow sits on"
		+ " the first letter: BIRD_X in tools/make_splash.py) and assets/web/og.png, run the checks")


if __name__ == "__main__":
	main()
