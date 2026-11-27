"""Tells whether every file changed between two commits of main is documentation, for CI.

A merge into main that changes only docs builds nothing (the PR's run already checked them): no tests,
no builds, no release, no deploy; `lint` still runs. Docs are `docs/`, a Markdown file at the root and
the PR template; none of them goes into a build (export_presets.cfg exports no Markdown).

    python3 tools/docs_only.py <head>          files since the release marked "Latest" (the `changes` job)
    python3 tools/docs_only.py <base> <head>   files from base to head (the `deploy` job: are the merges
                                               after this build all docs, so this build is still the newest)

Prints `true` or `false` (GH_TOKEN, GITHUB_REPOSITORY; REST only). Anything unclear is `false`: head not
ahead of base, no files, a compare of 300 files or more (GitHub cuts the list there), an API error.
"""

import json
import os
import re
import subprocess
import sys

DOCS = re.compile(r"^(docs/|[^/]+\.md$|\.github/pull_request_template\.md$)")
MAX_FILES = 300  # a compare lists at most this many files


def docs_only(status: str, files: list) -> bool:
    return status == "ahead" and 0 < len(files) < MAX_FILES and all(DOCS.match(f) for f in files)


def gh_api(path: str) -> dict:
    out = subprocess.run(["gh", "api", path], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def main(args: list) -> int:
    if len(args) not in (1, 2):
        print(__doc__, file=sys.stderr)
        return 2
    repo = os.environ["GITHUB_REPOSITORY"]
    try:
        base = args[0] if len(args) == 2 else gh_api(f"repos/{repo}/releases/latest")["tag_name"]
        head = args[-1]
        cmp = gh_api(f"repos/{repo}/compare/{base}...{head}")
    except (subprocess.CalledProcessError, KeyError, ValueError) as e:
        print(f"docs_only: {e}", file=sys.stderr)
        print("false")
        return 0
    files = [f["filename"] for f in cmp.get("files", [])]
    result = docs_only(cmp.get("status", ""), files)
    print(f"{base}...{head}: {cmp.get('status')}, {len(files)} files, docs only: {result}", file=sys.stderr)
    print("true" if result else "false")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
