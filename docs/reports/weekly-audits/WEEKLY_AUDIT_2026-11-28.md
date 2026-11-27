# Weekly audit 2026-11-28

A manual run of the weekly audit (the Friday 2026-11-27 18:19 Moscow run was missed), made by the rules of the owner's
`weekly_audit.md` in the narrowed form: the changes since the previous audit and a re-check of
[OPEN_ISSUES.md](OPEN_ISSUES.md). History, not instructions: the paths and line numbers are those of the day.

## A. General information

| | |
|---|---|
| Date | 2026-11-28 (Moscow time; the work began 2026-11-27 22:59 UTC) |
| Commit | `e78f09f` on main, «Saves: one save code in Session…» (#958) |
| Previous audit | [2026-11-14](WEEKLY_AUDIT_2026-11-14.md), `b35d371` (#576); no audit ran between |
| Period | 2026-11-14 → 2026-11-28; `b35d371..e78f09f` is 378 commits (#577–#958), 2038 files, +130 899 / −16 300 lines |
| Method | Read-only. **Godot is not installed in this container: no headless test, bench or game was run.** Run: `tools/lint.py`, `tools/doc_index.py --check`, `tools/lang_check.py --strict en,ru` (all 0 problems); GitHub runs of main; the code diff read. |
| Full audit | The week also had the [full audit of 2026-11-27](../../audit/full-audit-2026-11-27/AUDIT.md) (`4abe839`, #942): the whole code, 106 findings. It is not repeated here. The 378 commits are therefore covered as follows: up to `4abe839` by that audit, and `4abe839..e78f09f` (#943–#958, 16 commits) read here in the diff. |

## B. Overall state

The project is in a stable state. Main's runs for #945–#955 are green (one docs-only run, #951, was cancelled by the next push); the runs for #956 and #958 were still going when this was written. Of the last 60 finished main runs (2026-11-26 13:21 → 2026-11-27 22:37 UTC) 54 passed, 3 failed and 3 were cancelled; the three failures (#908, #909 and a build-mode change) were fixed forward by the next runs.

| | Critical | High | Medium | Low | All |
|---|---|---|---|---|---|
| Found by this audit | 0 | 0 | 1 | 0 | 1 |
| Closed | 0 | 0 | 1 | 1 | 2 |
| Left open | 0 | 0 | 5 | 5 | 10 |

## C. Changes since the previous audit, and what was read

`4abe839..e78f09f`, read in the diff against CLAUDE.md's rules (layers, `who`, requests, content as data, translation keys, main.gd):

- **Saves (#945, #948, #958).** One save code: `Session.to_saved`, `Session.read_clock`, `Session.from_saved`, used by single player (`save_game.gd`) and the server (`server_store.gd`, `server_main.gd`); a world with a missing bundle is not opened (`Mods.missing`), also on `renew`. Layers hold (`src/shared/` loads nothing from client or server; `save_game.gd` loads `Session`, a shared script). The load order of the parts is kept as the server had it, the teams and fights only on a server (`SERVER_PARTS`), single player merges its part over what a server wrote (WA-020 stays fixed). No problem found.
- **Server and rules (#946, #947).** Pending sockets: one address is limited to 4 except the tunnel's own, and past 16 the oldest is put out (`_oldest_pending`); the WebSocket handshake has its own 3 s (`HANDSHAKE_WAIT`); revive at the place of death only with playtest switches or in one's own game (`_revive_at`, `paced`); `authors` kept across `renew`. No problem found; the 3 s handshake is a small risk on a very slow link (section H).
- **Trap far from players (#955).** New `trap_days`, `step_far_traps`: **WA-068** (below).
- **Wildlife (#957).** Fish count lives on the water (`_water_share`, `FISH_WATER_CHUNKS`): the walk is 64 columns a chunk, once per populated chunk; reads correct; not run.
- **Shores, water (#956), trunks and stumps (#944).** Mesher and body code read for index bounds (`deep_shore`, `deep_diag` guard `i + dy`, `i - dy` on the padded array) and for the 14-varyings rule (no shader varying added; `water.gdshader` +10 lines, no new varying); not run, so the look and cost on a phone are unchecked.
- **CI and tools (#951, #954).** `docs_only.py` skips the build for a docs-only merge, `prune_releases.py` prunes releases, `progress` is split in three parts. #954 says «progress (metal)» still has to be added to the ruleset's required checks (owner action, see WA-039).
- **Docs, library, art sources (#943, #949, #950, #952, #953).** `doc_index --check` and `lint` pass; `tools/art/` has `.gdignore`; `hand` marks checked by lint.

## D. Problems found

| ID | Priority | Area | Description | Status |
|---|---|---|---|---|
| WA-068 | Medium | Game rules | A baited trap far from every player catches nothing once its chunk has been forgotten (`far_catch_chance` reads the biome of a loaded chunk only) | Open |

Details are in [OPEN_ISSUES.md](OPEN_ISSUES.md#wa-068--medium--game-rules).

## E. Fixes made

None. WA-068 is small, but it is in a feature merged hours ago, the audit container cannot run the tests, and the owner asked for no commit without a go-ahead: a plan, not a fix.

## F. Re-check of the open issues

| ID | Result |
|---|---|
| WA-044 | **Closed**: no queued run is left in GitHub Actions |
| WA-065 | **Closed**: the phone list was gone through by the owner on 2026-11-10; `plan/backlog.md` closed it on 2026-11-16 |
| WA-046 | **Narrowed**: `LICENSE`, `LICENSE-ASSETS`, `LICENSING.md`, `THIRD_PARTY.md` now exist; left is the pinned Python versions |
| WA-039 | Still open, owner action (strict "up to date" setting); 3 failed of 60 main runs in 33 h, all fixed forward; «progress (metal)» to be added to the required checks |
| WA-032, WA-034, WA-061 | Still open; need a phone or a Godot run; no commit in the period reaches them |
| WA-047, WA-053, WA-066, WA-067 | Not re-run (need Godot); the cited files are unchanged by `4abe839..e78f09f` except as listed above |
| OPEN_ISSUES table | The header said 12 open (5 + 7) but 11 were listed; now 10 (5 + 5) after the above |

## G. Problems left open

10: 0 Critical, 0 High, 5 Medium (WA-032, WA-034, WA-039, WA-061, WA-068), 5 Low (WA-046, WA-047, WA-053, WA-066, WA-067). See [OPEN_ISSUES.md](OPEN_ISSUES.md). The full audit's own queue is in its report.

## H. Risks of the next week

- The audit-fix queue touches saves, `placed.gd`, `chunk_streamer.gd`, `main.gd` and `server.gd`: each PR needs `save_test`, `net session`, `server_test` on CI.
- `HANDSHAKE_WAIT` 3 s: a client on a very slow mobile link that needs more than 3 s from the accepted socket to the upgrade request is put out; the client's retry should cover it, not tested.
- The release pruning (#951) deletes tags and releases: watch the first runs.

## I. Final assessment

Nothing Critical or High. The one new finding is functional and harmless. The audit could not run any test; the green CI of main is the evidence for what the diff does, not this audit.

## Areas not fully checked, and why

No Godot here: tests, benches, the validator, `frame_test` and the game were not run. `4abe839..e78f09f` was read in the code, the rest of `b35d371..4abe839` only through the full audit. Rendering and shader changes were read, not seen.

## Git state at the end

Branch `claude/project-thread-3grsoj` from `e78f09f`; the changes of this audit (this report, INDEX, OPEN_ISSUES and their `_RU` copies) are in the working tree, not committed.
