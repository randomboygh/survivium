# TEST: tests, CI, tools, repo hygiene, the docs system

**What I read.** Read in full: `tests/run_tests.gd`, `tests/unit/test_case.gd`, `tests/run_all.sh`,
`.github/workflows/build.yml`, `.github/workflows/playtest.yml`, `.github/actions/godot/*`,
`.github/pull_request_template.md`, `docs/CONTRIBUTOR_RULES.md`, `docs/testing/TEST_COVERAGE.md` (the flaky table),
`docs/audit/TESTING_CI_AUDIT.md` §2–3 and `docs/planning/TESTING_CI_ROADMAP.md`. Read the headers and the relevant
ranges of: `frame_test.gd`, `save_test.gd`, `server_test.gd`, `progress_test.gd`, `tools/shot.gd` (the outline and
`_run`), `tools/shot/shots.gd`, `tools/lint.py`, `tools/lang_check.py`, `tools/doc_index.py`, `tools/web_patch.py`,
`tools/make_sprites.gd`, `make_models.gd`, `make_sounds.gd`, the `make_*.py` headers, `tools/tree_feet.py`, `export_presets.cfg`,
`src/shared/content/content_mods.gd` (the scan) and about ten unit test files (by grep, plus the fixture ranges).
I also wrote scripts to measure function lengths, to map test coverage by path, and to find the docs that are
Russian only or have drifted. I pulled CI data through `gh api`: the job durations of 7 main runs and 1 PR run, and the
outcomes of the last 100 runs (the log artifacts could not be downloaded because the proxy blocked them).

**Checks I ran.** `python3 tools/lint.py`: "4317 files, 0 problems" (0.9 s). `python3 tools/doc_index.py --check`:
"docs OK". `python3 tools/lang_check.py --strict en,ru`: "3502 phrases, 0 problems" (ru 3502/3502; es, pt, fr, de, it,
pl, tr and uk have 2318/3502 each).

**Limits.** The clone is shallow (50 commits, 2026-11-26..27), so the git history only shows hotspots over those 48 PRs.
Godot is not installed, so nothing was run and I have no per-file test times.

---

### TEST-1 · High · CI
- **What:** The progress test is split into two "halves" that are far from equal. `progress (other)` is the critical path
  of every main run and is close to its hard limit.
