#!/usr/bin/env python3
"""The phrases of the game and what each language lacks (decision 183, src/shared/content/lang.gd).

The game is written in Russian: every Russian string literal in src/ (but logs: print,
push_error, the server's console) and every title and description in content/ is a
phrase a language translates. The code's go to content/core/lang/<code>.yaml, a mod's
manifest's to content/<mod>/lang/, a bundle's data and manifest's to <bundle>/lang/.

    python3 tools/lang_check.py                 what every language lacks, exit 1 on a broken file
                                                or a phrase glued to values (glued)
    python3 tools/lang_check.py --write en      adds the phrases en lacks, empty, to its files,
                                                and drops those no longer used
    python3 tools/lang_check.py --missing en    the phrases en lacks, as JSON {key: file}
    python3 tools/lang_check.py --strict en     exit 1 when en lacks a phrase too

A translation must keep the template's `%s`, `%d`... in the same order.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")
LANGS = ["en", "ru", "es", "pt", "fr", "de", "it", "pl", "tr", "uk"]
SOURCE = "ru"
RUSSIAN = re.compile(r"[А-Яа-яЁё]")
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
FORMAT = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[sdifxXc%]")
# Files whose phrases only the server's console shows.
CONSOLE = {"src/server/server_main.gd", "src/server/real_weather.gd", "src/server/tunnel.gd",
           "src/shared/content/content_graph.gd"}
LOG_CALLS = ("print(", "printerr(", "push_error(", "push_warning(", "assert(", "print_debug(")
# Files where a phrase may be glued to values with `%` or `+` (see glued): the server's
# replies to commands (its console, an op's chat), the draw census of the stats panel,
# and a new team's name, which the players then edit as plain text.
GLUE_OK = {"src/server/server.gd", "src/server/requests.gd", "src/client/view/draw_census.gd",
           "src/shared/game/teams.gd"}


def unescape(s):
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "n":
                out.append("\n")
            elif n == "t":
                out.append("\t")
            elif n == "u" and i + 5 < len(s) + 1:
                out.append(chr(int(s[i + 2:i + 6], 16)))
                i += 6
                continue
            else:
                out.append(n)
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def code_part(line):
    """The line without its comment."""
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#":
            return line[:i]
        i += 1
    return line


RUN = re.compile(r'"((?:[^"\\\n]|\\.)*)"((?:\s*\+\s*"(?:[^"\\\n]|\\.)*")*)')


def code_texts():
    """(relative path, the code with comments, logs and doc lines blanked) of src/."""
    for base, _dirs, files in os.walk(os.path.join(ROOT, "src")):
        for f in sorted(files):
            if not f.endswith(".gd"):
                continue
            path = os.path.join(base, f)
            rel = os.path.relpath(path, ROOT)
            if rel in CONSOLE:
                continue
            with open(path, encoding="utf-8") as fh:
                raw_lines = fh.read().split("\n")
            kept = []
            for raw in raw_lines:
                line = code_part(raw)
                st = line.strip()
                kept.append("" if st.startswith(LOG_CALLS) or st.startswith("##") else line)
            yield rel, "\n".join(kept)


def code_phrases():
    """{phrase: first file:line} of src/; literals joined by `+` are one phrase."""
    out = {}
    for rel, text in code_texts():
            for m in RUN.finditer(text):
                parts = [m.group(1)] + re.findall(r'"((?:[^"\\\n]|\\.)*)"', m.group(2) or "")
                s = "".join(unescape(x) for x in parts)
                if RUSSIAN.search(s):
                    out.setdefault(s, "%s:%d" % (rel, text.count("\n", 0, m.start()) + 1))
    return out


YAML_FIELD = re.compile(r"^\s*(?:-\s+)?(title|description):\s*(.+?)\s*$")


def yaml_scalar(v):
    v = v.strip()
    if v.startswith('"') and v.endswith('"') and len(v) >= 2:
        return unescape(v[1:-1])
    if v.startswith("'") and v.endswith("'") and len(v) >= 2:
        return v[1:-1].replace("''", "'")
    # A plain scalar: cut a comment.
    m = re.search(r"\s#", v)
    return v[:m.start()].strip() if m else v


def glued():
    """["file:line: text"] of phrases put together with values by `%` or `+` instead of
    Lang.line / Lang.f: the table has the template, not the text made of it, so it
    stays Russian on the screen."""
    out = []
    for rel, text in code_texts():
        if rel in GLUE_OK:
            continue
        for m in RUN.finditer(text):
            parts = [m.group(1)] + re.findall(r'"((?:[^"\\\n]|\\.)*)"', m.group(2) or "")
            if not RUSSIAN.search("".join(parts)):
                continue
            after = text[m.end():].lstrip(" \t")
            before = text[:m.start()].rstrip(" \t\n\\")
            if after.startswith("%") or after.startswith("+") or before.endswith("+"):
                n = text.count("\n", 0, m.start()) + 1
                out.append("%s:%d: %s" % (rel, n, text.split("\n")[n - 1].strip()))
    return out


def content_phrases():
    """{lang dir (relative to content/): {phrase: file}} of the content's titles and descriptions."""
    out = {}
    for base, dirs, files in os.walk(CONTENT):
        dirs.sort()
        rel_base = os.path.relpath(base, CONTENT)
        if rel_base.split(os.sep)[0].startswith("_"):
            continue
        for f in sorted(files):
            if not f.endswith(".yaml") or rel_base.endswith("lang"):
                continue
            path = os.path.join(base, f)
            if f == "mod.yaml" or f == "bundle.yaml":
                owner = rel_base
            elif os.path.basename(base) == "data":
                owner = os.path.dirname(rel_base)
            else:
                continue
            with open(path, encoding="utf-8") as fh:
                for n, raw in enumerate(fh, 1):
                    m = YAML_FIELD.match(raw)
                    if not m:
                        continue
                    s = yaml_scalar(m.group(2))
                    if RUSSIAN.search(s):
                        out.setdefault(owner, {}).setdefault(s, "%s:%d" % (os.path.relpath(path, ROOT), n))
    return out


