#!/usr/bin/env python3
"""Report on the order of the Claude project's library (never deletes or moves anything).

Usage: python3 tools/library_check.py [root]     (default root: /mnt/project-files)

Checks: the top level; survivium-builds sections and README rows; planning/ leftovers and stale files;
old files in uploads/hearth/; a `Статус`/`Status` line in the first 5 lines of every plan/**/*.md.
Exit code 1 when something is reported. Not a CI check (the library is not in the repo).
"""
import os
import re
import sys
import time

TOP = {"README.md", "plan", "planning", "survivium-builds", "uploads", "android-key"}
DAY = 86400


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files"
    if not os.path.isdir(root):
        print("library_check: no library at %s, nothing to check" % root)
        return 0
    now = time.time()
    out = []

    for name in sorted(os.listdir(root)):
        if name not in TOP:
            out.append("top level: unexpected `%s` (allowed: %s)" % (name, ", ".join(sorted(TOP))))
    for name in sorted(TOP):
        if not os.path.exists(os.path.join(root, name)):
            out.append("top level: `%s` is missing" % name)

    builds = os.path.join(root, "survivium-builds")
    readme = os.path.join(builds, "README.md")
    if os.path.isfile(readme):
        text = open(readme, encoding="utf-8").read()
        sections = set(re.findall(r"^\| \[`([^`/]+)/`\]\(#", text, re.M))
        allrows = set(re.findall(r"^\| `([^`|]+/)` \|", text, re.M))
        # a row `<section>/` covers the whole section; a row `<section>/<topic>/<sub>/` counts for its topic
        whole = {r.split("/")[0] for r in allrows if r.count("/") == 1}
        rows = {"/".join(r.split("/")[:2]) + "/" for r in allrows if r.count("/") >= 2}
        dirs = {d for d in os.listdir(builds) if os.path.isdir(os.path.join(builds, d))}
        for d in sorted(dirs - sections):
            out.append("survivium-builds: folder `%s/` is not a section of the README table" % d)
        for s in sorted(sections - dirs):
            out.append("survivium-builds: section `%s/` of the table has no folder" % s)
        have = set()
        for s in sorted(dirs & sections):
            for t in sorted(os.listdir(os.path.join(builds, s))):
                if os.path.isdir(os.path.join(builds, s, t)):
                    have.add("%s/%s/" % (s, t))
        for h in sorted(h for h in have - rows if h.split("/")[0] not in whole):
            out.append("survivium-builds: `%s` has no README row" % h)
        for r in sorted(rows - have):
            if r.split("/")[0] in sections:
                out.append("survivium-builds: README row `%s` names a missing folder" % r)
    else:
        out.append("survivium-builds: README.md is missing")
    for dp, dn, fn in os.walk(builds):
        for d in dn:
            if d == "__pycache__":
                out.append("survivium-builds: %s" % os.path.relpath(os.path.join(dp, d), root))
        for f in fn:
            if f.endswith(".pyc"):
                out.append("survivium-builds: %s" % os.path.relpath(os.path.join(dp, f), root))

    planning = os.path.join(root, "planning")
    for dp, dn, fn in os.walk(planning):
        for f in fn:
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, root)
            if f.endswith("-body.md") or f.endswith(".patch"):
                out.append("planning: `%s` is a PR text or a patch (not kept in the library)" % rel)
            age = (now - os.path.getmtime(path)) / DAY
            if age >= 14:
                out.append("planning: `%s` not changed for %d days: is the task closed?" % (rel, age))

    up = os.path.join(root, "uploads", "hearth")
    if os.path.isdir(up):
        old = [f for f in os.listdir(up)
               if os.path.isfile(os.path.join(up, f)) and now - os.path.getmtime(os.path.join(up, f)) > 7 * DAY]
        if old:
            out.append("uploads/hearth: %d files older than 7 days" % len(old))

    for dp, dn, fn in os.walk(os.path.join(root, "plan")):
        for f in sorted(fn):
            if not f.endswith(".md"):
                continue
            path = os.path.join(dp, f)
            with open(path, encoding="utf-8", errors="replace") as fh:
                head = [next(fh, "") for _ in range(5)]
            if not any("Статус" in l or "Status" in l for l in head):
                out.append("plan: `%s` has no `Статус` line in its first 5 lines" % os.path.relpath(path, root))

    for line in out:
        print(line)
    print("library_check: %d finding(s)" % len(out))
    return 1 if out else 0


if __name__ == "__main__":
    sys.exit(main())