- **Where:** `tests/progress_test.gd:51` (`const PARTS := ["hunting", "other"]`), `:192` (the split is "needs a beast or
  not"); `tests/run_all.sh` `limit[progress_other]=1500`; `.github/workflows/build.yml:139-167` (`timeout-minutes: 30`).
- **Evidence:** Job times from `gh api` for the last 6 successful main runs:
  - `progress (other)` took 987, 750, 772, 1393, 911 and 1293 s.
  - `progress (hunting)` took 174, 152, 124, 157, 171 and 174 s over the same runs.
  - 1393 s is 93 % of the 1500 s limit.
  - In run 46021558407 the step itself took 889 s, against a wall time of 17 min 16 s for the whole run.
  - In the last 100 runs, `progress (other)` failed main twice: 45884726797 and 45062959187.

  `TEST_COVERAGE.md`'s flaky table already says "if the usual run grows past ~1000 s, split the way further". That point
  has been reached.
- **Why it matters:** Every main run waits ~15–23 min for one machine while the other half idles after 2–3 min. The next
  content PR, or a slow runner (×1.3–1.45 according to the flaky table), pushes it over 1500 s and main goes red with
  a timeout that says nothing.
- **Proposed refactoring:**
  1. Split by measured cost, not by "beast or not": give `PARTS` 3–4 names, chosen so the recipe trips balance (the
     test can print each trip's time).
  2. Or let the matrix take `part: [1/3, 2/3, 3/3]` with a deterministic split over the sorted list of recipes.
  3. Add a soft warning in `run_all.sh` when a check uses more than 75 % of its limit.
- **Effort:** S–M. **Risk:** low. **Confidence:** high.

### TEST-2 · High · Tests
- **What:** The unit runner has no isolation between tests. All 31 files run in one process and share the static state
  of `Content`, `Mods`, `Lang`, `Settings` and `PixelView`. Each test changes that state and restores it by hand at
  the end of the function. A runtime error aborts the function before the restore runs, so the changed state leaks
  into every later file. Temporary test mods are written into the real `res://content/` of the working tree.
- **Where:**
  - The runner: `tests/run_tests.gd:38-55` (`tests.run()` only; no setup/teardown and no reset between files).
  - Hand restores, for example:
    - `tests/unit/ui_test.gd:357-391` (`Settings.path`, `Settings.testing_unlocked`)
    - `tests/unit/content_test.gd:231-234` (`Content.strict`), `:361-376` (`Content._parsed`, then `Mods.rescan()`)
    - `tests/unit/mod_files_test.gd:224-264` (`Content.serve(...)` … `Content.serve({})`, `Mods.rescan()`)
    - `tests/unit/character_test.gd:561-567` (`Lang.code`)
    - `tests/unit/view_test.gd:1103-1123` (`PixelView.up`)

    A grep finds 31 such assignments to statics in `tests/unit`.
  - Temporary mods: `content_test.gd:186-199` (`res://content/_a`, `_b`, `_c`, `_d`), `:415`, `:466`, `:511`, `:725`
    (`_h`, `_i`), `:760` (`_rbad`); `actions_test.gd:1025` and `:1099`; `bundle_system_test.gd:16`.
  - Parallel checks: `tests/run_all.sh` `batch parse validate report balance run_tests save_test progress_hunting progress_other
    server_test` runs all of these at the same time in one checkout. `.gitignore` has no `content/_*`.
- **Evidence:**
  - `CONTRIBUTOR_RULES.md:87` says "A runtime error in a test aborts only its function". That is exactly what skips
    the restore lines.
  - `content_mods.gd:138` scans the hidden `_` folders too (`_folders(true)`), so another Godot process that scans
    `content/` while run_tests has `_a`..`_rbad` on disk sees them.
  - The `_` prefix keeps those folders out of `available()`/`all_bundles()`. Whether a stray folder can change the
    output of `validate` or `report` is **unverified**. Checking it would take a run of `run_all.sh` with a sleep put
    between a `_write_file` and its `_remove`.
- **Why it matters:**
  - One failure cascades into many unrelated failures in later files, which costs time on triage of red CI.
  - Running a subset (`-- ui content`) changes the order and so what each test sees.
  - A crash leaves `content/_x/` folders in the working tree that `git add -A` would commit.
- **Proposed refactoring:**
  1. Give `test_case.gd` `before_each()`/`after_each()` hooks and make `run_tests.gd` call every `_test_*` through
     them, discovered by reflection instead of the hand-written `run()` lists.
  2. Have the runner snapshot and restore the known statics (`Content.strict/live/_parsed/served`, `Lang.code/watching`,
     `Settings.path`, `PixelView.up/box_views`) after each file, and run `Mods.rescan()` once if a file changed them.
  3. Write temporary mods under `user://` (Content already reads other roots for one's own mods, `own_mods.gd`). If
     that is not possible, at least add `content/_*/` to `.gitignore` and have the runner remove leftover `content/_*`
     folders at start.
- **Effort:** M. **Risk:** low (tests only). **Confidence:** high (the mechanism); medium (the cross-process race).

### TEST-3 · High · Size / Coupling
- **What:** `tools/shot.gd` is a 3,010-line SceneTree script whose `_run()` is one function of 1,822 lines. It reads
  311 distinct option keys of a shot and reaches into 56 private fields of the client modules. Together with the shot
  registry it is the biggest merge hotspot in the repo.
- **Where:** `tools/shot.gd:139-1960` (`func _run()`); `tools/shot/shots.gd:9-1848` (`const SHOTS`, 110 entries);
  `tools/shot/places.gd` (1,841 lines); `tests/frame_test.gd:22` (`const ShotPlaces := preload("res://tools/shot/places.gd")`)
  and `:256`.
- **Evidence:**
  - `sed -n 139,1960p tools/shot.gd | grep -o 'shot\.\(get\|has\)("…"' | sort -u` gives 311 distinct keys.
  - The private reaches include `main.controls._stroke` (×8), `main.menu._setup`/`_fill_page` (×4 each),
    `main.creatures._process`, `main.death_screen._revive`, `main.player._build` and `main.view._spin_start`.
  - In the last 48 commits, `tools/shot/shots.gd` changed in 22 and `tools/shot.gd` in 17, the top two files of the repo.
- **Why it matters:**
  - Every visual PR appends to the same function and the same dict, which feeds WA-039 (parallel PRs).
  - Any rename of a private field in `controls.gd`, `menu`, `player` or `view` breaks the tool, and only
  `parse_check` would notice, and only for the names it can resolve.
  - A frame test depends on a screenshot tool's helper.
- **Proposed refactoring:**
  1. Turn `_run`'s if-chain into a table of small "shot effects": one function per option key, or per family (clock,
     weather, settings, places, hands, build, UI), dispatched from the shot's keys.
  2. Move each effect family into its own `tools/shot/*.gd` part.
  3. Give the client modules a small public test/tool API (e.g. `controls.stroke_for_tool()`) in place of `_private`
     access.
  4. Move the shared world-finding helpers (`places.cave`, `hills`, `shore`) to `src/shared/world/test_ground.gd` or a
     `tests/support/` script that both the tests and the tools preload.
  5. Optionally, keep shots as YAML/one file per shot to cut conflicts.
- **Effort:** M–L. **Risk:** low (tool only). **Confidence:** high.

### TEST-4 · Medium · Tests (determinism)
- **What:** The game's rules draw from unseeded or global random generators, so tests can't make them deterministic.
  Most `Wildlife` instances in tests are unseeded. This is the root cause of four rows in the flaky table.
- **Where:**
  - `src/shared/game/wildlife_base.gd:294` `var rng := RandomNumberGenerator.new()` (seeded randomly by Godot).
  - Global `randf()`/`randi()` in rules: `src/shared/game/quality.gd:59`, `skill_set.gd:95` and `:131`,
    `actions_dig.gd:122`, `:139` and `:142`, `actions_fight.gd:100` and `:198`, `actions_farm.gd:174`, `placed.gd:1112`.
  - Local unseeded RNGs: `felling.gd:65`, `:84` and `:157`, `actions_gather.gd:564` and `:634`.
  - Tests: `tests/unit/wildlife_test.gd` has 19 `Wildlife.new(`, and only 3 lines set a seed.
- **Evidence:**
  - `TEST_COVERAGE.md` "Flaky checks" has 4 wildlife rows (2026-11-14, 11-15, 11-26 and 11-27). Each was fixed one at
    a time by seeding or zeroing that one instance (`life.rng.seed = 11`, `life.density = 0.0`, `lure = 10`).
  - Tests of global-`randf` rules have to assert ranges, e.g. `decay_test.gd:248`
    `_check(got >= 8 and got <= 32, "…about half the time (%d of 40)")`.
- **Why it matters:** Each new wildlife or hands test is a future flake that turns main red, and a rerun becomes the fix.
- **Proposed refactoring:**
  1. Give every rule object an `rng` it uses, with no global `randf()` in `src/shared/game/`, and let the session seed
     them.
  2. Add a `test_case.gd` helper `_life(world, seed := 1)` that always seeds.
  3. Add a lint rule that rejects bare `randf(`/`randi(` in `src/shared/game/`.

  This touches rule code (the shared layer), but not saves or the protocol.
- **Effort:** M. **Risk:** low–medium. **Confidence:** high.

### TEST-5 · Medium · Tests / CI (timing)
- **What:** Unit and scene tests contain wall-clock and frame-count assertions, and the `tests` CI job runs the three
  timing-sensitive checks in parallel on one 2-core runner.
- **Where:**
  - `tests/unit/security_test.gd:300-305`: `… and Time.get_ticks_msec() - t0 < 100, "a shape too big is not made at all"`.
  - Waits by frame count: `tests/save_test.gd:712` (`for i in 10: await process_frame`) and `:853`.
  - `.github/workflows/build.yml:126`: `run_all.sh run_tests save_test server_test`, all three in one batch, side by side.
- **Evidence:**
  - The flaky table's last row: save_test "2 of 3 local runs side by side".
  - The `tests` job failed main in 45983526852 and 45886048213, 2026-11-26/27 (`gh api`).
  - `CONTRIBUTOR_RULES.md:75` asks tests to wait by `get_ticks_msec`, not by frames.
- **Why it matters:** Load-dependent failures on main, and reruns treated as a fix.
- **Proposed refactoring:**
  1. Replace the 100 ms bound with a size/count assertion (the plan's cell count or an early-out flag).
  2. Use `_until(cond, timeout)` (already in `server_test.gd:98`) everywhere instead of N frames.
  3. Either run `save_test` and `server_test` one after the other, or give them their own jobs. Measured: the tests
     job takes 148–268 s, so it has the headroom.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-6 · Medium · Duplication (test fixtures)
- **What:** Test fakes and fixtures are copied across files, and the main fake of the one acting is a hand-written
  duck type that has already drifted from the real `character.gd`.
- **Where:**
  - Two fakes of the one acting in `tests/unit/test_case.gd`: `Survivor` (extends the real
    `src/shared/game/character.gd`, line 152, 42 uses) and `Who` (extends `RefCounted` and re-declares ~20 methods,
    line 197, 49 uses).
  - `class Builder extends "res://tests/unit/test_case.gd".Who: var placed` appears identically in
    `fences_test.gd:9` and `plans_test.gd:11`.
  - `func _with(who, id)` is identical in `actions_test.gd:1579` and `fences_test.gd:234`.
  - `class _Who` appears in both `decay_test.gd:243` and `territory_test.gd:561`.
  - `_flat()` exists in both `fences_test.gd:21` and `signs_test.gd:14`, and the same flat stone world
    (`WorldData.new(40, Vector2i(48, 48))` + `set_cell(x, 0, z, Mat.STONE)`) is written inline 34 times across
    `tests/unit`.
  - Scene tests:
    - `func _check` is re-implemented in `frame_test.gd:109`, `progress_test.gd:107`, `save_test.gd:47` and
      `server_test.gd:90`.
    - The main.tscn bootstrap (`skip_setup = true`, `low_processor_usage_mode_sleep_usec = 0`, `Settings.path`)
      appears in 4 tests and 3 tools (`frame_test.gd:96-104`, `save_test.gd:37-56`, `server_test.gd:77/268`,
      `progress_test.gd:94-102`, `tools/shot.gd:91`, `tools/profile.gd:75`, `tools/bench_turn.gd:12`).
    - `_frames`/`_wait_ms` are in `save_test.gd:79/414`, `server_test.gd:129/138`, `tools/shot.gd:2695` and
      `tools/profile.gd:480`.
- **Evidence:** The drift: `Who.lay(_kind, _data)` (test_case.gd) against `character.gd:834`
  `lay(kind, data, until := -1.0, grave := {})`. The rules also probe the one acting with `who.has_method(...)`
  (10×) and `who.get("…")` (34×) in `src/shared/`, so a fake that lacks a method silently takes another branch instead
  of failing.
- **Why it matters:** A change to the character's API is tested against a fake that does not have it, and the fixes to
  the scene bootstrap (like the low-processor sleep) have to be made in seven places.
- **Proposed refactoring:**
  1. Keep one fake: make `Who` extend `Survivor`, or drop `Who` and give `Survivor` the extra fields.
  2. Move `Builder`, `_with`, `_flat(size)` and `_placed(w)` into `test_case.gd`.
  3. Add a `tests/scene_case.gd` (extends SceneTree) with `_check`, `_frames`, `_until`, the main.tscn bootstrap and
     the script-error logger (see TEST-8), and have the 4 scene tests and `shot.gd`, `profile.gd` and `bench_turn.gd`
     extend or preload it.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### TEST-7 · Medium · Size (tests)
- **What:** Several test files and functions are too large to navigate, and `view_test` is a grab-bag rather than a
  topic.
- **Where and evidence:**
  - `tests/unit/view_test.gd`: 2,407 lines and 41 `_test_*` functions. Its fakes span camera, sound, creatures, the
    cursor, build mode, the plan ghost, tree sprites, effects and `RemoteWildlife` (`view_test.gd:5-29` preloads 25
    scripts).
  - Longest functions, from my measurement:
    - `frame_test.gd:116 _run` 871 lines
    - `net_test.gd:243 _test_requests` 418
    - `view_test.gd:207 _test_sprite_sheet` 416
    - `server_test.gd:145 _run` 326
    - `save_test.gd:675 _run` 233 and `:220 _hold_to_put` 192
    - `body_test.gd:632 _test_ground` 186
    - `content_test.gd:154 _test_mods` 155
    - `security_test.gd:102 _test_requests` 153
  - `actions_test.gd`: 1,756 lines and 28 tests.
- **Why it matters:**
  - A runtime error in a 400-line test function skips every check after it (TEST-2).
  - Failure messages don't say which sub-scenario ran.
  - These files change in most PRs (plans_test and actions_test in 9 of 48 each).
- **Proposed refactoring:**
  1. Split `view_test` by system: `camera`, `sprites`, `effects`, `sound`, `build_view`, `creatures_view`.
  2. Cut functions over ~120 lines into named sub-tests, one per scenario (each a `_test_*` the runner counts).
  3. Turn `frame_test._run`'s scenarios into a list of `{name, setup, step, events}` records.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### TEST-8 · Medium · Tests (failure detection)
- **What:** Only `run_tests.gd` counts SCRIPT ERRORs (its `ScriptErrors` Logger). The four scene tests do not: a
  runtime error in them still exits 0 if no `_check` failed. If the error lands in the awaited `_run`, `quit()` is
  never reached and the run hangs until the `timeout`.
- **Where:** The logger is only in `tests/run_tests.gd:11-31`, plus `tools/parse_check.gd:13`. The scene tests end with
  `quit(1 if failures > 0 else 0)` at `frame_test.gd:986`, `save_test.gd:907`, `server_test.gd:470` and
  `progress_test.gd:165`.
- **Evidence:** The only safety net is `run_all.sh`'s `grep -q 'SCRIPT ERROR'`. CLAUDE.md tells contributors to run
  one test by hand as `timeout 300 godot … save_test.gd 2>&1 | tail -30`, which shows exit 0 and may cut the error out
  of the 30 lines it keeps.
- **Why it matters:** False greens when run locally, which is how agents check before pushing.
- **Proposed refactoring:** Move `ScriptErrors` into the shared scene-test base (TEST-6) and count each error as a
  failure, with a watchdog that quits with 1 after N s without progress.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-9 · Medium · Tests (coverage map)
- **What:** 108 scripts in `src/` are over 300 lines, and 38 of them are named by no file under `tests/`
  (`grep -rF <path> tests/`). Many of those 38 are parts of a chain or are reached through their head. The list below
  sorts them by how they are reached.
- **(a) Reached only through the scene tests** (main.tscn in save, server, frame and progress tests), with no unit test
  of their logic:
  - The UI windows and panels:
    - `src/client/ui/ui_icons.gd` 1386
    - `src/client/ui/inventory_window.gd` 1206
    - `src/client/ui/craft_panel.gd` 930
    - `src/client/ui/host_screen.gd` 868
    - `src/client/ui/world_setup.gd` 670
    - `src/client/ui/perf_panel.gd` 548
    - `src/client/ui/editor/content_editor.gd` 520
    - `src/client/ui/build_bar.gd` 387
    - `src/client/ui/editor/voxel_editor.gd` 346
    - `src/client/ui/person_panel.gd` 344
    - `src/client/ui/gl_watch.gd` 318
  - Input: `src/client/input/controls.gd` 1374, `src/client/input/farm_mode.gd` 314.
  - Game and view: `src/client/game/props.gd` 1181, `src/client/view/death_fx.gd` 466,
    `src/client/view/shader_warmup.gd` 457, `src/client/view/tree_hits.gd` 422.
  - Saves and the server: `src/client/save_game.gd` 309, `src/server/server_main.gd` 450 (command-line parsing:
    `server_test` uses `server.gd`, not `server_main.gd`), `src/server/server_bot.gd` 326.
- **(b) Parts of a chain or a generator, tested through their head:**
  - The generator: `src/shared/world/land_layout.gd` 1902 (via `world_gen`), `src/shared/world/world_cells.gd` 1134
    (part of world_data), `src/client/world/water_mesher.gd` 772 (via chunk_mesher in `mesher_test`).
  - The hands: `src/shared/game/actions_farm.gd` 702, `actions_gather.gd` 650, `actions_boat.gd` 455,
    `actions_dig.gd` 407.
  - Wildlife: `src/shared/game/wildlife_base.gd` 621, `wildlife_move.gd` 569, `wildlife_spawn.gd` 334,
    `wildlife_fight.gd` 314.
  - Content: `src/shared/content/content_schema.gd` 802, `content_fields.gd` 426, `content_mods.gd` 411.
  - Menus and the HUD: `src/client/ui/menu_pages.gd` 589, `menu_loading.gd` 435, `hud_layout.gd` 501,
    `hud_menus.gd` 327.
- **Why it matters:** The riskiest gaps are `controls.gd`, which turns input into requests (1374 lines, only reached
  by scene tests), `props.gd`, `server_main.gd` (its argument parsing is a security surface because it reads the
  config and the port), and `save_game.gd` (the web sync after a hidden page, WA-057), which is only reached through
  `save_test`. Line coverage can't be measured (no plugins, `TEST_COVERAGE.md:7`), so this path map is the only proxy
  there is.
- **Proposed refactoring:**
  1. Add focused unit tests for `server_main` argument parsing and for `controls` (request building from a fake input).
  2. Have `tools/doc_index.py` print this map: scripts over N lines that no test references directly.
- **Effort:** M. **Risk:** low. **Confidence:** high (the list); medium (how deep the indirect coverage goes).

### TEST-10 · Medium · Tooling (generated assets)
- **What:** About 25k lines of art generators and the sound synth write committed binaries. The generators overwrite
  hand edits, nothing checks that a binary is up to date with its source, and for the largest binaries the source is
  not in the repo.
- **Where:** `tools/art/*.gd` (39 files, 24,554 lines); `tools/make_sprites.gd:1-10` and `make_models.gd` ("A picture
  painted over by hand is overwritten, so name the pictures to make"); `tools/make_sounds.gd` ("A sound replaced by
  hand is overwritten"); `tools/tree_feet.py` header ("Run it after the pictures are packed again
  (survivium-builds/trees-redraw/integration/*/src/pack_*.py)"); and the Python art scripts `make_curio_art.py`,
  `make_dye_art.py` ("Everything is written again").
- **Evidence:**
  - 932 PNGs (9.99 MB) and 146 WAVs (8.6 MB) are tracked.
  - The biggest files are `content/plants/*/tree/frames.png` (pine 555 KB, spruce 362 KB …), whose packer lives
    outside the repo.
  - `tree_feet.py --check` exists but is not called from `build.yml` or `lint.py`.
  - Three pipelines make art:
    - GDScript `tools/art` + `make_*.gd`
    - Python/PIL `make_*.py` + `creature_kit.py`
    - external pack scripts
- **Why it matters:** Nothing says which PNGs are hand-painted, so `--all` can silently destroy art. A generator that
  no longer reproduces its committed output is invisible. Contributors don't know which file is the source of truth.
- **Proposed refactoring:**
  1. Add a manifest (YAML) per bundle: `generated_by: <tool> <args>` or `hand: true`. The generators refuse to overwrite
     `hand` entries.
  2. Add `tree_feet.py --check` to the lint job.
  3. Decide (owner) whether `tools/art` stays as the source of truth or is archived once the art is hand-kept. Either
     way, record that in `PROJECT_MAP.md`.
  4. Move the tree packers into `tools/` or document them as external.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### TEST-11 · Medium · Docs
- **What:** The biggest system docs are single-heading monoliths, which contradicts the reading rules in CLAUDE.md and
  INDEX.md. Their Russian copies have drifted to a fraction of their size.
- **Where and evidence:**
  - Word count and number of headings, from `wc -w` and `grep -c '^#'`:
    - `docs/systems/character.md`: 9,018 words, 1 heading
    - `interaction.md`: 7,580 words, 1 heading (443 lines, lines up to 856 chars)
    - `chunks.md`: 5,314 words, 1 heading
    - `crafting.md`: 4,710 words, 1 heading
    - `wildlife.md`: 4,065 words, 1 heading
    - `content.md`: 3,885 words, 1 heading
  - CLAUDE.md says "`docs/systems/<x>.md` is a short overview, its pages are in `docs/systems/<x>/`; read the page …
    by `grep -n '^#'` first". `docs/INDEX.md:50` says the three largest are `network`, `ui` and `rendering`, but those
    overviews are now 324, 242 and 226 words.
  - `interaction.md` changed in 21 of the last 48 commits (rank 2 in the repo), so it is a merge hotspot.
  - The `_RU` copies:
    - `interaction_RU.md` has 1,251 words against 7,580
    - `chunks_RU.md` 491 against 5,314
    - `crafting_RU.md` 856 against 4,710
    - 15 English docs that have a `_RU` copy changed in the last 48 commits, and none of their `_RU` copies did.
  - Across `docs/`, the `_RU` copies hold 32.6k words against 145k words of live English docs.
- **Why it matters:**
  - Agents read the whole 7–9k-word file for any change, which costs context at every step.
  - Parallel PRs conflict in one paragraph.
  - The "weekly catch-up" scheme for `_RU` is not keeping up, so the Russian docs mislead.
- **Proposed refactoring:**
  1. Split the six monoliths like `network/`: a 300-word overview plus pages by topic.
  2. Decide (owner) whether the `_RU` copies are kept as full mirrors, reduced to a short Russian overview per
     system, or dropped. Mark each `_RU` page with the English commit it mirrors so drift is measurable.
- **Effort:** M–L. **Risk:** low. **Confidence:** high.

### TEST-12 · Medium · CI (cost and triggers)
- **What:** Steps are duplicated across jobs. A PR always builds the PC and Android packages, which nothing on the PR
  uses. Any label re-runs the whole workflow. On main, the concurrency group can drop a merge's pending run.
- **Where:**
  - `build.yml:198-205`, `251-258` and `307-314`: "Version and recent changes" (`build_info.py`, a GitHub API call)
    and "content_cache.gd" are repeated in `export`, `pc` and `android`.
  - The Godot action runs in 8 jobs, ~25–35 s each, with a full `--import` every time (the `.godot/` import cache is
    not cached).
  - `build.yml:21`: `types: [opened, synchronize, reopened, labeled]`.
  - `build.yml:30-32`: `group: build-${{ github.ref }}`, with `cancel-in-progress` false on main.
- **Evidence:**
  - PR run 46020408746: `pc` 61 s and `android` 72 s on a PR that changed nothing on PC or Android. The PR run takes
    ~19 runner-min; the main run ~40 runner-min.
  - Any label added (not only `full`/`smoke`) restarts and cancels the PR's run.
  - GitHub keeps one *pending* run per concurrency group. A third merge that lands while one main run is running and
    another is pending cancels the pending one, which goes against the comment "on main every merge's run goes to the
    end". Main runs cancelled in the last 100: 45911437427, 45888012807 and 45133347629. The cause of those three is
    **unverified**: they had started, so these three were probably cancelled by hand.
- **Why it matters:** CI minutes, slower feedback, and on main a merge that goes untested when merges come in a burst
  (related to WA-039 but a different mechanism).
- **Proposed refactoring:**
  1. One `prepare` job makes `build_info.json` and `content_cache.bin` as an artifact for the three export jobs.
  2. Cache `.godot/imported` keyed by a hash of `assets/**` and `content/**/*.png`.
  3. Gate `pc`/`android` on PRs behind `changes` (export paths) or the `full` label.
  4. Filter `labeled` with `if: github.event.action != 'labeled' || github.event.label.name == 'full' || github.event.label.name == 'smoke'`.
  5. On main, use `group: build-${{ github.ref }}-${{ github.sha }}`, so every merge has its own group.
- **Effort:** S–M. **Risk:** low. **Confidence:** high (duplication, labels); medium (pending-run cancellation in practice).

### TEST-13 · Low · Tooling (export)
- **What:** The exports ship every tool script. Only `tests/*` is excluded.
- **Where:** `export_presets.cfg:8-10` (also `:40-42`, `:73-75` and `:100-102`): `export_filter="all_resources"`,
  `exclude_filter="tests/*"`.
- **Evidence:** `tools/**/*.gd` is 1.31 MB of source, including `tools/art` (24.5k lines) and `shot.gd`. No `src/` or
  `scenes/` file loads `res://tools`, according to grep. The size this adds to the `.pck` after Godot's tokenisation is
  unverified: listing the files of the built `.pck` would confirm it.
- **Why it matters:** A bigger download on a phone browser, for nothing.
- **Proposed refactoring:** Set `exclude_filter="tests/*, tools/*, docs/*"` in all four presets. The browser smoke test
  confirms the result.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-14 · Low · Docs (stale facts)
- **What:** Numbers and paths in the docs no longer match the code.
- **Where and evidence:**
  - `CLAUDE.md:86`: "`content-graph.md` alone is 218 KB". It is 290,382 bytes.
  - `docs/testing/TEST_COVERAGE.md`:
    - "each of ~200 GDScript scripts": there are 369 tracked `.gd`.
    - The counts of `_test_*` functions are behind. The doc against the code: `character_test` (19) has 22,
      `generation_test` (11) 24, `actions_test` (13) 28, `wildlife_test` (18) 21, `ui_test` (12) 20, `body_test` (10)
      14, `skills_test` (5) 7.
    - `save_test` "84 checks" has 107 `_check(` calls, and `server_test` "182" has 194.
  - The `FILES` list in `docs/systems/testing.md` lacks `decay` and `editor`.
  - `CONTRIBUTOR_RULES.md:13` says the layers are checked by "`run_tests.gd` fails otherwise". The check is actually
    `content_test.gd:790 _test_layers`.
  - `docs/INDEX.md:50`: the "three largest" claim (see TEST-11).
  - `README.md:23`: "20 species of trees, shrubs and grasses … 22 kinds of beasts". The content has 21 tree, 7 bush and
    34 plant records, and 37 creature records.
  - `export_presets.cfg:120`: `version/name="0.3"`. The stage is `0.5` (`project.godot:16`). CI overwrites it
    (`build.yml:359`), so it is harmless but stale.
  - Versioning is otherwise consistent: the workflow, `build_info.py`, `release_notes.py`, the README and
    `CI_PIPELINE.md` all use `<stage>.<PR>` with stage 0.5. I found no "v0.4" left in the live docs.
- **Proposed refactoring:**
  1. Drop the hand-kept counts from the docs, or have `doc_index.py --check` compute them (it already parses the
     tests).
  2. Fix the six facts above in one docs PR.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-15 · Low · Tooling (rules without a check)
- **What:** `lint.py` enforces:
  - no `class_name`, autoloads or plugins
  - text hygiene and merge markers
  - `load("res://…")` paths
  - the shader sampler (≤13) and varying limits
  - that the Python, shell, JS, JSON and workflow files parse

  `lang_check.py` enforces `[key]` literals, Russian in code, and "glued" `%`. The layer rule is checked by a Godot
  test that matches text (`content_test.gd:790-812`), which could be a sub-second `lint.py` rule.
- **CLAUDE.md rules with no automatic check:**
  - `FileAccess` at `Content.ROOT` outside `content*.gd`.
  - -1 as "none" for world coordinates.
  - A lambda using `self` connected to a signal. There are 69 `.connect(func` in `src/`, and implicit `self` use can't
    be found by grep, so this needs a reviewer or a GDScript AST.
  - A new request goes into `Requests.PACED`, and each security fix gets a test in `security_test.gd`.
  - `main.gd` "only builds the scene". It is 1,212 lines and nothing guards its size.
  - Content is asked for by role, not by id. No literal ids such as `"tools:axe"` exist in `src/shared/game` or
    `src/server` now, according to grep, but nothing keeps it that way.
  - Nothing sounds before the first tap.
  - Shader hints and endings: no `source_color` (`shaders/grade.gdshader:8-9` uses it, but that is a canvas_item, which
    may be exempt) and `COMPAT_ALBEDO` at the end of fragment(). Nine spatial shaders (world, grass, tree, water,
    leaves, sprite, sprite_water, fire_shadow, plan_cut_mul) lack the literal token. They may be documented exceptions
    with custom light(); the rendering reviewer should confirm (**unverified**).
  - Player-facing English literals: `lang_check` flags Russian and non-key `title`s, not English text set on a Control
    (**unverified** whether any exist).
  - Global `randf()` in rules (TEST-4).
- **Proposed refactoring:** Move `_test_layers` into `lint.py`, and add cheap regex rules for `FileAccess` + `ROOT`,
  bare `randf(` in `src/shared/game`, literal content ids in `src/`, and a ceiling on `main.gd`'s line count.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-16 · Low · Coupling (test base)
- **What:** Every unit test file inherits ~50 preloads from `test_case.gd`, including client view scripts and a
  server script. A parse error in any one of them fails all 31 files as "does not load".
- **Where:** `tests/unit/test_case.gd:5-55`:
  - client scripts: `ChunkMesher`, `PixelView`, `SkyScript`, `PlayerScript`, `VoxelProps`, `Foliage`, `SpriteSheet`,
    `Figure`, `Tracks`, `ChunkStreamer`, `SoundScript`, `Music`
  - a server script: `RealWeather` from `src/server/real_weather.gd`

  The failure path is `run_tests.gd:41-44`.
- **Why it matters:** Pure-rule tests (clock, quality, skills) depend on the client compiling. The blast radius of a
  break is all files, not one.
- **Proposed refactoring:** Keep only the `src/shared` consts in `test_case.gd`, and have each file preload the
  client/server scripts it uses (view_test already does this for 25 scripts).
- **Effort:** S. **Risk:** low. **Confidence:** high.

### TEST-17 · Low · Docs / Code language
- **What:** Two generated docs, and the generator code that writes them, are in Russian, which goes against "Code,
  comments … are in English". Four testing docs overlap.
- **Where:**
  - `tools/content_report.gd:118` writes Russian prose into `docs/generated/content-checks.md` ("# Проверки контента").
  - `tools/balance_report.gd` writes `docs/balance/GAME_BALANCE_TABLES.md` ("# Таблицы баланса").
  - Russian-only docs without an English copy: `docs/specifications/BUNDLE_SYSTEM_READINESS.md`,
    `docs/balance/GAME_BALANCE_AUDIT.md`, `GAME_BALANCE_REPORT.md`, and all 11 of `docs/audit/*.md` (archived, which
    is acceptable).
  - The testing docs: `docs/systems/testing.md` (1,899 words), `docs/testing/TESTING_GUIDE.md` (1,283),
    `CI_PIPELINE.md` (1,788) and `TEST_COVERAGE.md` (3,427). How to run, the CI jobs and the flaky table are each partly
    repeated across them.
- **Proposed refactoring:**
  1. Make the report generators write English (the docs are read by grep, not by players).
  2. Merge `systems/testing.md` into `docs/testing/` as an index.
  3. Move the flaky table's long narrative rows into a dated history file, keeping one line per row.
- **Effort:** S–M. **Risk:** low. **Confidence:** high.

---

## Healthy
- **Supply-chain hygiene in CI is good.**
  - Every action is pinned by SHA with a version comment.
  - Godot and the templates are checked against SHA-512 (`.github/actions/godot/SHA512-SUMS`), and cloudflared against
    a pinned SHA-256.
  - `permissions: contents: read` is the default, with `contents: write`, `pages` and `id-token` only on
    `release`/`deploy`.
  - There is no `pull_request_target`.
  - PR and dispatch inputs reach `run:` only through `env:`: `playtest.yml:72-79` strips non-digits, and the release
    notes go through `--notes-file`.
- **Android signing is done right.** The release keystore is given only when `github.ref == 'refs/heads/main'`. Branches
  sign with a key made for the run, the key file is deleted after the export, and the APK is verified with `apksigner`.
- **The fast checks are good.**
  - `lint.py`, `doc_index.py --check` and `lang_check.py` run in about a second and catch real classes of bugs (the
    WebGL sampler and varying limits, merge markers, broken paths).
  - `parse_check.gd` compiles tools and art scripts no test loads.
  - The `run_tests` guard that fails when a `_test.gd` file is missing from `FILES` is good.
- **`run_all.sh` is solid.** It gives each check its own `XDG_DATA_HOME`, a hard `timeout`, catches `SCRIPT ERROR` in
  logs, repeats the FAIL lines at the end, and writes a summary table. Keep it as the single entry point.
- **The flaky table is a valuable engineering record.** `TEST_COVERAGE.md` "Flaky checks" gives a cause and a fix for
  each flake. Keep the practice, but cut down the prose (TEST-17).
- **`web_patch.py` fails loud.** It is fragile by nature (14 string patches on minified engine JS), but each patch
  checks the exact occurrence count and exits with an error on a mismatch, and it is idempotent. An engine upgrade
  breaks CI instead of the game. Don't rewrite it.
- **The generated docs are not a merge-conflict source in practice.** In 48 PRs, `content-graph.md`, `content-index.md`
  and `content-recipes.md` changed once each, and `code-index.md` twice. Keep them committed.
- **Repo size is modest:** `.git` is 24 MB (shallow), with 4,317 tracked files and no file over 0.6 MB.

## Not covered
- Per-file unit test times and the real CI logs: the artifact download was blocked by the proxy. The race in TEST-2
  across processes was not reproduced.
- The deep history: the clone is shallow, so I could not measure conflict rates of the generated files or `_RU` drift
  dates beyond 48 commits.
- I did not read `tests/browser_smoke.mjs` beyond its waits, `tools/profile.gd`, the `bench_*` and `map` tools, or
  most `tools/art/*` bodies, and I made no judgement of art quality.
- Whether the shader exceptions to `COMPAT_ALBEDO` and `source_color` are documented: left to the rendering reviewer.
- The `.pck` size impact of TEST-13: I did not export a build.