def wanted():
    """{lang file dir: {phrase: where}}: every phrase and the folder whose lang/ holds it."""
    out = {"core": code_phrases()}
    for owner, phrases in content_phrases().items():
        out.setdefault(owner, {})
        for k, v in phrases.items():
            out[owner].setdefault(k, v)
    return out


def lang_path(owner, code):
    return os.path.join(CONTENT, owner, "lang", code + ".yaml")


def quote(s):
    return json.dumps(s, ensure_ascii=False)


def read_lang(path):
    """{key: phrase} of a lang file written by this tool (one `"key": "value"` a line)."""
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = re.match(r'^("(?:[^"\\]|\\.)*")\s*:\s*("(?:[^"\\]|\\.)*")\s*$', line)
            if not m:
                raise ValueError("%s:%d: expected \"key\": \"phrase\"" % (os.path.relpath(path, ROOT), n))
            out[json.loads(m.group(1))] = json.loads(m.group(2))
    return out


def write_lang(path, phrases, keep):
    """Writes `phrases` ({key: where}) with the translations in `keep`, grouped by file."""
    by_file = {}
    for k, where in phrases.items():
        by_file.setdefault(where.rsplit(":", 1)[0], []).append(k)
    lines = ["# Phrases of the game in this language (src/shared/content/lang.gd); written by",
             "# tools/lang_check.py --write: fill the empty ones, keep %s %d in their order."]
    for f in sorted(by_file):
        lines.append("")
        lines.append("# " + f)
        for k in by_file[f]:
            lines.append("%s: %s" % (quote(k), quote(keep.get(k, ""))))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def formats(s):
    return [f for f in FORMAT.findall(s) if f != "%%"]


def main(argv):
    want = wanted()
    if "--missing" in argv:
        code = argv[argv.index("--missing") + 1]
        out = {}
        for owner, phrases in want.items():
            have = read_lang(lang_path(owner, code))
            for k, where in phrases.items():
                if not have.get(k):
                    out[k] = os.path.relpath(lang_path(owner, code), ROOT)
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0
    if "--write" in argv:
        code = argv[argv.index("--write") + 1]
        for owner, phrases in want.items():
            path = lang_path(owner, code)
            write_lang(path, phrases, read_lang(path))
        return 0
    strict = argv[argv.index("--strict") + 1] if "--strict" in argv else None
    bad = 0
    for g in glued():
        print("glued, not a line: " + g)
        bad += 1
    total = sum(len(p) for p in want.values())
    for code in LANGS:
        if code == SOURCE:
            continue
        lacks = 0
        files = 0
        for owner, phrases in want.items():
            path = lang_path(owner, code)
            try:
                have = read_lang(path)
            except ValueError as e:
                print(e)
                bad += 1
                continue
            files += os.path.exists(path)
            for k, v in have.items():
                if v and formats(k) != formats(v):
                    print("%s: %s keeps not the template's %s: %s" % (os.path.relpath(path, ROOT), quote(k),
                                                                       " ".join(formats(k)), quote(v)))
                    bad += 1
            lacks += sum(1 for k in phrases if not have.get(k))
        if files:
            print("%s: %d of %d phrases" % (code, total - lacks, total))
            if code == strict and lacks:
                bad += 1
    print("lang: %d phrases, %d problems" % (total, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
