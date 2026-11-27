# Full audit of the code, architecture and tests (2026-11-27)

Status: REPORT. A read-only audit of `main` at `4abe839` (after #942). Nothing in the repository was changed.
This page is the list of what needs refactoring, by importance. The evidence for every row (places in the
code, quotes, the proposed steps) is in the six area reports in [areas/](areas/): `DATA.md` (world, content,
saves), `GAME.md` (the rules in `src/shared/game/`), `NET.md` (server, protocol, security), `REND.md` (chunks,
picture, shaders), `UI.md` (main, settings, interface, input), `TEST.md` (tests, CI, tools, docs).

## How it was done and what it cannot tell

- Six reviewers read one area each (the rules, then the biggest and most central files by ranges), and each
  finding had to cite the current lines. The lead checked the Critical one and a sample of the High ones
  against the code (DATA-1, NET-1, NET-2, NET-4, UI-2) and built the dependency numbers below.
- Godot is not installed in the audit's container: **no test, bench or game was run**. Every cost claim comes from
  reading loops, not from a measurement, and every "bug" is a traced code path, not a reproduction. Each row has
  a confidence mark in its area report; rows the reviewer could not confirm say "unverified" there.
- The clone holds only the last 50 commits, so history-based claims cover about two days.
- Not read: most of `land_layout.gd`, `grass.gd`, `growth.gd`, `currents.gd`, each content YAML against the
  schema, the balance, the `_RU` docs line by line. What is already open in `OPEN_ISSUES.md` (WA-032 … WA-067)
  is not repeated here.
- `python3 tools/lint.py`, `doc_index.py --check` and `lang_check.py --strict en,ru` were run: all report 0 problems.

## The picture in short

106 findings: **1 Critical, 18 High, 53 Medium, 34 Low**.

What is in good shape and should be left alone: the layers of `src/shared/` (content → world → game, no link
back, checked by a test; the only crossing is `placed.gd` taking `Protocol.clean_text`), the server's check of
request arguments (`_fit`), the handshake and keys, the content host and the mods' download (no path
traversal found), `take_input` clamping, no mutable static state in the rules (two sessions in one process are
safe), the budgeted chunk jobs, the translation keys (0 problems), the lint and the doc index.

The debt gathers in nine themes:

| | Theme | The core of it | Main rows |
|---|---|---|---|
| A | **Saves** | One world is written and read by four hand-kept copies of the code; numbers in chunk files follow the load order of the mods with no table of their own; the format number never changed, so old-save shims cannot be retired | DATA-1, DATA-2, DATA-3, GAME-3, UI-1, DATA-5, DATA-11 |
| B | **One game, two paths** | Single player reads and writes the server's objects directly and has its own copy of the playtest switches, so a rule can work in one mode and not in the other | NET-11, UI-2, UI-5 |
| C | **Files that hold several systems** | `placed.gd` 2794 lines / 7 jobs, `chunk_streamer.gd` 1859 / 11, `plans.gd` 1784 / 3, `server.gd` 1271, `main.gd` 1212 with feature state, `settings.gd` 1286, `effects.gd` 1236, `tools/shot.gd` with one 1822-line function | GAME-1, REND-1, UI-3, UI-4, NET-9, TEST-3 |
| D | **The server against a slow or hostile client** | No backpressure, a join lock-out behind the tunnel, a full per-player update on every request, a whole-world save on every leave | NET-1 … NET-4, NET-7, NET-14 |
| E | **State kept in loose fields** | Chunk jobs, build-mode pointers, placement modes, placed things and bag slots are positional arrays or flags set around a call | REND-2, UI-6, GAME-5, GAME-9 |
| F | **Cost that grows with the base or the art** | Every tick scans all placed things per player; the tree atlas is near the 4096 limit; three shaders sit at the sampler limit | GAME-2, GAME-10, REND-4, REND-7 |
| G | **Tests and CI** | No isolation between unit tests, unseeded randomness in the rules, `progress (other)` at 93 % of its limit, 38 big scripts no test names | TEST-1, TEST-2, TEST-4, TEST-9 |
| H | **The same rule or number written twice** | 13 GDScript↔shader constant pairs, the cell index written by hand ~30 times, "is it an opening" in six variants, land rights in the request handler | REND-5, DATA-9, UI-8, GAME-7 |
| I | **Leftovers and docs** | Dead material edges, "old slope" names, two tree art paths, monolith system docs, generators that overwrite hand-edited art | DATA-12, REND-15, TEST-10, TEST-11 |

### The structure in numbers (the lead's own check)

