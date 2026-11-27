"""The pictures and sounds made or finished by hand, which the art generators of tools/ leave as they are.

A bundle names them in its bundle.yaml, a mod in its mod.yaml (the files of a mod of one bundle and of a mod's own
folders), each as a path inside that folder; assets/hand.yaml names those of assets/ the same way:

    hand: [models/grave.png]

A file named so is the one the game shows: it is changed by hand, or its name is taken out of the list to let its
generator write it again. `marked(path)` says whether a file is named so, `kept(path)` also prints that it is left
as it is, and `save(img, path)` saves a PIL picture unless it is. The GDScript generators ask tools/hand_art.gd,
which reads the same lists.
"""
import os
import re

ROOT = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
_read = {}


def _names(manifest):
    """The paths a manifest's top-level `hand` lists (a flow list or a block list), read once."""
    if manifest in _read:
        return _read[manifest]
    out = set()
    try:
        with open(os.path.join(ROOT, manifest), encoding="utf-8") as f:
            lines = [line.split("#", 1)[0].rstrip() for line in f.read().splitlines()]
    except OSError:
        lines = []
    for i, line in enumerate(lines):
        m = re.match(r"hand:\s*(.*)$", line)
        if not m:
            continue
        rest = m.group(1).strip()
        if rest.startswith("["):
            out = {x.strip().strip("\"'") for x in rest.strip("[]").split(",") if x.strip()}
        else:
            for item in lines[i + 1:]:
                m = re.match(r"\s+-\s*(.+)$", item)
                if m:
                    out.add(m.group(1).strip().strip("\"'"))
                elif item.strip():
                    break
        break
    _read[manifest] = out
    return out


def _manifest_of(rel):
    """The manifest that names the file `rel` (a path in the repository) and its folder, or None."""
    parts = rel.split("/")
    if parts[0] == "content" and len(parts) >= 3:
        if len(parts) >= 4 and os.path.exists(os.path.join(ROOT, "content", parts[1], parts[2], "bundle.yaml")):
            return "content/%s/%s/bundle.yaml" % (parts[1], parts[2]), "content/%s/%s/" % (parts[1], parts[2])
        return "content/%s/mod.yaml" % parts[1], "content/%s/" % parts[1]
    if parts[0] == "assets" and len(parts) >= 2:
        return "assets/hand.yaml", "assets/"
    return None


def marked(path):
    """Whether `path` (absolute, or relative to the working folder) is named as made by hand."""
    rel = os.path.relpath(os.path.realpath(path), ROOT).replace(os.sep, "/")
    at = _manifest_of(rel)
    return at is not None and rel[len(at[1]):] in _names(at[0])


def kept(path):
    """True, after saying so, when `path` is made by hand: the generator leaves it as it is."""
    if not marked(path):
        return False
    print("kept, made by hand: %s" % path)
    return True


def save(img, path, **options):
    """Saves the PIL picture `img` at `path` unless the file there is made by hand."""
    if not kept(path):
        img.save(path, **options)
