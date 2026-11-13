"""Writes build_info.json for the client: version, commit, date and the recent changes.

CI runs it before the web export. The version is <stage>.<PR>: the stage comes from
application/config/version in project.godot (bumped by hand when an MVP stage closes),
the PR is the one the commit merged into main (else the last one merged), so "0.1.67" is the build
of PR #67; its GitHub release is tagged v0.1.67 (tools/release_notes.py).
A pull request build is that number plus "+pr<N>". The changes are the last ENTRIES lines
"Что нового [вид]: ..." (Russian) and "What's new [kind]: ..." (English) from the descriptions of
the merged PRs, newest first; a PR may have several, and a line without a kind is something new
(see KINDS). The same change in another language is a line "What's new (de) [kind]: ..." and so on;
the n-th line of each language is the n-th change, and the client shows the game's language, else
English, else Russian ("text" is the Russian one, or the English one when there is none).

    python3 tools/build_info.py [out.json]   (GITHUB_TOKEN, GITHUB_REPOSITORY, HEAD_SHA from CI)
"""

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.request

ENTRIES = 500  # changes, the newest
PAGES = 10  # of 100 closed PRs at most, read until ENTRIES lines are found
# «Что нового» is Russian, "What's new" is English, "What's new (xx)" is the language xx.
LINE = re.compile(r"^\s*(?:\*\*)?(?:Что нового|What['’]s new(?:\s*\(([a-z]{2})\))?)\s*(?:\[([^\]]*)\])?\s*:(?:\*\*)?\s*(.+?)\s*$",
                  re.MULTILINE | re.IGNORECASE)
# The kind written in a line -> the kind the client draws an icon for.
KINDS = {
    "новое": "new",
    "улучшено": "better",
    "исправлено": "fix",
    "оптимизировано": "fast",
    "ядро": "inside",
    # The English names of the kinds.
    "new": "new",
    "improved": "better",
    "fixed": "fix",
    "optimized": "fast",
    "optimised": "fast",
    "core": "inside",
    # Their first names, still read in older PRs.
    "быстрее": "fast",
    "внутри": "inside",
}


def kind(tag: str) -> str:
    tag = (tag or "").strip().lower()
    if tag and tag not in KINDS:
        print("unknown kind [%s], shown as new" % tag)
    return KINDS.get(tag, "new")


def lines_of(body: str) -> list:
    """The changes of a PR description: [{"kind", "text", "texts": {language: text}}], the n-th
    line of every language going to the n-th change."""
    seen = {}  # language -> lines
    for m in LINE.finditer(body or ""):
        whole = m.group(0).strip().lower().lstrip("*")
        lang = "ru" if whole.startswith("что") else (m.group(1) or "en").lower()
        seen.setdefault(lang, []).append((m.group(2), m.group(3)))
    out = []
    for n in range(max((len(v) for v in seen.values()), default=0)):
        texts, tag = {}, None
        for lang in sorted(seen, key=lambda l: (l != "ru", l != "en", l)):
            if n < len(seen[lang]):
                texts[lang] = seen[lang][n][1]
                tag = seen[lang][n][0] if tag is None else tag
        out.append({"kind": kind(tag), "text": texts.get("ru") or texts.get("en") or next(iter(texts.values())),
                    "texts": texts})
    return out


def stage() -> str:
    with open("project.godot", encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.MULTILINE)
    return m.group(1) if m else "0"


def merged_prs(repo: str, token: str) -> list:
    """The PRs merged into main, the last merged first: up to PAGES pages of the closed
    ones, the last updated first, which holds the last merged."""
    prs = []
    for page in range(1, PAGES + 1):
        url = (f"https://api.github.com/repos/{repo}/pulls?state=closed&base=main&sort=updated&direction=desc"
               f"&per_page=100&page={page}")
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            got = json.load(r)
        prs += [p for p in got if p.get("merged_at")]
        if len(got) < 100 or sum(len(lines_of(p.get("body"))) for p in prs) >= ENTRIES:
            break
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
        # A build of main is the PR its commit merged (a squash merge's subject ends with "(#N)"),
        # not the last one merged by the time the job runs: the tag of its release and the APK agree.
        own = re.search(r"\(#(\d+)\)\s*$", subprocess.run(
            ["git", "log", "-1", "--format=%s"], capture_output=True, text=True).stdout)
        mine = [p for p in prs if own and p["number"] == int(own.group(1))]
        if mine and not os.environ.get("GITHUB_REF", "").startswith("refs/pull/"):
            prs = [p for p in prs if p["merged_at"] <= mine[0]["merged_at"]]
        if prs:
            info["version"] = "%s.%d" % (stage(), prs[0]["number"])
        for p in prs:
            for c in lines_of(p.get("body")):
                info["changes"].append({"pr": p["number"], "date": p["merged_at"][:10], "merged": p["merged_at"], **c})
        del info["changes"][ENTRIES:]
        ref = os.environ.get("GITHUB_REF", "")
        m = re.match(r"refs/pull/(\d+)/", ref)
        if m:
            info["version"] += "+pr" + m.group(1)
    with open(out, "w", encoding="utf-8") as f:
        # One change a line: 500 of them stay small to download.
        f.write(json.dumps({k: v for k, v in info.items() if k != "changes"}, ensure_ascii=False)[:-1])
        f.write(', "changes": [\n' + ",\n".join(json.dumps(c, ensure_ascii=False) for c in info["changes"]) + "]}\n")
    print("build %s (%s), %d changes" % (info["version"], commit, len(info["changes"])))


if __name__ == "__main__":
    main()