- `src/shared/` 35.5k lines, `src/server/` 5.3k, `src/client/` 59.8k, `tests/` 24.0k, `tools/` 35.8k.
- Between layers the `preload` graph has no forbidden edge. **Inside `src/client/` there is no layering at all**:
  eight pairs of folders load each other (`view`↔`ui` 9/11, `view`↔`world` 7/12, `game`↔`ui`, `input`↔`ui`,
  `audio`↔`ui`, `game`↔`view`, root↔`ui`, root↔`view`). Most back edges are three helpers living in the wrong
  folder: `ui/ui_style.gd` (taken by 7 `view/` scripts), `ui/vibration.gd` (taken by `audio/`, `game/`),
  `ui/sound_marks.gd`. **ARCH-1 · Medium:** move those helpers to a neutral place and add the client folders'
  allowed directions to `_test_layers` (a structure change: the owner's pick).
- `main.gd` preloads 83 scripts; client modules name `game.` about 2000 times, 327 of them three deep
  (`game.player` 206, `game.hud` 180, `game.character` 174, `game.net` 121, `game.settings` 111).
- The most changed files of the last 48 PRs: `tools/shot/shots.gd` 22, `tools/shot.gd` 17, `build_mode.gd` 15,
  `plans.gd` 10, `controls.gd` 10, `placed.gd` 9, `props.gd` 9: the building work lands on the files this audit
  names as overloaded, so their split pays back first.

## The most important, in the order to do them

### 1. Stop the ways a save can be damaged (theme A): Critical and High

1. **DATA-1 (Critical).** When the order of materials differs from the saved one (an old save, a mod update that
   adds a material earlier in the order, a missing bundle), chunks are translated while read
   (`world_gen.gd:275-279`) but not marked unsaved, and the first save stamps `world.json` with the new order
   (`save_game.gd:286`, `server_store.gd:182`). On the next start the lists agree, no translation runs, and every
   chunk not edited in that session is read with the old numbers as other materials. Traced in code, not run. No
   test does translate → save → reload. Fix options (a save-format choice): the id table per chunk file; or keep
   the old list in `world.json` until a background pass has rewritten every chunk; add the missing test either way.
2. **DATA-2 (High).** Tree species, bush kinds and column biomes are saved as load-order numbers with no id list
   at all, so the same shift has no translation even on the first load; a hot-joined own mod shifts them during play.
3. **DATA-3 (High).** A world whose bundle is gone loads silently (its materials become stone) and the first save
   makes the loss permanent. Needs a refusal or a warning with a read-only start.
4. **GAME-3 + UI-1 + DATA-5 (High).** The session's state is saved and restored in four places
   (`server_store.gd`, `server_main.gd`, `save_game.gd`, `props.gd`), each with its own list of sections; the
   loaders already differ. One `Session.to_meta/from_meta` used by both is the root fix for WA-020-type losses.
   A change of who owns the save: the owner's pick.
5. With those: DATA-4 (single player overwrites an unreadable `world.json`, the server refuses), DATA-11 and
   GAME-15 (start counting the format number so shims can retire), NET-15 (a save cut midway), GAME-12 (weather
   and lying snow are not saved: intended?).

### 2. Close the server's holes that need few lines (theme D)

- **NET-2 (High):** the limit of 4 connections without a hello per address also counts 127.0.0.1
  (`server.gd:243`), and behind the tunnel every player is 127.0.0.1: four idle sockets lock everybody out. The
  fetching limit already makes the exception (`:953`). One condition and a test.
- **NET-1 (High):** no `put_packet` result is checked and a chunk is marked sent even when dropped
  (`player_link.gd:477-479`): a phone on a slow link can keep holes in the world. Needs a send budget by the
  outbound buffer.
- **NET-4 (High):** each leaving player triggers a whole-world save (`server.gd:1236`), which a player can repeat at will.
- **NET-3 (High):** every request runs a full per-player flush (`server.gd:866-870`).
- Small and safe beside them: NET-5 (ice holes lost on rejoin), NET-7 (claimed `hands` forwarded unchecked),
  NET-13 (authors dropped on a world move), NET-14 (no heartbeat), NET-16, DATA-7 (the registries' limits such as
  255 materials are not checked at runtime for a server's or an imported mod), DATA-8 (no depth or size limit in the YAML reader).

### 3. One path for single player and the server (theme B)

- **UI-2 + NET-11 (High).** The playtest switches are applied by `settings.gd` for a local world and by
  `cheats.gd` for a server: nine places for one switch. Two bugs found from it: turning cheats off never resets
  `air_temp`, `wind`, `wind_dir` (`settings.gd:1026-1028`); setting the season skips `Clock._begin_season`
  (`settings.gd:914-919`), so spring does not clear `leaf_fall` (the earlier audit's game-m1, listed as fixed).
  Route the local world through the same `CHEATS` request.
- UI-5: keys Z, X, T change season, rain and time for any single player, with no developer-mode check.

### 4. Player-visible bugs found on the way (cheap, do with the next touch)

GAME-6 (things vanish when the bag is full: a door's wreath, ground dug while building, fishing bait), REND-9
(`WindowGlow` erases while iterating), GAME-5 (a placement mode flag stays set after an error), UI-8 (one of six
"is it an opening" checks disagrees with the shared rule), NET-6 (any socket player may revive at the death spot: intended?).

### 5. Split what the building work keeps hitting (themes C and E): planned PRs, each needs the owner's pick

In the order of payback: `placed.gd` into a chain of parts with an index of things by cell (GAME-1 with GAME-2,
which also removes the per-tick scans); `chunk_streamer.gd` into jobs / nodes / view cut with a `ChunkJob` object
and a scheduler test (REND-1, REND-2, REND-3); the build mode's pointer state machine (UI-6); `plans.gd` (GAME-8);
`main.gd` state into modules and a declared build order (UI-3, UI-4); `server.gd` (NET-9, NET-10);
`settings.gd` (UI-7); `tools/shot.gd` (TEST-3).

### 6. Tests and CI (theme G)

TEST-1 first (split `progress (other)` by measured cost before it times out for good), then TEST-2 (reset of
shared static state between test files; temporary mods out of `res://content/`), TEST-4 (seedable randomness
in the rules: the root of four rows of the flaky table), TEST-8 (scene tests must fail on SCRIPT ERROR),
REND-5 (one test comparing the GDScript↔shader constants), REND-4 (a check of the tree atlas height in `validate`).

## Decisions only the owner can make

| # | Question | Options | Recommended |
|---|---|---|---|
| 1 | DATA-1/2: where the numbering of a saved chunk lives | a) an id table in every chunk file; b) keep the old list in `world.json` and rewrite all chunks in the background; c) both lists, per-kind (materials, trees, bushes, biomes) in `world.json` plus (b) | c: the smallest format change that also covers DATA-2 |
| 2 | DATA-3: a world whose bundle is missing | a) refuse to open and name the bundle; b) open read-only with a warning; c) as now | a |
| 3 | GAME-3/UI-1: one save code for single player and the server | a) `Session.to_meta/from_meta` used by both; b) keep four places and add a test that compares them | a |
| 4 | Theme C: splitting the big files | a) the chain-of-parts way already accepted (decisions 145/168), one file per PR, in the order of section 5; b) only `placed.gd` and `chunk_streamer.gd`; c) not now | a |
| 5 | ARCH-1: layering inside `src/client/` | a) move the three helpers and test the directions; b) leave | a |
| 6 | NET-6, GAME-12, UI-5: are these intended (revive at the death spot over a socket; weather not saved; Z/X/T keys for everyone in single player) | per item: keep / fix | fix all three |
| 7 | DATA-10: the test world (`test_ground.gd`, 1182 lines, 30+ non-core ids) in shared code | a) keep; b) move its layout to data of a `testing` bundle | b, later |

