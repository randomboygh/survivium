"""Deletes old GitHub releases (and their tags) so the Releases page stays short.

CI's `release` job runs it after a release is made. Kept: the newest KEEP releases `v<stage>.<PR>` (by
the version, stage first, then the PR number), the last release of every stage (the one that closed it),
the release marked "Latest", the release just made, and the rolling prereleases (any tag that is not
`v<stage>.<PR>`). Everything else goes, with its tag.

    python3 tools/prune_releases.py [--keep 50] [--dry-run] [--current v0.5.950]   (GH_TOKEN, GITHUB_REPOSITORY)

With --dry-run only the lists are printed. Stdlib and `gh api` only.
"""

import argparse
import json
import os
import re
import subprocess
import sys

TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def key(tag: str) -> tuple:
    return tuple(int(x) for x in TAG.match(tag).groups())


def to_delete(releases: list, keep: int, current: str = "") -> list:
    """The tags to delete from `releases` ([{tagName, isLatest}]): see the module doc."""
    tags = sorted((r["tagName"] for r in releases if TAG.match(r["tagName"])), key=key, reverse=True)
    kept = set(tags[:keep])
    closing = {}
    for t in tags:  # newest first: the first of a stage is its last release
        closing.setdefault(key(t)[:2], t)
    kept.update(closing.values())
    kept.update(r["tagName"] for r in releases if r.get("isLatest"))
    if current:
        kept.add(current)
    return [t for t in tags if t not in kept]


def gh_api(*args: str) -> str:
    return subprocess.run(["gh", "api", *args], capture_output=True, text=True, check=True).stdout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", type=int, default=50)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--current", default="")
    a = ap.parse_args()
    repo = os.environ["GITHUB_REPOSITORY"]
    # The REST API only (`gh release` goes through GraphQL, which some tokens cannot reach).
    rows = gh_api("--paginate", f"repos/{repo}/releases?per_page=100", "--jq", ".[] | [.id, .tag_name] | @tsv")
    ids = dict(reversed(line.split("\t")) for line in rows.splitlines() if line)
    latest = json.loads(gh_api(f"repos/{repo}/releases/latest"))["tag_name"]
    releases = [{"tagName": t, "isLatest": t == latest} for t in ids]
    doomed = to_delete(releases, a.keep, a.current)
    print(f"{len(releases)} releases (Latest {latest}), {len(doomed)} to delete; "
          f"kept: the {a.keep} newest, each stage's last, Latest, the current one, the rolling ones")
    failed = 0
    for t in doomed:
        print(("would delete " if a.dry_run else "deleting ") + t)
        if a.dry_run:
            continue
        try:
            gh_api("-X", "DELETE", f"repos/{repo}/releases/{ids[t]}")
            gh_api("-X", "DELETE", f"repos/{repo}/git/refs/tags/{t}")
        except subprocess.CalledProcessError as e:
            failed += 1
            print(f"could not delete {t}: {e.stderr.strip()}", file=sys.stderr)
    # A failed delete is retried by the next release; it does not fail the run.
    print(f"{failed} failed" if failed else "done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
