#!/usr/bin/env python3
"""Fast checks of the repository that need no Godot, a second or two (CI's `lint` job):

- the project's rules for scripts: no `class_name`, no autoloads, no editor plugins
  (CLAUDE.md: scripts are loaded by `preload` consts and `extends "res://…"`);
- text files: no trailing spaces, no CRLF, a newline at the end, no merge conflict markers;
- every literal `load("res://…")` of a script and every resource a scene or a `.tres` names
  is a file of the repo (a `preload` is checked by tools/parse_check.gd, which compiles);
- no shader declares more than MAX_SAMPLERS samplers, its includes' counted;
- no 3D shader declares more than MAX_VARYINGS varying slots, its includes' and every
  `#ifdef` variant's counted together;
- the Python tools compile, the shell scripts parse (`bash -n`), the browser test parses
  (`node --check`, when node is there), the JSON files and the workflows parse;
- every file a `hand` list names (a bundle.yaml, a mod.yaml, assets/hand.yaml: the art made
  by hand, tools/hand_art.py) exists, and the trees' look.yaml files hold what their pictures
  measure (`tools/tree_feet.py --check`, which needs Pillow).

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
# The samplers a shader may declare, its includes' (common.gdshaderinc) counted, used or
# not: Godot gives each declared sampler a texture unit from 0, and the Compatibility
# renderer keeps the top units for its own (scene.glsl `texunit:-2` the sky, `-3` the
# sun's shadow atlas, ...). WebGL has 16 units, so a 14th sampler shares unit 13 with the
# shadow atlas, the browser refuses the draw and the shader's things vanish (the grass
# after #754); a desktop GL with 32 units and Android's Vulkan do not show it.
MAX_SAMPLERS = 13
SAMPLER = re.compile(r"^\s*(?:global\s+|instance\s+)?uniform\s+(?:\w+\s+)?sampler\w*\s+\w+", re.M)
INCLUDE = re.compile(r'^\s*#include\s+"res://([^"]+)"', re.M)
# The varying slots a 3D shader may declare: each varying one slot (a float as a vec4, a
# matN N, an array its length), the fragment-to-light ones too, which Godot counts though it
# passes them in no slot. Godot's Mobile renderer (Android) starts them at 14
# (scene_shader_forward_mobile.cpp base_varying_index) and refuses a shader past the GPU's
# limit, min(vertex outputs, fragment inputs) / 4: 28 on an Adreno 840, whose fragment
# inputs are 112. Counted over all of a shader's `#ifdef` variants at once (the falling
# trees' copy of tree.gdshader, TreeSprites.falling): it took 30, failed to build there and
# no falling tree was drawn (v0.5.912 to v0.5.929). The desktop's 32 and a WebGL's own
# count (from 0) do not show it.
MAX_VARYINGS = 14
VARYING = re.compile(r"^\s*varying\s+(?:(?:flat|smooth|lowp|mediump|highp)\s+)*(\w+)\s+\w+\s*(?:\[\s*(\d+)\s*\])?\s*;", re.M)
VARYING_SLOTS = {"mat2": 2, "mat3": 3, "mat4": 4}


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

    def samplers(path: pathlib.Path, seen: set) -> int:
        if path in seen or not path.is_file():
            return 0
        seen.add(path)
        text = path.read_text()
        return len(SAMPLER.findall(text)) + sum(samplers(ROOT / m, seen) for m in INCLUDE.findall(text))

    def varyings(path: pathlib.Path, seen: set) -> int:
        if path in seen or not path.is_file():
            return 0
        seen.add(path)
        text = path.read_text()
        n = sum(VARYING_SLOTS.get(m.group(1), 1) * int(m.group(2) or 1) for m in VARYING.finditer(text))
        return n + sum(varyings(ROOT / m, seen) for m in INCLUDE.findall(text))

    for path in files:
        if path.suffix == ".gdshader":
            n = samplers(path, set())
            if n > MAX_SAMPLERS:
                bad(path, 1, f"{n} samplers with its includes, at most {MAX_SAMPLERS}: the web build runs out of texture units (MAX_SAMPLERS in tools/lint.py)")
            if re.search(r"^\s*shader_type\s+spatial\b", path.read_text(), re.M):
                n = varyings(path, set())
                if n > MAX_VARYINGS:
                    bad(path, 1, f"{n} varying slots with its includes and all its variants, at most {MAX_VARYINGS}: an Adreno phone does not build it (MAX_VARYINGS in tools/lint.py)")

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

    # The art made by hand: each name a `hand` list gives is a file of its folder.
    sys.path.insert(0, str(ROOT / "tools"))
    import hand_art
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        if path.name in ("bundle.yaml", "mod.yaml", "hand.yaml") and rel.startswith(("content/", "assets/")):
            for name in sorted(hand_art._names(rel)):
                if not (path.parent / name).is_file():
                    bad(path, 1, f"`hand` names {name}, which is not a file of {path.parent.relative_to(ROOT).as_posix()}/")

    # The trees' look.yaml against their pictures (tools/tree_feet.py, after a tree is packed again).
    try:
        import PIL  # noqa: F401
    except ImportError:
        bad(ROOT / "tools/tree_feet.py", 1, "needs Pillow to check the trees' look.yaml (pip install pillow)")
    else:
        r = subprocess.run([sys.executable, "tools/tree_feet.py", "--check"], cwd=ROOT, capture_output=True, text=True)
        if r.returncode != 0:
            for line in (r.stdout + r.stderr).strip().splitlines()[-10:]:
                bad(ROOT / "tools/tree_feet.py", 1, f"--check: {line}")

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