## The owner's answers (2026-11-27, 19:43-19:45 MSK, decision cards in the thread)

All as recommended:

1. DATA-1/DATA-2: the lists of materials, tree species, bush kinds and biomes live in `world.json`; chunks with old numbers are rewritten in the background before the old list is dropped.
2. DATA-3: a world whose bundle is missing is not opened; the game names the bundle and leaves the save alone.
3. GAME-3/UI-1: one save code: the session writes and reads its own state, single player and the server call it.
4. Big files: all are split, as chains of parts, one file per PR, in the order of section 5.
5. ARCH-1: layers inside `src/client/`: move `ui_style`, `vibration`, `sound_marks` to a neutral place and test the directions.
6. NET-6: reviving at the death spot over a socket is forbidden without the playtest switch.
7. GAME-12: the weather and what lies on the ground (snow, wet, puddles) are saved.
8. UI-5: keys Z, X, T work only in developer mode.
9. DATA-10: the test world moves to data of a `testing` bundle, later (not urgent).

### Second round (2026-11-27, 22:17-22:25 MSK, decision cards in the thread «Подготовить решения по остальным пунктам аудита»)

Already fixed before this round: DATA-1, DATA-2 (#945); NET-2, NET-5, NET-13, GAME-6, REND-9 (#946); NET-6, GAME-12, UI-5 (#947); DATA-3 (#948).
All as recommended except 11 (the owner picked the bigger option):

1. NET-1, NET-14: a slow client is not dropped. The server reads the outbound buffer, holds world streaming back above a high-water mark, checks `put_packet` and resends what was lost (rejoin-style resync); a dead connection is noticed within 20 s (heartbeat or `heard_at` + idle ping).
2. NET-3, NET-4: a leaving player only marks "save soon"; the autosave writes only the changed parts (dirty sections), no full save per request or per leave. Save format unchanged.
3. NET-12: split PEOPLE into rarely-changing person data and a compact move; YOU sends the bag only when it changed. Protocol version bumped. After the server fixes (1, 2).
4. UI-2, NET-11: one path for the playtest switches: single player sends the same `CHEATS` request (one switch table, `Clock.set_season`, a test that "off" restores every key). No loopback-socket CI job for now.
5. DATA-4, NET-15: keep `world.json.bak` (previous good file) and open it when `world.json` is unreadable; if there is none, do not open the world and do not touch the folder (as the server). Save cut midway made safe (chunks written beside, moved after all writes; failures counted).
6. DATA-11, GAME-15: the save format number starts counting; migrations live in one file, ordered by number; renames move into `was:` fields; old worlds always stay readable (no support window).
7. Tests and CI, in order, one PR each: TEST-1 (split `progress (other)` by measured cost + a 75 % warning), TEST-8, TEST-2, TEST-4, then TEST-5, TEST-6, TEST-9, TEST-16, NET-19 and the rest.
8. TEST-12: PRs build the PC and Android packages only with the `full` label or when export paths change; main builds all. Plus the other CI clean-ups of TEST-12 (shared prepare job, import cache, label filter, per-merge concurrency group on main).
9. REND-4, REND-7: now only the guard (error in `validate`/`view_test` when the tree atlas passes 4096); the second atlas and splitting `common.gdshaderinc` come before the next tree art (young trees).
10. More file splits go to the end of the split queue: `effects.gd` (REND-10), `character.gd` and `body.gd` (GAME-11), `land_layout.gd` row functions (DATA-17), `inventory_window` `_ready` (UI-14), the big tests (TEST-7).
11. UI-10: one key table / input-action layer AND a key-rebinding screen in the settings right away (gamepad later). Player-visible: new strings are keys en+ru, UI kit, screenshots for approval.
12. UI-12: move the remaining windows onto the UI kit one window per PR, screenshots before/after for approval; fix `kit.md` now.
13. TEST-11, REND-18: split the six monolith system docs into a short overview + pages; `_RU` copies stay full mirrors caught up by the weekly thread.
14. TEST-10: a per-bundle manifest marks `hand` art the generators refuse to overwrite; `tree_feet.py --check` in lint.
15. Small server and security fixes, all as recommended: NET-7, NET-8, NET-16, NET-17, NET-18, NET-20, DATA-7, DATA-8 (each with a test in `security_test.gd`).
16. Small code fixes, all as recommended, in ~5 PRs by theme: GAME-4, 5, 7, 9, 10, 13, 14; DATA-6, 9, 13, 15, 16; REND-5, 6, 8, 11, 12, 13, 14, 17; UI-8, 9, 11, 15, 16.
17. Clean-up, all as recommended, including renaming `old_slope*` to `slope*` (with rename maps where paths move): DATA-12, DATA-14, REND-15, REND-16, TEST-13, TEST-14, TEST-15, TEST-17, UI-13, UI-17.

## All findings

Effort: S under half a day, M one or two days, L several PRs. "Owner's pick": the fix changes structure, saves,
the protocol or what the player sees. Theme letters as in the table above. Ids lead to the area reports.

### Critical (1)

| Id | Kind | What | Where (first place) | Effort | Risk | Owner's pick | Theme |
|---|---|---|---|---|---|---|---|
| DATA-1 | Correctness | After any change of material order, the first save writes the new order into `world.json` `materials`. The chunk files that were not re-saved that session keep the old numbering. The next load reads them without a remap, so their cells become other materials. | `src/client/save_game.gd:286` | M | medium | yes | A |

### High (18)

| Id | Kind | What | Where (first place) | Effort | Risk | Owner's pick | Theme |
|---|---|---|---|---|---|---|---|
| DATA-2 | Data | Saves keep the tree species, bush type and column biome as load-order *indices*, with no id table and no remap. Unlike materials, they have no `materials`-style list at all. | `src/shared/world/world_cells.gd:961` | M | medium |  | A |
| DATA-3 | Correctness | A world whose bundle is no longer installed loads without any warning. The first save then permanently rewrites `mods`, `known` and `materials` without that bundle, so restoring the mod later cannot bring the world back. | `src/shared/content/mods.gd:189-204` | M | low |  | A |
| GAME-1 | Size | `placed.gd` is a god object: 2794 lines (115 KB), 156 functions, 15 `is_*` predicates. It holds at least seven separate jobs behind one API that 58 files use (414 references outside it). | `src/shared/game/placed.gd` | M | low |  | C |
| GAME-2 | Performance | every player, every tick, the rules scan all placed things linearly several times. There is no index by cell or by chunk. Fence posts are placed things, so a base with hundreds of fences makes each scan hundreds of dictionary and `Items.get_item` lookups, at up to 60 ticks a second. In single player this runs inside the… | `character.gd:390-391` | M | medium |  | F |
| GAME-3 | Architecture | the session's world state is saved and loaded in four places, each with its own hand-written list of sections and its own load order. `Session` itself has no `to_meta`/`from_meta`. | `src/server/server_store.gd:187-196` | M | medium | yes | A |
| NET-1 | Correctness | The server has no backpressure toward slow clients. It ignores every `put_packet` result. A chunk counts as "sent" even when its frame was dropped, so a client on a slow link silently loses deltas and chunks and its copies drift for good. | `src/server/server.gd:304-306` | M | medium |  | D |
| NET-2 | Security | Anyone can block new players from joining by holding a few silent connections open. The per-address limit on connections without a hello also applies to `127.0.0.1`, so behind the Cloudflare tunnel, where every connection comes from that address, 4 idle sockets refused every 10 s shut out all newcomers. Without a tunnel, 16… | `src/server/server.gd:61-64` | S | low | yes | D |
| NET-3 | Performance | Every request message triggers a full `PlayerLink.flush()` for its sender, on top of the per-frame flush. Flush does work that grows with the zone and with the world: a full ring scan of the zone, the `_sent` sweep, and `Territory.used()` over all claims. A client may send 300 messages a second (`MSG_RATE`), so a player can… | `src/server/server.gd:866-870` | M | low |  | D |
| NET-4 | Performance | Every player who leaves (lingering ended, kick, a goodbye on their own land) triggers a whole world save. Any player can repeat this by reconnecting with their key and sending BYE while standing on their own land (linger 0). Independently, the 10 s autosave serialises the whole `world.json` (every placed thing with chest… | `src/server/server.gd:1230-1236` | M | medium |  | D |
| REND-1 | Architecture | `chunk_streamer.gd` is a god object with eleven distinct responsibilities. It has about 80 member vars and touches 28 distinct `game.*` members. | `src/client/world/chunk_streamer.gd:118-299` | L | medium | yes | C |
| REND-2 | Correctness | The chunk job is a hidden state machine. It is spread over about 17 fields with sentinel values, and a positional 9-element `stashed` array saves and restores it. | `chunk_streamer.gd:190-236` | M | medium |  | E |
| UI-1 | Duplication | Single player writes and restores the world's save with its own client code. That code is a hand copy of the server's `ServerStore` and `server_main` code, key by key. | `src/client/save_game.gd:275-309` | M | medium | yes | A |
| UI-2 | Duplication / Correctness | The playtest switches ("Тестирование") take effect by two separate code paths, and two bugs have come out of that split: | `src/client/settings.gd:693-766` | M | low |  | B |
| UI-3 | Architecture / Size | `main.gd` (1212 lines) holds a lot of feature state and per-frame game logic, which breaks its rule: "only builds the scene and runs the frame; new state goes into its module". |  | M | medium | yes | C |
| UI-4 | Coupling | Every client module gets the whole Main node as `game` and reaches through it deeply. That couples all 85 files to Main's field names and to an implicit build order. | `main.gd:306-400` | L | medium |  | C |
| TEST-1 | CI | The progress test is split into two "halves" that are far from equal. `progress (other)` is the critical path of every main run and is close to its hard limit. | `tests/progress_test.gd:51` | S | low |  | G |
| TEST-2 | Tests | The unit runner has no isolation between tests. All 31 files run in one process and share the static state of `Content`, `Mods`, `Lang`, `Settings` and `PixelView`. Each test changes that state and restores it by hand at the end of the function. A runtime error aborts the function before the restore runs, so the changed… | `tests/run_tests.gd:38-55` | M | low |  | G |
| TEST-3 | Size / Coupling | `tools/shot.gd` is a 3,010-line SceneTree script whose `_run()` is one function of 1,822 lines. It reads 311 distinct option keys of a shot and reaches into 56 private fields of the client modules. Together with the shot registry it is the biggest merge hotspot in the repo. | `tools/shot.gd:139-1960` | M | low |  | C |

### Medium (53)

| Id | Kind | What | Where (first place) | Effort | Risk | Owner's pick | Theme |
|---|---|---|---|---|---|---|---|
| DATA-4 | Correctness | If `world.json` is unreadable or has another format, single player starts the world anew and later overwrites `world.json`. The server refuses to start in the same case. Two behaviours for one file. | `src/client/save_game.gd:122-126` | S | low |  | A |
| DATA-5 | Duplication | `world.json` is composed in two places, and "open a saved world" is written three times. | `src/client/save_game.gd:279-299` | M | low |  | A |
| DATA-6 | Architecture | Content-derived caches are invalidated by three different mechanisms, and several callers set `Content.BUNDLES` and call `Content.refresh()` around `Mods`. | `src/shared/content/mods.gd:104-118` | M | medium |  | E |
| DATA-7 | Security | The registries' engine checks never run at runtime. A server's mods, a zip import or a phone's override folder can load more than 255 materials, or a set without `core:air` first, and corrupt the byte-sized cells. | `src/shared/content/materials.gd:250-265` | S | low |  | D |
| DATA-8 | Security | The hand-written YAML reader has no nesting or size limit, recurses for every nested flow or block level, and parses files a server sends. | `src/shared/content/yaml.gd:155-205` | S | low |  | D |
| DATA-9 | Coupling | The cell index layout `(y << 8) / (z & MASK) << SHIFT / (x & MASK)` is written out by hand about 30 times in 6 files, though `LAYER`/`SHIFT`/`MASK` exist. The `natural` and `shapes` bytes also pack bits by hand (`& 15`, bits 4..7). | `src/shared/world/world_cells.gd:345,355,386,433,442,457,477,568,594` | S | low |  | H |
| DATA-10 | Architecture | `test_ground.gd` (1182 lines, 45 functions) is a shipped feature in shared code: the «Тестирование» world, and the server's `--seed -1`. It hard-codes 30+ ids of non-core mods, against the "ids only core's" rule. | `src/shared/world/test_ground.gd:148-158` | M | low | yes | C |
| DATA-11 | Data | Save migrations are scattered, with two version numbers and rename tables in code, though the data-driven `was` field already exists. | `world_store.gd:20` | L | medium | yes | A |
| GAME-4 | Coupling | the contract for the `who` a rule acts on is implicit. The shared base `character.gd` does not declare methods that rules call. They exist only in two subclasses with different implementations. Callers sometimes guard with `has_method` and sometimes do not. | `src/server/player.gd:210-245` | S | low |  | E |
| GAME-5 | Correctness | placement search switches modes by setting instance fields around a call and clearing them after. If a runtime error happens inside, the field stays set for good, and later real placements see the blueprint's ghost blocks as solid. | `placed.gd:1939-1943` | M | medium |  | E |
| GAME-6 | Correctness | items silently vanish when the bag is full. Several rules call `who.give(...)` or `inventory.add(...)` and ignore what did not fit. A give-or-drop helper exists, but only privately in `workshop.gd`. | `placed.gd:1808` | S | low |  | H |
| GAME-7 | Layering | some land-rights checks live in the request handler, not in the rule. Reach is checked by four different helpers. | `requests.gd:254-261` | S | low |  | H |
| GAME-8 | Size | `plans.gd` (1784 lines, 78 functions) holds three systems: the blueprint (shapes, draw, replace, earthwork, build), ghost things, and the farming mode's marks. Farm marks are stored in the same `cells` dictionary as blueprint cells and told apart by string tests. | `plans.gd:1089` | M | medium |  | C |
| GAME-9 | Data | the two central records are untyped and positional. A placed thing is a Dictionary with about 15 optional keys whose meaning depends on the item's flags. A bag slot is a positional Array whose 6th field means either sign text or dye id. A third tuple shape exists for crafting materials. | `placed.gd:183-191` | M | low |  | E |
| GAME-10 | Performance | some session "things" steps go over the whole world's records every 0.5 to 1 s, not only those near players. | `session.gd:266-285` | M | medium |  | F |
| GAME-11 | Size | `character.gd` (1080 lines) and `body.gd` (1014) each mix several concerns, and each has one very long function. | `character.gd` | M | low |  | C |
| NET-5 | Correctness | `PlayerLink.rejoin()` resets the "send again" flags one by one and forgets `_holes`. A player who reconnects to a character that is still in the world (a page reload, another device) never gets the ice holes until the ice changes again. The deeper cause: the list of what a new connection needs is duplicated between the field… | `src/server/player_link.gd:74` | S | low |  | D |
| NET-6 | Security | Any player over a socket may come back to life where they died, next to their death sack, instead of at a respawn point. The game's own client offers this only with the playtest switch `revive_at_death`. | `src/server/requests.gd:472-478` | S | low | yes | B |
| NET-7 | Security | What a player holds, as their own client claims it, is forwarded unchecked to every other player nearby. PEOPLE carries the raw `hands` from INPUT, not the checked `in_hands()`. A crafted client can show itself holding any item, including a light the others' clients render, and push arbitrarily long strings, up to the 256 KB… | `src/server/player.gd:113` | S | low |  | D |
| NET-8 | Coupling | Who may run a command is decided in four places that must agree, and the roles are recomputed with several SHA-256 hashes on every message. | `src/server/server.gd:95-102` | S | low |  | D |
| NET-9 | Architecture | `server.gd` (1271 lines) is a god object. It holds the transport, the handshake and its limits, access lists and roles, the admin commands, chat routing, mod hosting and hot reload, the security log, account lifecycle and bots, and the event broadcast. | `src/server/server.gd` | L | medium | yes | C |
| NET-10 | Size | The protocol is dispatched by long string `match` statements, and adding a request or event means editing 5-8 places by hand, with nothing checking they agree. | `src/server/requests.gd:176-495` | M | low |  | C |
| NET-11 | Architecture | Single player (the in-process loop) and a socket run different code for the same game. The loop link turns off world sending, move checks and pacing; the client reads and writes the server's own objects directly; and the playtest switches are applied by two separate implementations. | `src/client/net/local_host.gd:104-110` | M | medium | yes | B |
| NET-12 | Performance | Snapshots resend fields that never change. A PEOPLE entry is 20 fields, including the player's name, looks dictionary, worn gear and gear dyes, and the whole entry goes again whenever any field changes, which means every 50 ms while the player walks. YOU resends the whole inventory and character state on any bag change. | `src/server/player_link.gd:517-524` | M | medium |  | D |
| NET-13 | Correctness | When the server moves to another world, it carries hosts, bans and the whitelist over but drops the authors, and the merged lists are never written into the new world's `access.json`. | `src/server/server_main.gd:251` | S | low |  | A |
| NET-14 | Robustness | Dead connections are not detected. Neither the server nor the client sets a WebSocket heartbeat or an idle timeout after the hello. A phone that drops off the network leaves a half-open connection: its character stays "online" and never starts its LINGER countdown, and events pile up toward the 4 MB buffer until the OS TCP… | `src/server/server.gd:247-252` | S | low |  | D |
| REND-3 | Layering | Build-mode UI state lives in the streamer and the mesher: the floor cut from the building-UX PRs (user's picks of 2026-11-26/27) and the blueprint holes. A getter that runs every frame writes to it. | `chunk_streamer.gd:256-271` | M | low |  | C |
| REND-4 | Performance | The tree-picture atlas is 4096 wide and grows downward without any guard. By my estimate it is already at about 94% of a 4096 texture height. | `src/client/world/tree_sprites.gd:28` | S | low |  | F |
| REND-5 | Duplication | At least 13 pairs of magic numbers or encodings are copied between GDScript and the shaders, each kept in sync only by a comment. No test compares them. |  | S | low |  | H |
| REND-6 | Duplication | `tree.gdshader` and `tree_shadow.gdshader` repeat the same instance decoding block, even though both already include `tree_pictures.gdshaderinc`. | `shaders/tree.gdshader:358-400` | S | low |  | H |
| REND-7 | Performance | Three shaders have no texture-unit headroom left and one has no varying headroom. Part of the cause is that `common.gdshaderinc` declares 10 global samplers, so every shader that includes it starts at 10 of 13. | `shaders/common.gdshaderinc:88,117,120,123,130,134,137,807,900,901` | M | medium |  | F |
| REND-8 | Performance | Animals have one ShaderMaterial per species × tint × view × frame (×2 for fish), and swap `material_override` on every frame change. The species "look" is a 13-slot positional Array. | `src/client/game/creatures.gd:260-305` | M | medium |  | E |
| REND-9 | Correctness | `WindowGlow.update` can erase from `windows` while iterating over it. | `src/client/view/window_glow.gd:86-91` | S | low |  | E |
| REND-10 | Size | `effects.gd` (1236 lines) holds about eight unrelated effects, and its sub-modules call its private helpers. | `src/client/view/effects.gd` | M | low |  | C |
| REND-11 | Coupling | Rendering modules reach into other modules' internals through `game.*` chains and private fields, and the felling animation is started as a side effect of re-meshing. | `chunk_streamer.gd:1086,1158,1174` | M | low |  | C |
| REND-12 | Performance | The mesher's hot path is untyped and allocates Arrays per face. | `chunk_mesher.gd` | M | low |  | F |
| REND-13 | Performance | Turning the camera refits the culling box of every shown node in one frame, twice per turn. It is not budgeted and `frame_test` does not cover it. | `chunk_streamer.gd:1321-1329` | S | low |  | F |
| REND-17 | Tests | Several risky parts of the picture and the streamer have no automated check. | `tests/frame_test.gd` | M | low |  | G |
| UI-5 | Correctness | The playtest keys Z (next season), X (rain on/off) and T (time ×100) work for every player in single player. They are not gated by developer mode (`Settings.testing_unlocked`) or `may_cheat()`, and the docs do not mention them. | `src/client/input/controls.gd:213-224` | S | low |  | B |
| UI-6 | Architecture | Build mode's pointer handling is a state machine kept in untyped Dictionaries of six shapes, plus four ad-hoc timers. The recent building-UX PRs keep adding special branches and flags to it. | `src/client/input/build_mode.gd:604-708` | M | medium |  | E |
| UI-7 | Size / Architecture | `settings.gd` (1286 lines) mixes five jobs, and `apply()` pushes every setting into about 15 modules on each change. | `src/client/settings.gd` | M | low |  | C |
| UI-8 | Duplication | The rule for "which items are wall openings" (door, window, hatch, gate) is written out inline six times in the client, in four different variants. One of them disagrees with the shared rule. | `src/shared/game/placed.gd:1920-1922` | S | low |  | H |
| UI-9 | Tests | The biggest screens have no direct test. The scene tests that do reach them depend on private fields. | `tests/unit/ui_test.gd` | M | low |  | G |
| UI-10 | Architecture | There is no input-action layer. Keys are hard-coded physical keycodes spread over about 16 files, the game keys are split between two handlers, and there is no gamepad path. | `src/client/input/controls.gd:164-254` | M | low | yes | H |
| TEST-4 | Tests (determinism) | The game's rules draw from unseeded or global random generators, so tests can't make them deterministic. Most `Wildlife` instances in tests are unseeded. This is the root cause of four rows in the flaky table. | `src/shared/game/wildlife_base.gd:294` | M | low |  | G |
| TEST-5 | Tests / CI (timing) | Unit and scene tests contain wall-clock and frame-count assertions, and the `tests` CI job runs the three timing-sensitive checks in parallel on one 2-core runner. | `tests/unit/security_test.gd:300-305` | S | low |  | G |
| TEST-6 | Duplication (test fixtures) | Test fakes and fixtures are copied across files, and the main fake of the one acting is a hand-written duck type that has already drifted from the real `character.gd`. | `tests/unit/test_case.gd` | M | low |  | G |
| TEST-7 | Size (tests) | Several test files and functions are too large to navigate, and `view_test` is a grab-bag rather than a topic. |  | M | low |  | C |
| TEST-8 | Tests (failure detection) | Only `run_tests.gd` counts SCRIPT ERRORs (its `ScriptErrors` Logger). The four scene tests do not: a runtime error in them still exits 0 if no `_check` failed. If the error lands in the awaited `_run`, `quit()` is never reached and the run hangs until the `timeout`. | `tests/run_tests.gd:11-31` | S | low |  | G |
| TEST-9 | Tests (coverage map) | 108 scripts in `src/` are over 300 lines and 38 of them are named by no file under `tests/` (the list with line counts is in the area report). |  | M | low |  | G |
| TEST-10 | Tooling (generated assets) | About 25k lines of art generators and the sound synth write committed binaries. The generators overwrite hand edits, nothing checks that a binary is up to date with its source, and for the largest binaries the source is not in the repo. | `tools/art/*.gd` | M | low |  | I |
| TEST-11 | Docs | The biggest system docs are single-heading monoliths, which contradicts the reading rules in CLAUDE.md and INDEX.md. Their Russian copies have drifted to a fraction of their size. |  | M | low |  | I |
| TEST-12 | CI (cost and triggers) | Steps are duplicated across jobs. A PR always builds the PC and Android packages, which nothing on the PR uses. Any label re-runs the whole workflow. On main, the concurrency group can drop a merge's pending run. | `build.yml:198-205` | S | low |  | G |

### Low (34)

| Id | Kind | What | Where (first place) | Effort | Risk | Owner's pick | Theme |
|---|---|---|---|---|---|---|---|
| DATA-12 | Dead code | The material fields `edge`/`edge_size` and `Mat.edge_mode`/`edge_size`/`EDGE_*` are computed but never read. The comment itself says "Nothing draws them since … 2026-11-20". | `src/shared/content/materials.gd:92-100, 142-144` | S | low |  | I |
| DATA-13 | Tests | The generator's determinism depends on the engine's `hash()` of Variants, and no golden fingerprint test pins it across engine upgrades. | `src/shared/world/world_gen.gd:435` | S | low |  | G |
| DATA-14 | Tooling | `tools/content_report.gd` mixes Russian labels with raw lang keys, so the generated docs print literal keys. The generated docs are also Russian-only, against the "docs in English" rule. | `tools/content_report.gd:34-42` | S | low |  | I |
| DATA-15 | Duplication | The registry list is repeated (see DATA-6). | `tools/validate.gd:39-48,83-92` | S | low |  | H |
| DATA-16 | Performance | The material remap of a saved chunk walks every cell in one call (16·16·48 = 12 288 iterations) at job start. That is chunk-sized work in one frame, against the per-frame rule. | `src/shared/world/world_gen.gd:275-279` | S | low |  | A |
| DATA-17 | Size | `land_layout.gd`'s per-row functions are still long. `_cover_row` is 239 lines and `_water_row` 179 lines. | `src/shared/world/land_layout.gd:922-1101, 1107-1346` | M | low |  | C |
| DATA-18 | Correctness | Small save-format nits (listed in the area report). |  | S | low |  | A |
| GAME-12 | Correctness | the clock's save keeps only time and season. The weather and what it leaves on the ground (snow lying, wet, puddles, clouds, the current weather and `weather_left`) are not saved. | `clock.gd:516-529` | S | low |  | A |
| GAME-13 | Coupling | `Placed` keeps content-derived tables as `static var` (`sizes`, `middles`, `seats`), and an instance method rebuilds them alongside instance tables (`footprints`, `turned`, `opened_boxes`). `opened_boxes` is never cleared on a re-read. This is the only `static var` in `src/shared/game/`. | `placed.gd:230-238` | S | low |  | E |
| GAME-14 | Tests | some risky logic has no direct unit test. |  | S | low |  | G |
| GAME-15 | Dead code | the old-save shims cannot be retired, because the save format never changes version. `WorldStore.FORMAT` has been 1 throughout, and each shim instead checks whether a field is present. | `world_store.gd:20` | S | low | yes | A |
| GAME-16 | Coupling | minor state and duplication problems. |  | S | low |  | E |
| NET-15 | Correctness | A save cut off midway can leave the world inconsistent, contrary to the docs. Chunks are moved into place before `world.json` is even written, and the final moves are file by file. A crash between them pairs new chunks or player files with an old `world.json`, so items placed or chest contents can be duplicated or lost. The… | `src/server/server_store.gd:110-117` | M | medium |  | A |
| NET-16 | Security | A malicious server can make the client allocate as much memory as it names: the client trusts the server-sent uncompressed size of a CHUNK. Some vector events are taken without a finiteness check. | `src/client/net/remote_gen.gd:60` | S | low |  | D |
| NET-17 | Security | Player records grow without limit on a public server. `NEW_PLAYERS` allows 10 new keys a minute (14,400 a day). Each joins with a fresh key, gets a `players/<hash>.json` on the next save, and is never pruned. `known_players()` parses every one of them at startup. | `src/server/server.gd:77-78` | S | low |  | A |
| NET-18 | Security | A crafted client can jump without paying stamina. The server's simulated body jumps when the claimed height rises, but stamina is charged only when the client sets its own "jumped" flag. | `src/server/player.gd:155-158` | S | low |  | D |
| NET-19 | Tests | About half of the request kinds are never sent over a socket in `security_test.gd` or `server_test.gd`. No test sends malformed args for every kind, and none covers a slow client, a rejoin getting the full state, or pending-slot exhaustion. | `tests/unit/security_test.gd` | M | low |  | G |
| NET-20 | Security | Small loose ends. (a) The host command `tp` does not clamp coordinates (any `is_valid_int`), while the playtest teleport clamps to `Cheats.MOST_FAR` 1e6. (b) `real_weather.gd` sends the server's IP to ipapi.co or ipwho.is and puts no size limit on the response body. Both are opt-in. | `src/server/server.gd:717-721` | S | low |  | D |
| REND-14 | Performance | Shader parameters are set every frame whether or not they changed. | `sky.gd` | S | low |  | F |
| REND-15 | Dead code | The names still say "old slopes" although the old slopes are now the only ones. The "slopes" world option is vestigial, and the planning docs are stale. | `old_slope_mesher.gd:1-6` | S | low | yes | I |
| REND-16 | Dead code | Two tree art paths are still alive. The leaf-cluster crowns are now only a fallback for young trees and for trunk heights that have no picture look. The "species without pictures" branch is never taken with the shipped content. | `foliage.gd:415-417` | S | low |  | I |
| REND-18 | Docs | `docs/systems/chunks.md` is not the short overview the project's rules ask for. | `docs/systems/chunks.md` | S | low |  | I |
| UI-11 | Duplication / Tooling | The content editor's `field_names.gd` is a 368-entry table that can be derived by formula and must be kept in sync with `content_schema.gd` by hand. | `src/client/ui/editor/field_names.gd:6-374` | S | low |  | H |
| UI-12 | Docs / Duplication | The kit doc says all windows use the kit, but half of the big ones still build their own frame and do their own layout. Spacing and colour literals are spread across the screens. | `docs/systems/ui/kit.md:6-7` | S | low | yes | H |
| UI-13 | Data (translation) | Translation status, and the gaps that `lang_check` does not catch. | `tools/lang_check.py` | S | low |  | I |
| UI-14 | Size | Two `_ready` functions build a whole window in one go. `hud._ready` was split for the same reason in #696. | `src/client/ui/inventory_window.gd:184-431` | S | low |  | C |
| UI-15 | Architecture | Static caches outlive scene restarts and are reset from scattered lists. A new cache must be remembered in the right list. | `src/client/main.gd:350-351` | S | low |  | E |
| UI-16 | Duplication | Each screen decides "portrait", "narrow" or "phone" by its own rule. | `ui/hud_layout.gd:57` | S | low |  | H |
| UI-17 | Data | `ui_icons.gd` (1386 lines) is already pure data, but there is a second source of UI pictures alongside it. | `src/client/ui/ui_icons.gd:9` | S | low |  | I |
| TEST-13 | Tooling (export) | The exports ship every tool script. Only `tests/*` is excluded. | `export_presets.cfg:8-10` | S | low |  | I |
| TEST-14 | Docs (stale facts) | Numbers and paths in the docs no longer match the code. |  | S | low |  | I |
| TEST-15 | Tooling (rules without a check) | Rules of CLAUDE.md that no tool checks: layering inside the client, `template % values` for player text, `FileAccess` at `Content.ROOT`, -1 as "none" for coordinates, `.connect(func` lambdas using `self`. |  | S | low |  | G |
| TEST-16 | Coupling (test base) | Every unit test file inherits ~50 preloads from `test_case.gd`, including client view scripts and a server script. A parse error in any one of them fails all 31 files as "does not load". | `tests/unit/test_case.gd:5-55` | S | low |  | G |
| TEST-17 | Docs / Code language | Two generated docs, and the generator code that writes them, are in Russian, which goes against "Code, comments … are in English". Four testing docs overlap. | `tools/content_report.gd:118` | S | low |  | I |
