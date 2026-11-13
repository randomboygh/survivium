# Tests, tools, CI, versions

Status: ACTIVE. The commands of checks before every push — in `CLAUDE.md`. How to check by levels and what to
run for which system — [../testing/TESTING_GUIDE.md](../testing/TESTING_GUIDE.md); coverage and flaky checks —
[../testing/TEST_COVERAGE.md](../testing/TEST_COVERAGE.md); the CI jobs —
[../testing/CI_PIPELINE.md](../testing/CI_PIPELINE.md). A Russian copy: [testing_RU.md](testing_RU.md).

## Tests (`tests/`)

| File | What it checks | Limit |
|---|---|---|
| `run_tests.gd` + `unit/<topic>_test.gd` | unit tests by the topics of `FILES` (generation, mesher, body, shapes, view, actions, clock, wildlife, store, content, graph, bundle_system, character, session, net, security, territory, plans, skills, quality, farming, boat, properties, balance, fences, signs, lang, mod_files, ui; a `*_test.gd` file that is not in `FILES` is a failure); each file inherits `unit/test_case.gd` (`_check` and helpers) and prints its checks and seconds; `-- topic …` runs only them; `properties` are generative: the bag under random actions and the graph of recipes on random sets from pinned seeds | 300 s |
| `save_test.gd` | plays, saves, starts again: digging, the place, the clock, things, the map, markers, the modules' parts, old saves | 300 s |
| `progress_test.gd` | a new world with an empty bag (of 24 places, as with a backpack): the path to every recipe through the game's own calls; on a failure says what cannot be got; `-- --part hunting` — only the recipes that need something got from a beast (a carcass, hides, fur, bones, fat), `-- --part other` — the rest (in `run_all.sh` — `progress_hunting` and `progress_other`, in CI — on two machines); waits go both by the clock and for no fewer than 30 frames | 1200 s per half |
| `frame_test.gd` | plays scenarios without a screen and fails if work the size of a chunk got into one frame; idle and idle by the campfire are judged by the frame's median against a share of a chunk measured right before the measuring, and print the parts of the game's frame; the timings are noisy on a busy machine — rerun alone | 600 s |
| `server_test.gd` | the scene of a headless server in the same process on port 7791 and bots through `socket.gd`: login and refusals (version, password, a full server, no hello), the login events, chunks, a request through the socket, a cut link and a return by key; the game itself enters a server (`join_url`): a world from the sent chunks, edits of cells, other players' figures with names, the server's check of movement (a jump across half the world is put back, a step — not); the goodbye, the commands who / say / kick / stop; one's own server from the menu (`LocalHost.host`: listens at once, a second on the same port — «busy», `stopped`) and the host's commands give / tp / ban / unban / whitelist; a restart of the server over a saved world — the unfinished is removed, the cell and things are the same, Anya returns by key to her character | 300 s |
| `browser_smoke.mjs` | the web build in headless Chrome as PC, as a phone (DPR 3, touches) and as an upright phone by the link `?server=` (the «Join» screen, an unsuccessful login); a machine for each; fails on SCRIPT ERROR, SHADER ERROR, Parse Error and `Invalid call/access/get/set`, prints the loading time and a snapshot | in CI |
| `run_all.sh` | `parse`, `validate`, `report` (freshness of the content reports), `run_tests`, `save_test`, `progress_hunting`, `progress_other`, `server_test` in parallel, each with its own `user://` (`XDG_DATA_HOME`), then `frame_test` alone; `GODOT=path`; names as arguments — only them (`progress_test` — the whole path in one run); `LOGS=folder` — logs there; in Actions — a table into the run's summary and `::error` | — |

The lines `ERROR: content: _test…` in the output of `run_tests` are deliberately broken data of the loader's
checks; the warnings about RID leaks at the exit of `save_test` and `progress_test` are old and harmless.

## Pitfalls of tests

- Tests of behaviour in time wait by `Time.get_ticks_msec`, not by frames: in CI the frames are very fast. A
  frame's flag counted before the state's update is stale in that frame.
