# Test coverage

Status: ACTIVE. What is checked by what, the goals by the systems' importance, what is checked only by hand
and which checks are flaky. How to run — [TESTING_GUIDE.md](TESTING_GUIDE.md). A Russian copy:
[TEST_COVERAGE_RU.md](TEST_COVERAGE_RU.md).

The percentage of lines is not measured: GDScript has no coverage tool in Godot 4.5 without plugins, and
plugins are forbidden in the project. Coverage is judged by scenarios: which rules and paths of the game are
checked by calls of the game itself.

## Layers of checks

| Layer | What | Where |
|---|---|---|
| Static | the scripts' rules (no `class_name`, autoloads, plugins), texts (trailing spaces, CRLF, merge conflicts), the paths `load("res://…")` and of scenes' resources, Python/shell/JS/JSON/workflow are parsed | `tools/lint.py` |
| Compilation | each of ~200 GDScript scripts compiles, also those that no test loads | `tools/parse_check.gd` |
| Documents | the paths in `docs/` exist, the code index is fresh | `tools/doc_index.py --check` |
| Data | schemas, references, each bundle separately, assets, the content graph, eras | `tools/validate.gd`, `tools/content_report.gd --check` |
| Modular | rules, the generator, meshes, data, the network — by topic | `tests/run_tests.gd` + `tests/unit/*_test.gd` |
| Generative | the bag under random actions; the graph of recipes on random sets | `tests/unit/properties_test.gd` |
| Integration | saving and loading the game, the server and clients over the network | `tests/save_test.gd`, `tests/server_test.gd` |
| System | the path from an empty bag to every recipe by the game's calls; frames in the game's scenarios | `tests/progress_test.gd`, `tests/frame_test.gd` |
| End-to-end | the web build in Chrome as PC, phone, upright phone | `tests/browser_smoke.mjs` (CI) |

## Systems, tests and goals

Importance: **К** — critical (breaks the game or saves, checked by every PR), **В** — important, **О** —
ordinary. The goal is what must be covered automatically.

