# CI: how the pipeline is built

Status: ACTIVE. The file: `.github/workflows/build.yml`, the Godot setup — `.github/actions/godot/`. How to
run the same locally — [TESTING_GUIDE.md](TESTING_GUIDE.md). A Russian copy:
[CI_PIPELINE_RU.md](CI_PIPELINE_RU.md).

## When it runs

| Event | What goes |
|---|---|
| A PR (opened, a new push, reopened, a label set) | everything except, by the job `changes`: the check in a browser, if the PR does not touch what the browser shows differently (the label `smoke` turns it on); the way to every recipe (`progress`), if the PR touches neither the content nor crafting: the mods' `data/`, `bundle.yaml`, `mod.yaml`, `src/shared/content/`, the hands' `actions_*.gd`, `world_actions`, `workshop`, `placed`, `craft_queue`, `inventory`, `felling`, `fishing`, `quality`, the test itself, `run_all.sh`, `.github/` (the jobs `progress (…)` then pass at once with their steps skipped; a rule elsewhere that cuts the way shows in `main`'s run, and the first red run names the merge). The label `full` turns everything on |
| A push to `main` (a PR's merge) | everything, always: `main` is the safety net for what a PR skipped and for two PRs green apart that break together (#513 + #514); if all jobs succeed — publishing |
| By hand: Actions → Test and build → Run workflow | everything, as in `main`, with no publishing (it is only for `main`) |
| By hand: Actions → Playtest server → Run workflow | not a check: `.github/workflows/playtest.yml` runs the game's server from `main` behind a Cloudflare tunnel for the given minutes (up to 300) with bots (`--join … --bot`, `src/client/input/bot.gd`; by default the test world, 3 bots, 120 minutes, free items), the link for a phone is in the step «Link for the phone: open this step» and in the status `playtest-link`, the game finds it itself («Testing» → «Join the test server»); the world is not saved |

A new push to the same PR cancels its previous run. On `main` runs are not cancelled: every merge is checked
to the end, and a breakage does not hide behind the next merge (before, the run of a merged PR could turn out
«cancelled»).

## Jobs

All jobs go in parallel, each on its own machine (except `smoke`, which waits for the web build, and
publishing, which waits for everything). The fast ones fail first.

| Job | What it does | Time | Blocks |
|---|---|---|---|
| `lint` | `tools/lint.py` (rules of scripts and texts, Python, shell, JS, JSON, workflow), `tools/doc_index.py --check` (paths in documents, freshness of the code index) and `tools/lang_check.py --strict en,ru` (every key exists in English and Russian, there is no Russian text in the code); without Godot | ~10 s | yes |
| `checks` | `parse` (every script compiles, `tools/parse_check.gd`), `validate` (the mods' data and each bundle separately), `report` (freshness of `docs/generated/content-*.md`) | ~1 min | yes |
| `tests` | `run_tests` (unit tests), `save_test`, `server_test` side by side | ~3 min | yes |
| `progress (hunting)`, `progress (other)` | two halves of `progress_test`: recipes that need something got from a beast, and the rest — on two machines | see the report | yes |
| `frames` | `frame_test` alone on a machine (it measures frames) | ~1.5 min | yes |
| `export` | the version and «What's new» (`build_info.py`), web export, the patches `web_patch.py` and `web_cache.py`; the artifact `survivium-web` | ~1 min | yes (for the deploy) |
| `pc` | the Windows and Linux export; the artifacts `survivium-windows`, `survivium-linux` | ~1 min | yes (for publishing) |
| `android` | the Android APK (arm64), signed by the key from the secrets ([../systems/android.md](../systems/android.md)); the artifact `survivium-android` | ~2 min | yes (for publishing) |
| `smoke (desktop / phone / upright)` | the web build in headless Chrome (`tests/browser_smoke.mjs`); the phones draw the lightest preset (`?quality=0`, `Settings.use_page_quality`), the desktop the default picture | 1–4 min | yes, when it runs |
| `release` | only `main`: the GitHub release `v<stage>.<PR>` with the notes of `tools/release_notes.py` (the «What's new» lines since the last release) and the APK and PC builds; the same files into the prereleases `android-latest`, `pc-latest` ([Releases](#releases)) | seconds | — |
| `deploy` | only `main`: the web build to GitHub Pages | seconds | — |

«Blocks» here means: `release` and `deploy` wait for its success, and by the project's rule a PR is merged
only on green CI. So that GitHub itself does not let a red PR be merged, in the repository's settings
(Settings → Branches → the rule for `main` → Require status checks) mark the jobs `lint`, `checks`, `tests`,
`progress (hunting)`, `progress (other)`, `frames`, `export`, `pc`, `android`. `smoke (…)` is not put there: on a PR with
no client changes it is skipped.

## Releases

Every build of `main` that passed every job is a release on GitHub (Releases), made by the job `release`:

- **Version and tag.** The version is the one the game shows, `<stage>.<PR>` (`tools/build_info.py`): the stage
  is `application/config/version` in `project.godot`, the PR the one the commit merged (its subject ends with
  `(#N)`). It is valid semver: the stage is the minor number (raised by hand when an MVP stage closes), the PR
  the patch (it only grows). The tag is `v<stage>.<PR>` on the merged commit, the title `Survivium <version>`.
- **Notes.** `tools/release_notes.py` reads the PRs merged since the last release's tag (`git log`, so the
  checkout has the whole history and the tags) and groups their «What's new» lines by kind: New, Improved,
  Fixed, Optimized, Core; in English, then in Russian; a PR with no such line is listed by its title. Then the
  downloads and the link comparing the two tags. With no release before, the notes start where the stage
  began. A main run that failed makes no release: its changes go into the next one.
- **Files.** `survivium-android.apk`, `survivium-windows.zip`, `survivium-linux.tar.gz` (the names do not
  change, so `https://github.com/randomboygh/survivium/releases/latest/download/<file>` always gives the
  newest build). The web build is Pages.
- **Latest.** The newest version is marked "Latest"; a run finishing after a newer one (main's runs are never
  cancelled) makes its release without the mark and leaves the rolling prereleases alone.
- **Rolling prereleases.** `android-latest` and `pc-latest` keep older links working: the same files as the
  newest release, their tags moved to its commit.
- A rerun of a main run edits its release (notes and files) instead of failing.

## Results and logs

- In a job's log each check is a collapsed group «name: N s, exit code».
- The run's summary (the run's page, the Summary tab) is a table of every check: seconds, the result, the
  score line («3227 checks, 0 failed»), under it the first `FAIL:` lines of the failed ones.
- A failed check sets an annotation `::error` with the first line of the failure — seen right in the PR.
- The logs of each check are the artifact `logs-<job>` (kept 90 days by GitHub's default), even if the job
  failed.
- GitHub itself sends the email about a failure to the run's author (the account's notification settings).

## Security

- The token's default rights are read only (`contents: read`); `changes`, `export`, `pc` also read the PR
  (`pull-requests: read`), `release` writes a release and its tag (`contents: write`), `deploy` — Pages (`pages: write`,
  `id-token: write`). A PR's code gets no write rights.
- The secrets: the built-in `GITHUB_TOKEN` and the Android signing key `ANDROID_KEYSTORE`,
  `ANDROID_KEYSTORE_PASSWORD` (only the `android` job reads them; the keystore file is deleted after the export);
  none is printed.
- Third-party actions are only GitHub's `actions/*`, pinned to a commit (SHA) with the version in a comment.
  Update by replacing the SHA with the commit of the new tag (`git ls-remote https://github.com/actions/<name>`).
- Godot and the export templates are downloaded from the engine's release and checked against the SHA-512
  from `.github/actions/godot/SHA512-SUMS`; for a new Godot version two lines from the `SHA512-SUMS.txt` of
  its release are added there, otherwise the job fails with a clear error. The cache is keyed by the version
  and these sums.
- `playwright-core` for the smoke test is pinned by version (`1.48.2`), with no lock file.
- Every test writes to its own `user://` (`XDG_DATA_HOME`), the developer's saves are not touched; the tests
  call no external services (the server test listens on localhost:7791).
- Checking the code and publishing are separated: only `release` and `deploy` publish, only into `main`, only
  after all checks succeed.

## Time

Measurements before and after — [../audit/TESTING_CI_REPORT.md](../audit/TESTING_CI_REPORT.md). The longest
is the path to every recipe (`progress_test`); it is divided into two halves that go on two machines. Each job
is limited by `timeout-minutes`, each check — by its own limit in `tests/run_all.sh`.

## What to do when CI is red

1. Open the run's summary: which check and the first `FAIL:` lines.
2. Repeat the same check locally: `GODOT=~/godot/godot tests/run_all.sh <name>`.
3. `frame_test` and `progress_test` are sensitive to the machine: the failure message has numbers (the chunk's
   measure beside the measuring, the frame's parts, the places and frames of waiting). A job's rerun is
   allowed only if the numbers show a failure of the machine, not of the code; otherwise — fix the code. Every
   such case is a row in [TEST_COVERAGE.md](TEST_COVERAGE.md), the section «Flaky checks».
4. After a merge follow the run of `main` to the end (the project's rule) and fix red at once.