- Wrap a headless run in `timeout`: an error in a script with `await` leaves Godot hanging.
- `--check-only --script res://x.gd` only parses the script.
- `tools/shot.gd` and `tools/profile.gd` write `user://settings.cfg`; the scene tests read their own
  `user://test_settings.cfg` (`Settings.path`, deleted at the start of a test), `server_test` —
  `user://test_server.cfg` (`Config.file`), so the tools no longer change what the tests play.
- A runtime error of a script cuts off only its own function, and the test goes on without the checks after
  it: `run_tests.gd` counts each such error as a failure (its own `Logger`), `run_all.sh` fails a check
  whose log has `SCRIPT ERROR`.

## Tools (`tools/`)

- `lint.py` — seconds, no Godot: no `class_name`, autoloads, plugins; trailing spaces, CRLF, the end of a
  file, conflict markers; the paths `load("res://…")` and of scenes' resources exist; Python compiles, shell
  — `bash -n`, `browser_smoke.mjs` — `node --check`, JSON and workflow are parsed. `parse_check.gd` —
  compiles every script (also those that no test loads) without creating objects. `hooks/pre-commit` —
  `lint.py` and `doc_index.py --check` before a commit, turned on by `git config core.hooksPath tools/hooks`.

- `validate.gd` — the check of all mods' data (in CI too): schemas, references, each bundle separately, the
  sounds' files, pictures, textures, models, the reachability of recipes, the place in the atlas; names
  against the rules it prints as warnings, without failing.
- `shot.gd` (+ `shot/shots.gd` — the table of shots, `shot/places.gd` — places and scenes) — screenshots
  without a GPU: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3
  --resolution 1280x720 --script res://tools/shot.gd -- <folder> [--phone] [names]` (slow, in the background;
  the shots share one world, a shot with an edit of cells returns them; `ground-*` — in the test world;
  `place` with a biome's name puts the player in its middle, not on the near edge, `places.inland`).
- `map.gd` — the map of the terrain round the spawn from above; `profile.gd` — the time of each module of
  the frame headless and the draw calls under xvfb (`-- spikes` — one-off actions); `bench_gen.gd`,
  `bench_mesh.gd`, `bench_edit.gd`, `bench_turn.gd` — measurements; `bench_content.gd [bundles]` — reading and
  loading the mods' data, the registries and the graph, now and with an invented mod added.
- Assets: `make_sprites.gd`, `make_models.gd`, `make_icons.gd`, `make_textures.gd` (the drawing tools in
  `art/*.gd`), `make_sounds.gd` (the bricks in `sound/synth.gd`) — make only the named ones (`-- <name> …`),
  everything at once only with `-- --all`: what was drawn by hand is overwritten too; `sheet.gd` (the player's
  sheet to PNG); Python with Pillow: `make_icon.py` (the icon and `assets/web/`; the `og:` tags of the link
  preview are in `html/head_include` of the preset `export_presets.cfg`), `make_splash.py` (the splash); both
  write the game's name from `project.godot`; `rename.py "Name"` — rename the game
  ([RENAMING.md](../RENAMING.md)), `make_creatures.py` with `creature_kit.py` (the beasts' sheets),
  `make_sparrow.py` (the sparrow), `make_birds.py` (crow, owl, duck), `make_frog.py`, `make_fish.py`,
  `make_rabbit.py`, `make_squirrel.py`, `make_fox.py`, `make_deer.py`, `make_boar.py`, `make_bear.py`,
  `make_wolf.py`, `make_cat.py`, `make_hedgehog.py`, `make_plant_art.py` (bark, plants, fruit of the new
  plants). What is drawn can be corrected by hand.
- `build_info.py` — the version and «What's new» for the build (CI); `web_patch.py` — the patch of the web
  build for sound and the phone's keyboard (CI, after export); `web_cache.py` — after it: the engine's files
  get a name by content (`engine-<hash>.*`), and the page itself (its own `fetch`) keeps the wasm in the
  browser's Cache Storage, so after a deploy a phone does not download 9 MB of engine again (a new engine — a
  new name, the old cache is deleted; the service worker of #304 is removed: because of it the page waited
  10 s, `engine.sw.js` now only deletes itself); `doc_index.py` — the index of scripts for `docs/` and the
  check of paths in documents (`uses` sees both the `.tscn` scenes and the scripts that load them);
  `content_report.gd` — reports on content from the loaded data: the registry of entities
  `docs/generated/content-index.md`, the graph `content-graph.md`, the registry of recipes
  `content-recipes.md`, what the checks found `content-checks.md` (`-- --check` — only check freshness, CI
  runs it so). `balance_report.gd` — the balance tables `docs/balance/GAME_BALANCE_TABLES.md` from the same
  data and the rules' formulas (tools, tree × axe × skill, cells, beasts, PvP, skills, stamina, price and
  term, food; `-- --check` — freshness); run it after editing tools, trees, materials, creatures, skills.

