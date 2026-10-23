"""Writes build_info.json for the client: version, commit, date and the recent changes.

CI runs it before the web export. The version is <stage>.<PR>: the stage comes from
application/config/version in project.godot (bumped by hand when an MVP stage closes),
the PR is the last one merged into main, so "0.1.67" is the build with PR #67 in it.
A pull request build is that number plus "+pr<N>". The changes are the lines
"Что нового [вид]: ..." from the descriptions of the last merged PRs, newest first; a PR
may have several, and a line without a kind is something new (see KINDS).

    python3 tools/build_info.py [out.json]   (GITHUB_TOKEN, GITHUB_REPOSITORY, HEAD_SHA from CI)
"""

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.request

ENTRIES = 15  # PRs with a line
LINE = re.compile(r"^\s*(?:\*\*)?Что нового\s*(?:\[([^\]]*)\])?\s*:(?:\*\*)?\s*(.+?)\s*$", re.MULTILINE)
# The kind written in a line -> the kind the client draws an icon for.
KINDS = {
    "новое": "new",
    "улучшено": "better",
    "исправлено": "fix",
    "оптимизировано": "fast",
    "ядро": "inside",
    # Their first names, still read in older PRs.
    "быстрее": "fast",
    "внутри": "inside",
}


def kind(tag: str) -> str:
    tag = (tag or "").strip().lower()
    if tag and tag not in KINDS:
        print("unknown kind [%s], shown as new" % tag)
    return KINDS.get(tag, "new")


def stage() -> str:
    with open("project.godot", encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.MULTILINE)
    return m.group(1) if m else "0"


def merged_prs(repo: str, token: str) -> list:
    url = f"https://api.github.com/repos/{repo}/pulls?state=closed&base=main&sort=updated&direction=desc&per_page=100"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        prs = json.load(r)
    prs = [p for p in prs if p.get("merged_at")]
    prs.sort(key=lambda p: p["merged_at"], reverse=True)
    return prs


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "build_info.json"
    # A pull request build checks out a merge commit; HEAD_SHA names the PR's own head.
    commit = os.environ.get("HEAD_SHA", "")[:7] or subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    info = {
        "version": stage() + ".dev",
        "commit": commit,
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d"),
        "changes": [],
    }
    repo, token = os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GITHUB_TOKEN")
    if repo and token:
        prs = merged_prs(repo, token)
        if prs:
            info["version"] = "%s.%d" % (stage(), prs[0]["number"])
        shown = 0
        for p in prs:
            lines = LINE.findall(p.get("body") or "")
            for tag, text in lines:
                info["changes"].append({"pr": p["number"], "date": p["merged_at"][:10], "kind": kind(tag), "text": text})
            shown += 1 if lines else 0
            if shown == ENTRIES:
                break
        ref = os.environ.get("GITHUB_REF", "")
        m = re.match(r"refs/pull/(\d+)/", ref)
        if m:
            info["version"] += "+pr" + m.group(1)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    print("build %s (%s), %d changes" % (info["version"], commit, len(info["changes"])))


if __name__ == "__main__":
    main()
