# Roadmap

Status: ACTIVE. The stages and tasks are not duplicated here. A Russian copy: [ROADMAP_RU.md](ROADMAP_RU.md).

## Approved plans (the library)

- `plan/mvp.md` — the stages: stage 0 is closed, stage 1 (the MVP) is in progress; the order of work and the
  state by area. The state by area was checked on 2026-11-09 (PRs up to #457; next item 8 of decision 178 —
  the check on a phone and the playtest, closing stage 1); what is in the code now is also in
  [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md).
- `plan/backlog.md` — the only task list by area (GitHub Issues are not kept).
- The server is built (decision 153, `plan/architecture/server.md`: stages С1–С7, PR #249–#263), on it
  territory and teams (Т1–Т6, PR #317–#329, [systems/territory.md](systems/territory.md)); fire, food and
  survival — PR #307–#314 ([systems/character.md](systems/character.md)); building (decision 163, PR
  #335–#339, #371, #372) and skills (decision 164, PR #340–#342) — tasks 7 and 6 of stage 1.
- The bundle system by the spec `bundles.md` (decision 152) is built: the rules and the state of the eight
  stages — [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md), the plan of the stages with
  files and risks — `plan/architecture/bundle-system.md`.

## The technical audit of the code (stage 4, 2026-11-01)

The findings by system — [audit/CODEBASE_AUDIT.md](audit/CODEBASE_AUDIT.md), the plan of steps and what waits
for the user's decision — [planning/REFACTORING_ROADMAP.md](planning/REFACTORING_ROADMAP.md). Done (steps
1–6, PR #289–#293): what was fixed and what is left — [audit/REFACTORING_REPORT.md](audit/REFACTORING_REPORT.md),
measurements — [audit/PERFORMANCE_REPORT.md](audit/PERFORMANCE_REPORT.md).

Testing and CI (stage 5, 2026-11-03, PR #346): the audit — [audit/TESTING_CI_AUDIT.md](audit/TESTING_CI_AUDIT.md),
the plan and what is left — [planning/TESTING_CI_ROADMAP.md](planning/TESTING_CI_ROADMAP.md), the result —
[audit/TESTING_CI_REPORT.md](audit/TESTING_CI_REPORT.md). The documentation audit (stage 6, 2026-11-05):
[audit/DOCUMENTATION_AUDIT.md](audit/DOCUMENTATION_AUDIT.md), what was fixed and what is left —
[audit/DOCUMENTATION_UPDATE_REPORT.md](audit/DOCUMENTATION_UPDATE_REPORT.md).

## Technical debt and limits found by the stage 0 audit (proposals, not approved)

| # | What | Why it matters | Proposal |
|---|---|---|---|
| Т1 | The material atlas was full: 13 materials + 8 barks = 21 of 21 | any new material or own bark in a bundle failed the validator | done (step 2 of the content filling): the mesh holds the material's number, not the tile's (6 bits, the sides' tile is a flag bit, the underside's by the normal), the atlas is 16×12 tiles, 63 materials and barks |
| Т2 | The roles are closed lists of the schema (`items.tool`, `items.prop`, `plants.kind`, `materials.role`, `biomes.where`) | a new kind of station, tool, plant needs code | decided (no. 152): `prop` and `tool` are open classes with the stations' flags (stage 5а of the bundle system, PR #243), a recipe's tool classes — `tools` (5б); the other roles are closed |
| Т3 | Conversions of old saves (the marks `content`, `OLD_MATERIALS`) in the client's `save_game.gd` | the server will need them | done (stage С1 of the server): `WorldStore.materials_of`, `CONTENT` |
| Т4 | A world's set of bundles is fixed, a new bundle in an old world — only by a conversion entry | new bundles will not appear in existing worlds | decided (no. 152): supplementing bundles enter old worlds — stage 7 of the bundle system |
| Т5 | The beasts' voices are synthesised by a table in `tools/make_sounds.gd` | a bundle brings no recipe of a voice, only `.wav` | leave as is or move the sounds' recipes into the bundle's data |
| Т6 | Weather, the calendar, the generator's noises and relief are code constants | a mod does not change them | in the MVP plan «kinds of weather as data»; the generator — later |
| Т7 | The layers inside `src/shared/` (content → world → game) are not checked by a test | an accidental backward reference passes CI | done: `_test_layers` checks the layers inside too (stage 2 of the bundle system) |
| Т8 | real weather (the device's HTTP service lay in the shared folder) | a doubtful place for a server | decided (no. 153, 168) and done (2026-11-05): `src/server/real_weather.gd`, started by the server (`--real-weather`, «Real weather outside» in «Create a server») and by the server inside the game (`LocalHost`) |
| Т9 | Big files: on 2026-11-05 `world_actions.gd` (1672 lines), `main_menu.gd` (1523), `content.gd` (1490), `hud.gd` (1397) were split by topic (decision 168, like 145): chains of parts of 130–500 lines, the calling code did not change ([systems/interaction.md](systems/interaction.md), [systems/content.md](systems/content.md), [systems/ui.md](systems/ui.md)); `ui_style.gd` (1315), `land_layout.gd` (1190), `wildlife.gd` (1184), `main.gd` (1182) stay whole | decision 145 left them whole | done for the four biggest; split the rest if they grow, the same way |
| Т10 | No test runs the interface on a real screen or the Android APK on a device (the interface has `tests/unit/ui_test.gd`, the server is checked by `tests/server_test.gd`, CI builds the PC builds and the APK) | — | by the MVP plan |
| Т11 | `frame_test` in a slow container fails «idle» by 4–25 % and «idle at night by the campfire» by 30–140 % (on main too); in CI the night by the campfire failed once on a fast runner (PR #243: 0.69 ms of 0.62, the repeat — 0.45) | the check is noisy, the night one more | since PR #346 idle is judged by the share of a chunk measured beside it, since PR #370 — no stricter than `IDLE_FLOOR` 1.25 ms and `NIGHT_FLOOR` 2.0 ms (the user's choice); when in doubt — a rerun alone and CI (one repeat of the failed job), [testing/TEST_COVERAGE.md](testing/TEST_COVERAGE.md) |