| System | Importance | Tests | Goal and state |
|---|---|---|---|
| Mods, bundles, schemas, ids | К | `content_test` (17), `bundle_system_test` (4), `graph_test` (3), `properties_test` (graph), `validate`, `report` | every check of data comes with a test on broken data; there |
| The content graph, recipes, stations, eras | К | `graph_test` (the spec's dead ends on test bundles), `properties_test` (random chains against a simple fixed point), `progress_test` | reachability and cycles — yes; there |
| Crafting and stations in the game | К | `actions_test` (things on cells, stations), `content_test` (recipes), `progress_test` (every recipe by the game's calls) | every recipe is made in CI; there |
| The bag, wear, spoiling | К | `character_test` (19), `properties_test` (random additions, takings, moves, sorts, saves) | the count of things and stacks — invariants; there |
| Saving and loading | К | `store_test`, `save_test` (84 checks: digging, things, the clock, the map, old saves) | a new field of a save — a check in `save_test`; there |
| World generation | К | `generation_test` (11), `shapes_test` | determinism by seed, the world by parts equals the world at once; there |
| Protocol and server | К | `net_test`, `session_test`, `server_test` (182 checks), the layers in `content_test` | login, refusals, a cut, the check of movement, the host; there |
| Hands and the world | В | `actions_test` (13), `plans_test`, `farming_test`, `progress_test` | every action of the hands — a check; there |
| The character, strengths, skills, body | В | `character_test`, `body_test` (10), `skills_test` (5) | there |
| Balance: tools × durability × skills, beasts, PvP, stamina, the experience curve, food | В | `balance_test` (9; limits with reasons, `docs/balance/GAME_BALANCE_DESIGN.md`), the tables of `tools/balance_report.gd` | there |
| Beasts, fishing | В | `wildlife_test` (18), `progress_test` (hunting each beast with a carcass, each kind of fish) | there |
| Territories, PvP | В | `territory_test` (11), `server_test` | there |
| Chunks on screen, frame budgets | В | `mesher_test`, `frame_test` | nothing the size of a chunk in one frame; there |
| Time, weather | О | `clock_test` | there |
| The picture, shaders | О | `view_test`, `parse_check` (shaders do not compile without a GPU), screenshots by hand | by hand: see below |
| The interface | О | `ui_test` (12), `frame_test` (a part of the HUD), `browser_smoke`, `parse_check` | by hand: see below |
| Sound | О | `view_test` (sound), `validate` (the sounds' files) | the ear — by hand |

The numbers in brackets are the `_test_*` functions in the file (`grep -c "^func _test" tests/unit/<topic>_test.gd`).

## What is checked only by hand and why

| What | Why not automatically | How to check |
|---|---|---|
| How the picture looks (shaders, light, the cave slice) | CI has no GPU, the software render does not show the flicker of phone GPUs | screenshots `tools/shot.gd` under xvfb, a check on the user's phone |
| FPS and freezes on a phone | CI is 10× faster than a phone in GDScript, draws in software | the stats panel F3 and the «Freeze log» on the phone |
| Sound by ear | no ears | the demo in the library `sound/` |
| Touches on a real phone | the emulation in the smoke test is only DPR and touch events | the user |

The list «Check on a phone» is in the library, `plan/backlog.md`.

## Flaky checks

Each — with the reason and what was done. A rerun of a CI job without a fix is only for the rows of this
table and only when the message shows a failure of the machine.

| Check | What was | Reason | What was done |
|---|---|---|---|
| `frame_test`: idle and idle by the campfire | 14 failures out of 70 runs in 2 days (0.97 ms at the limit 0.81) | the limit is a share of the cost of a chunk measured at the start of the test; GitHub's machines are of two kinds (a chunk 14–17 and 21–25 ms), and a machine's speed drifts within the minutes of the test; the mean of 120 frames is shifted by one hiccup | the chunk's measure is taken right before the measuring, the frame's median is compared; the message has the parts of the game's frame. The parts showed: it is not noise — the game's code in an idle frame (~1 ms in CI: the player 0.40, animals 0.20, sky 0.12 …) had grown to 1/20 of a chunk; #347 made it 10–15 % cheaper (the search of ground, the beasts' decisions, the beasts' snapshot): on a fast machine (a chunk 14.6 ms) 0.61 at the limit 0.73, on a slow one 0.95 at 1.20 — a reserve of about 1/6; further only beasts off screen stepping less often would make it cheaper (the user's decision). 2026-11-04: idle hardly depends on the kind of machine (fast 0.92 at the limit 0.81, slow 0.97 at 1.22), and the limit did; now it is no lower than `IDLE_FLOOR` 1.25 / `NIGHT_FLOOR` 1.55 ms (#370). 2026-11-09: the night frame grew with the new things (packs hunt at night, fear of fire, boats: in CI 1.26–1.76 ms, at night the beasts 0.4–0.5 against 0.2 by day, the player 0.6 against 0.4) and failed main (1.59 and 1.76 at 1.55); `NIGHT_FLOOR` was raised to 2.0 ms. The night can be made cheaper by beasts stepping less often and by rarer slow parts of the character (warmth, spoiling, the seat), this is the user's decision |
| `frame_test`: «crafting materials:cord keeps the rest of a frame» | 2 failures | one frame over the limit at 41 frames of the scenario (the allowance is 1 per 250) | left: a rerun by the numbers; if it repeats — look at the frame of crafting a rope in the code. 2026-11-10: it repeated (main after #464 and #467: 2 and 3 frames over 9.5 ms out of 19–22). An analysis of the frames: the start of crafting (the server ~3 ms for three frames) and the frame when the rope comes into the bag and teaches a dozen recipes: the tabs of kinds in crafting were all made anew and all repainted (~1.1 ms here, ~10 ms on a phone). Now the tabs that were stay and only those that changed light are repainted (`IconTabs.set_tabs`, `ScrollColumn.set_items`): 0.25 ms. And the crafting scenarios (and at a workbench) allow one frame over the limit for every made thing (`_scenario(..., events)`): each comes into the bag and teaches recipes in one frame |
| `frame_test`: «landing in a cave», «mowing keeps the rest of a frame» | main after #559 and #568 (2026-11-13) and several PRs after it: 2 frames over 6.6–8.0 ms | the unit of the limits was the cost of the nine chunks round the spawn; #568 filled pits and hollows there, the chunks became 25–30 % cheaper and every limit fell with them, while the frames' work stayed the same (the parts of the landing frames compared before and after; the body takes no long steps there, a step costs ~80 µs as before) | the unit is now the nine chunks round `REFERENCE` in the test world, built by hand, times `REFERENCE_SCALE` 1.4 (what the spawn cost against it before): a change of the generator no longer moves the limits. 2026-11-13, after #570 it still failed main (#573, #574: 2 frames over 6.6 and 8.4 ms out of 124–138). The parts of each frame showed the two over were always the first two: the player is put into the cave from afar, and the animals round the new place, the view and the cut move at once (8–15 ms past the budgets on a 15–27 ms chunk); they took the scenario's one stall, and any other stall of the runner failed it. Those two frames are now events (`LANDING_EVENTS`) and must stay under a chunk past the budgets; the rest of the landing keeps the limit |
| `frame_test`: «idle at night by the campfire keeps the rest of a frame», «mowing keeps the rest of a frame» | #577 (2026-11-13): 2 frames of 12 ms at the limit 10; nearly every CI run had 1 over (the allowance) | the parts of each frame: the night's spike is its first frame, catching up after `_chunk_cost` held the game for half a second (the server's tick, the animals, the player), plus the scene tests' own search of the screen for untranslated keys (`Lang.keys_shown` every 500 ms from `Hud.update_state`, 3–5 ms on CI) that falls in any scenario's frames; mowing's spikes are the first swing and each thing taken up into the bag (the server's pickup 0.5–3 ms, then the bag's, skills' and knowledge's copies) | the sweep's time is counted (`Hud.swept_us`) and taken out of the frames judged; after `_chunk_cost` ten frames and 0.3 s pass unjudged (`_settle`); in mowing each thing taken up and the first swing are events, and its worst frame must stay under a chunk past the budgets. Locally the night's worst frame fell from 10–14 to 3–4 ms |
| `progress_test`: «Сундук cannot be set down at the camp» | 1 failure | the wait for rest is 4 s by the clock; on a busy machine a frame lasts seconds, and 4 s is a couple of frames | waits for both 4 s and 30 frames |
| `progress_test`: «Медведь fell, but its Туша is not on the ground» | 1 failure | the same: the carcass comes to the client through frames, they waited 3 s by the clock | waits for both 3 s and 30 frames; the message names where the beast fell and where the nearest carcass is at the client and at the host |
| `progress_test`: the limit of 1200 s | 1 failure (exit 124) | the usual run is 945 s — right at the limit | divided into two halves on two machines (see the report) |
| `progress_test --part other`: the limit of 1200 s | 1 failure (`main` after #348): 24 casts for a perch without a bite, 16 min | a fish of this kind is within the float's reach but, it seems, in other water nearby: it is lured again and again and cannot swim up; for each cast they waited 40 s | after a cast without a bite a fish of this kind at the float is removed and a new one is put in the float's water |
