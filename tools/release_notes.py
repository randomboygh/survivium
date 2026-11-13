"""Writes the notes of a GitHub release of main: what changed since the last release.

CI's `release` job runs it on main after every job passed. The release is the version the game shows,
<stage>.<PR> (tools/build_info.py), tagged `v<stage>.<PR>` on the merged commit. Its notes are the
«What's new» lines of every pull request merged since the last release's tag (the squash merges'
subjects end with "(#N)"), grouped by kind, in English and then in Russian, with the downloads and a
link comparing the two tags. With no release before, the notes start where the stage began (the
commit that set application/config/version in project.godot).

    python3 tools/release_notes.py out.md   (GITHUB_TOKEN, GITHUB_REPOSITORY; a checkout with history and tags)

Prints `tag=…`, `version=…`, `previous=…` and `latest=true|false` for $GITHUB_OUTPUT: latest is false when a
release of a newer version is already out (main's runs are never cancelled and may finish out of order).
"""

import json
import os
import re
import subprocess
import sys
import urllib.request

import build_info

PR_OF = re.compile(r"\(#(\d+)\)\s*$")
TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
# The kinds as build_info.py names them, in the order the notes show them.
SECTIONS = [
    ("new", "New", "Новое"),
    ("better", "Improved", "Улучшено"),
    ("fix", "Fixed", "Исправлено"),
    ("fast", "Optimized", "Оптимизировано"),
    ("inside", "Core", "Ядро"),
]
LIMIT = 120000  # characters: a release body holds 125000


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()


def key(tag: str) -> tuple:
    m = TAG.match(tag)
    return tuple(int(x) for x in m.groups()) if m else (-1,)


def previous_tag(tag: str) -> str:
    """The newest release tag in the history of HEAD other than this one, or ""."""
    tags = [t for t in git("tag", "--merged", "HEAD", "--list", "v*").split() if TAG.match(t) and t != tag]
    return max(tags, key=key, default="")


def stage_start() -> str:
    """The commit that set the stage's version in project.godot, or "" when it is not in the history."""
    line = 'config/version="%s"' % build_info.stage()
    return git("log", "-1", "--format=%H", "-S", line, "--", "project.godot")


def pr_numbers(since: str) -> list:
    """The PRs merged after the commit `since` up to HEAD, the newest first; only HEAD's when since is ""."""
    subjects = git("log", "--format=%s", f"{since}..HEAD" if since else "-1").splitlines()
    return [int(m.group(1)) for m in map(PR_OF.search, subjects) if m]


def pull(repo: str, token: str, number: int) -> dict:
    req = urllib.request.Request(f"https://api.github.com/repos/{repo}/pulls/{number}",
                                 headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def notes(repo: str, prs: list, tag: str, previous: str, version: str) -> str:
    """prs: [(number, title, changes)] the newest first, changes as build_info.lines_of gives them."""
    out = []
    for lang, head in (("en", "What's new"), ("ru", "Что нового")):
        part = []
        for kind, en, ru in SECTIONS:
            items = []
            for number, title, changes in prs:
                for c in changes:
                    if c["kind"] != kind:
                        continue
                    text = c["texts"].get(lang) or c["texts"].get("en") or c["text"]
                    items.append(f"- {text} (#{number})")
            if items:
                part.append(f"### {en if lang == 'en' else ru}\n\n" + "\n".join(items))
        silent = [f"- {title} (#{number})" for number, title, changes in prs if not changes]
        if silent and lang == "en":
            part.append("### Other pull requests\n\n" + "\n".join(silent))
        if part:
            out.append(f"## {head}\n\n" + "\n\n".join(part))
    if not out:
        out.append("## What's new\n\nNothing a player sees.")
    name = re.search(r'^config/name="([^"]+)"', open("project.godot", encoding="utf-8").read(), re.MULTILINE)
    name = name.group(1) if name else "Survivium"
    out.append(
        "## Downloads\n\n"
        f"- **Android:** `{name.lower()}-android.apk`: open it on the phone, it installs over the previous build and keeps the saves.\n"
        f"- **Windows:** `{name.lower()}-windows.zip`: unpack and run `{name}.exe`; a server is `{name}.console.exe --headless -- --server`.\n"
        f"- **Linux:** `{name.lower()}-linux.tar.gz`: `./{name}.x86_64` (a server: `--headless -- --server`).\n"
        f"- **Browser:** https://{repo.split('/')[0].lower()}.github.io/{repo.split('/')[1]}/ (always the newest build).\n\n"
        f"The newest release is always at https://github.com/{repo}/releases/latest; a file of it by a link that "
        f"does not change: https://github.com/{repo}/releases/latest/download/{name.lower()}-android.apk")
    if previous:
        out.append(f"**Full changelog:** https://github.com/{repo}/compare/{previous}...{tag}")
    body = "\n\n".join(out) + "\n"
    if len(body) > LIMIT:
        cut = body[:LIMIT].rsplit("\n", 1)[0]
        body = cut + f"\n\n… and more: https://github.com/{repo}/compare/{previous or 'main'}...{tag}\n"
    return body


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "release_notes.md"
    repo, token = os.environ.get("GITHUB_REPOSITORY", ""), os.environ.get("GITHUB_TOKEN", "")
    head = PR_OF.search(git("log", "-1", "--format=%s"))
    if not head:
        sys.exit("HEAD is not a merged pull request (its subject has no (#N)): no release")
    version = "%s.%s" % (build_info.stage(), head.group(1))
    tag = "v" + version
    previous = previous_tag(tag)
    numbers = pr_numbers(previous or stage_start())
    prs = []
    for n in numbers:
        p = pull(repo, token, n) if repo and token else {"title": "", "body": ""}
        prs.append((n, p.get("title") or "", build_info.lines_of(p.get("body"))))
    with open(out, "w", encoding="utf-8") as f:
        f.write(notes(repo or "owner/repo", prs, tag, previous, version))
    newer = [t for t in git("tag", "--list", "v*").split() if TAG.match(t) and key(t) > key(tag)]
    print(f"tag={tag}")
    print(f"version={version}")
    print(f"previous={previous}")
    print(f"latest={'false' if newer else 'true'}")
    print(f"{len(prs)} pull requests since {previous or 'the stage began'}", file=sys.stderr)


if __name__ == "__main__":
    main()