## CI (`.github/workflows/build.yml`)

The jobs go in parallel, each on its own machine: `lint` (no Godot), `checks` (parse, validate, report),
`tests` (run_tests, save_test, server_test), `progress (hunting)` and `progress (other)`, `frames`
(frame_test alone), `export` (the version, web export, the patch), `pc` (the version, the export of Windows —
`Survivium.exe` with the console wrapper `Survivium.console.exe` — and Linux — `Survivium.x86_64`; the
archives `survivium-windows.zip` and `survivium-linux.tar.gz` as artifacts), then `smoke` (Chrome as PC and as
a phone). On a PR the check in a browser goes only if the PR touches what a browser may show differently (the
template `web` in the job `changes`), or the PR has the label `smoke`; on `main` — always, and the builds are
published only when all jobs have passed: the web to Pages (`deploy`), the APK (`android`,
[android.md](android.md)) and the PC builds into the GitHub release `v<stage>.<PR>` with the changes since the last
release (`release`, `tools/release_notes.py`; the same files into the rolling prereleases `android-latest`, `pc-latest`). A new push to a PR
cancels its old run, the runs of `main` are not cancelled. The token's rights are by jobs, the actions are
pinned to a SHA, Godot is checked against `.github/actions/godot/SHA512-SUMS`; the checks' logs are the
artifacts `logs-<job>`. The export templates (web, Windows, Linux, Android) are put by `.github/actions/godot` (to the
test jobs — without them); the presets — in `export_presets.cfg` (the Windows program's icon is put in by Godot itself, no rcedit:
`application/modify_resources=true`). A frame of software WebGL takes a second and more, every input event
waits for a frame: keep the events in the smoke test few. FPS in CI means nothing. In detail —
[../testing/CI_PIPELINE.md](../testing/CI_PIPELINE.md).

## The version and «What's new»

The client's version is `<stage>.<PR>`: the stage is `application/config/version` in `project.godot` (raised
by hand when an MVP stage closes or the code is reshaped), the PR is the last one merged into `main`
(`0.1.67` contains PR #67). CI writes it with `tools/build_info.py` into `build_info.json` (not in git;
locally — `dev`) together with the last 500 changes from the descriptions of the merged PRs (up to 10 pages of 100 PRs; one
JSON line per change); the main menu («What's new») and «Testing» show the version and open them, the page
makes 40 changes at a time and loads the next ones on scrolling. Each change is written in the PR description
in two languages: a Russian line `Что нового [вид]: …` and an English one `What's new [kind]: …` (for a
player, not a programmer; the n-th line of each language is the same change), and optionally in another
language of the game: `What's new (de) [fixed]: …`. The page shows the game's language, else English, else
Russian (`SettingsMenu.change_text`, the field `texts` of a change; `text` is the Russian one). The kinds:
`новое`/`new` (the default), `улучшено`/`improved`, `исправлено`/`fixed`, `оптимизировано`/`optimized`,
`ядро`/`core` (code moved, tools, tests); a PR that does several things gives a line for each, for example
`Что нового [исправлено]: Костёр больше не гаснет под крышей.` with `What's new [fixed]: A campfire no longer
goes out under a roof.` Old PRs have only the Russian line.

**In more detail.** `plan/architecture/testing-tools.md` (the idea; the section «What there is now» — the
current).
