#!/usr/bin/env python3
"""Fast checks of the repository that need no Godot, a second or two (CI's `lint` job):

- the project's rules for scripts: no `class_name`, no autoloads, no editor plugins
  (CLAUDE.md: scripts are loaded by `preload` consts and `extends "res://…"`);
- text files: no trailing spaces, no CRLF, a newline at the end, no merge conflict markers;
- every literal `load("res://…")` of a script and every resource a scene or a `.tres` names
  is a file of the repo (a `preload` is checked by tools/parse_check.gd, which compiles);
- the Python tools compile, the shell scripts parse (`bash -n`), the browser test parses
  (`node --check`, when node is there), the JSON files and the workflows parse.

    python3 tools/lint.py          check, print each problem as path:line: what, fail on any
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXT = {".gd", ".py", ".sh", ".mjs", ".yml", ".yaml", ".md", ".json", ".cfg", ".tscn", ".tres",
        ".gdshader", ".gdshaderinc", ".godot", ".txt", ".html", ".svg", ".import"}
# Generated or third-party text (Godot's .import files, the fonts' licence) where trailing
# spaces and the last newline are not ours to keep; Markdown keeps "  " line breaks.
TRAILING_EXEMPT = {".md", ".import", ".svg", ".html", ".txt"}
LOAD = re.compile(r'\b(?:ResourceLoader\.)?load\("(res://[^"%{}]+)"')
## A text measured by the font itself, which sees a key in brackets, not the words shown.
MEASURE = re.compile(r"\.get_(?:multiline_)?string_size\(")
RESOURCE = re.compile(r'path="(res://[^"]+)"')


def tracked() -> list[pathlib.Path]:
    out = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT, capture_output=True, check=True).stdout
    return [ROOT / p for p in out.decode().split("\0") if p]


def main() -> int:
    problems: list[str] = []

    def bad(path: pathlib.Path, line: int, what: str) -> None:
        problems.append(f"{path.relative_to(ROOT)}:{line}: {what}")

    files = [p for p in tracked() if p.is_file()]
    for path in files:
        if path.suffix not in TEXT:
            continue
        data = path.read_bytes()
        if b"\r\n" in data:
            bad(path, data[: data.index(b"\r\n")].count(b"\n") + 1, "CRLF line ending")
        if data and not data.endswith(b"\n") and path.suffix not in TRAILING_EXEMPT:
            bad(path, data.count(b"\n") + 1, "no newline at the end of the file")
        text = data.decode("utf-8", errors="replace")
        for n, line in enumerate(text.split("\n"), 1):
            if path.suffix not in TRAILING_EXEMPT and line != line.rstrip(" \t"):
                bad(path, n, "trailing whitespace")
            if line.startswith(("<<<<<<< ", ">>>>>>> ")) or (line == "=======" and path.suffix != ".md"):
                bad(path, n, "merge conflict marker")
            if path.suffix == ".gd":
                if MEASURE.search(line) and path.as_posix().startswith(str(ROOT / "src")) \
                        and path.name != "ui_style.gd":
                    bad(path, n, "measures a text by hand: UiStyle.text_width / text_lines measure its words, not its key")
                if re.match(r"\s*class_name\s", line):
                    bad(path, n, "class_name: scripts are found by preload paths, not global names")
                for m in LOAD.finditer(line):
                    if not (ROOT / m.group(1)[len("res://"):]).exists():
                        bad(path, n, f"loads {m.group(1)}, which is not in the repo")
            elif path.suffix in (".tscn", ".tres"):
                for m in RESOURCE.finditer(line):
                    if not (ROOT / m.group(1)[len("res://"):]).exists():
                        bad(path, n, f"names {m.group(1)}, which is not in the repo")
        if path.suffix == ".json":
            try:
                json.loads(text)
            except ValueError as e:
                bad(path, 1, f"not JSON: {e}")

    project = (ROOT / "project.godot").read_text()
    if re.search(r"^\[autoload\]", project, re.M):
        bad(ROOT / "project.godot", 1, "[autoload]: the project has no autoloads, Main builds the modules")
    if re.search(r"^\[editor_plugins\]", project, re.M):
        bad(ROOT / "project.godot", 1, "[editor_plugins]: the project uses no plugins")

    for path in files:
        if path.suffix == ".py":
            try:
                compile(path.read_text(), str(path), "exec")
            except SyntaxError as e:
                bad(path, e.lineno or 1, f"does not compile: {e.msg}")
        elif path.suffix == ".sh":
            r = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
            if r.returncode != 0:
                bad(path, 1, f"bash -n: {r.stderr.strip()}")
        elif path.suffix == ".mjs" and shutil.which("node"):
            r = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
            if r.returncode != 0:
                bad(path, 1, f"node --check: {r.stderr.strip()}")

    try:
        import yaml  # PyYAML is on GitHub's runners; the workflows are checked where it is.
    except ImportError:
        yaml = None
    if yaml is not None:
        for path in files:
            if path.suffix in (".yml", ".yaml") and ".github" in path.parts:
                try:
                    yaml.safe_load(path.read_text())
                except yaml.YAMLError as e:
                    bad(path, 1, f"not YAML: {e}")

    for p in problems:
        print(p, file=sys.stderr)
    print(f"lint: {len(files)} files, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
