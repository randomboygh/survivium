# Weekly audit 2026-11-14

The first weekly audit of the project, made by the rules of the owner's `weekly_audit.md`
(the Claude project's library). There is no weekly report before it, so it is the baseline: it
compares the code with the stage audits in [`docs/audit/`](../../audit/) (the last one, stage 7 on
security, `c8de2a17`, #377) and with the documentation debt decision 185. History, not
instructions: the paths and line numbers are those of the day.

## A. General information

| | |
|---|---|
| Date | 2026-11-14 (Moscow time; the work began 2026-11-13 22:16 UTC) |
| Commit | `b35d371` on main, «Android: the interface moves up over the keyboard…» (#576); client version 0.3.576 |
| Branch | `claude/project-thread-5ovj58` at `b35d371`; the audit's changes are in the working tree, not committed |
| Period | 2026-11-07 → 2026-11-14 (7 days), from `c8de2a17` (#377) |
| Changes checked | 284 commits, 199 pull requests (#376–#576); 2766 files changed, +97 197 / −17 094 lines: `src/` 185 files (+28 908 / −8 201), `content/` 2387 (+41 335 / −2 733, mostly new bundles and the move of the mods to `content/`), `tests/` 33, `tools/` 37, `docs/` 90, `.github/` 4, `shaders/` 17; 65 new scripts in `src/` |
| Method | Godot 4.5.1 headless: every check of CLAUDE.md, the three exports, a headless server; GitHub runs and job logs of the week; one reviewer per area (security and anti-cheat; architecture and code; client–server, game systems and saves; performance; CI, tests and dependencies; content, bundles and balance; documentation; the stage audits' open items). Each finding was checked again against the code before it entered this report. Active security tests ran only in a local copy, never against a public or playtest server |

## B. Overall state

The project is in a stable state. The three exports build, every headless check passes at `b35d371`
and again after this audit's fixes, and main's CI is green for `b35d371` (16 jobs with publishing
and Pages).

| | Critical | High | Medium | Low | All |
|---|---|---|---|---|---|
| Found | 0 | 3 | 31 | 33 | 67 |
| Fixed in this audit | 0 | 2 | 4 | 5 | 11 |
| Left open | 0 | 1 | 27 | 28 | 56 |

57 problems are new and 10 are carried from the stage audits (re-checked at `b35d371`).
No critical risk was found. Of the three High problems two are fixed (a bot account taken over by
its key, blueprints lost on load); the third, a single-player save of a hosted world that drops its
teams and player numbers (WA-020), is confirmed by reading the code and needs a plan, because it
changes what a save keeps.

## C. Changes since the previous audit

There is no previous weekly report; the changes are counted from the stage 7 audit (`c8de2a17`).

**New functions.**
- Building: the build mode with shapes, heights and a palette (#380, #385, #389, #394), slopes and
  stairs as a form of a cell (#382), flattening (#383), fences, gates, hatches and ladders (#450,
  decision 182), signs (#461–#467, #510), things that drop into place, dragging and turning them in
  the build mode (#557), set down facing the camera (#572).
- Farming (decision 169): beds, sowing, watering, the hoe and the watering can (#387, #388), crops
  (#390), saplings that grow into trees (#391, #397, #417, #424).
- The world: two-week seasons (#397), roomy caves (#534) with a way out of every pit (#568), ragged
  material edges (#532), ferns and clover (#540, #561, #564, #567), visions from glowing mushrooms
  (#550), the river's current (#541), gentler fall damage (#536), thick trunks that stop a body (#559).
- Animals: redrawn with walks and idles (#396, #409, #410, #412), they keep off fires (#421); the AI
  debug and the hot reload of the mods' data (#457, decision 184).
- Multiplayer: gestures (#453), chat (#488, #533), teammates on the map (#519), others' torches and
  footprints (#521, #526), the server windows (#522, #523, #530, #539), the playtest server in GitHub
  Actions (#460, #470, #472, #475, #477, #555, #574), a phone's server playing its own bots (#566),
  the server sending its mods' files (#553, decision 189), the playtest switches for hosts (#556).
- Languages: every player's text is a key, ten languages (#455, #456, #459, #501, #560; decision 183).
- Platforms: the Android APK and the app icons (#544; decision 188, Android draws with Vulkan), PC
  builds read the mods beside the program (#493), the PC interface sizes (#543), automatic graphics
  quality (#542), the CRT look (#498, #503), the phones' keyboards (#464–#520, #576).
- Interface: the UI kit (#511, #531, #558) and its gallery (#505), the state panel (#529), the upright
  phone's hotbar (#537); a new world with a camp in sight, a master switch of a mod and the import of
  one's own mods from a zip (#562).

**Systems changed.** The four biggest scripts split into chains of parts (#376, decision 168); the
tool decides the blow and the skill the hand (#395); the shader warm-up by the time of day (#379,
#381, #384); only the columns around an edit are rebuilt (#420, #426); stage 1 closed and the
version went to 0.3 (#483).

**Bugs fixed (a selection).** The PC build's crash on menu buttons (#484), the restart into a
hosted server (#485), felled trees on the clients (#518), the death sack's messages (#479), Vulkan
garbage after a rejoin (#569), free building that zeroed what digging gave (#393), and flaky frame
checks (#428, #465, #535, #570, #575).

**New dependencies.** `cloudflared` in the playtest workflow (pinned by version only, WA-042); the
runner's Android SDK and JDK 17 for the APK; `playwright-core` 1.48.2 is unchanged. No plugins or
add-ons: the project still has none.

**Configuration.** `export_presets.cfg` gained Android; `project.godot` the version stage 0.3 and the
Android renderer settings (decision 188); `.github/workflows/build.yml` the Android jobs and the
path filters of #547; `.github/workflows/playtest.yml` is new.

**Documentation.** The docs moved to English with `_RU` copies (#524, #525), the translation guide
(#494) and the security pages (#377) were added.

## D. Problems found

| ID | Priority | Category | Description | Status |
|---|---|---|---|---|
| WA-001 | High | Security, anti-cheat | A hello carrying a server bot's key (`bot:<number>`) took over that bot's account | Fixed in this audit (not committed) |
| WA-002 | High | Saves | Blueprint ghosts and farm work marks were lost on every load of a world | Fixed in this audit (not committed) |
| WA-003 | Medium | Security, client | A failed download of a server's mod files left the files in the cache untrimmed | Fixed in this audit (not committed) |
| WA-004 | Low | Security, impersonation | A player name that is a phrase key (`[server_stopped]`) was shown as the game's own phrase | Fixed in this audit (not committed) |
| WA-005 | Low | Performance, memory | The list of animals born grew for accounts with no connection | Fixed in this audit (not committed) |
| WA-006 | Low | Code, comments | The comment on `Requests.may_cheat` said playtest servers only | Fixed in this audit (not committed) |
| WA-007 | Medium | Documentation, security | The threat model said the server keeps only a hash of players' keys | Fixed in this audit (not committed) |
| WA-008 | Medium | Tools, balance | The balance tables' generator wrote raw keys, so `--check` always said the tables were stale | Fixed in this audit (not committed) |
| WA-009 | Low | Tests | `server_test` logged 272 "Lambda capture freed" errors | Fixed in this audit (not committed) |
| WA-010 | Low | Code, async | The join screen resumed a function after an await in a freed screen | Fixed in this audit (not committed) |
| WA-011 | Medium | Documentation | About 30 stale statements in 34 documentation files | Fixed in this audit (not committed) |
| WA-012 | Medium | Security, land rights | Boats ignore land rights | Open: needs plan |
| WA-013 | Medium | Security, secrets | `access.json` keeps players' keys as they are | Open: needs plan |
| WA-014 | Medium | Security, client | An in-game mod reload downloads a server's set without asking | Open: needs plan |
| WA-015 | Low | Security, roles | A host, not only the owner, can switch the server to another world | Open: user decision |
| WA-016 | Low | Security, availability | One address can take every mod-download slot | Open: needs plan |
| WA-017 | Low | Security, client | The zip import unpacks an entry before checking its size | Open: needs plan |
| WA-018 | Low | Security, secrets | The server's password is passed on a command line and stored in plain text | Open: needs plan |
| WA-019 | Low | Security, audit trail | A host's playtest switches on a normal server are not logged | Open: needs plan |
| WA-020 | High | Saves, data | A single-player save of a hosted world drops its teams, fights and the next player number | Open: needs plan (save format) |
| WA-021 | Medium | Synchronization | Cell changes for a chunk waiting to be restored are dropped on the client | Open: needs plan |
| WA-022 | Low | Synchronization | The server's rules never reach a remote client | Open: needs plan |
| WA-023 | Low | Saves | «New world» over a saved world also erases the hosted data in that folder | Open: user decision |
| WA-024 | Medium | Architecture | `main.gd` holds the client's connection and mod-download flow | Open: user decision (structure) |
| WA-025 | Medium | Maintainability | Scripts past 1500 lines are not split into parts, and some functions are very long | Open: needs plan |
| WA-026 | Medium | Duplication | Two pairs of near-identical classes and a copy of the roles | Open: needs plan |
| WA-027 | Low | Dead code | Thirteen functions are never called | Open: user decision |
| WA-028 | Low | Translation | Translated pieces are glued together | Open: needs plan |
| WA-029 | Low | Translation | Ten phrases of the zip import and the seed warning exist only in English and Russian | Open: backlog |
| WA-030 | Low | Content by role | The main menu names a content id that is not core's | Open: needs plan |
| WA-031 | Medium | Tests, performance | The frames check of mowing sits on a fixed one-off spike | Open: needs plan |
| WA-032 | Medium | Performance | An idle frame leaves thin headroom | Open: needs phone data |
| WA-033 | Medium | Performance | PC builds poll the mods' files on disk every frame | Open: needs plan |
| WA-034 | Medium | Performance | A teleport or a respawn costs one-off long frames | Open: needs plan |
| WA-035 | Low | Performance | The scare of fires scans every placed thing every half second | Open: needs plan |
| WA-036 | Low | Performance | The edge haze recomputes its grid every frame | Open: backlog |
| WA-037 | Low | Memory | Icon image caches are never cleared | Open: backlog |
| WA-038 | Low | Memory | Two server dictionaries are never pruned | Open: backlog |
| WA-039 | Medium | CI | Parallel green pull requests still merge into a red main | Open: owner action |
| WA-040 | Medium | CI, dependencies | Every pinned action still targets Node 20 | Open: needs plan |
| WA-041 | Medium | CI, secrets | The release Android keystore is given to every pull request from the repo | Open: user decision |
| WA-042 | Medium | CI, supply chain | The playtest workflow downloads cloudflared with no checksum | Open: needs plan |
| WA-043 | Medium | CI | Nothing orders the publishing jobs | Open: needs plan |
| WA-044 | Low | CI | Runs stuck in «queued» | Open: owner action |
| WA-045 | Low | CI, dependencies | The toolchain is not pinned | Open: needs plan |
| WA-046 | Low | Dependencies | No licence file and no list of external dependencies | Open: user decision |
| WA-047 | Low | Tests | Leaks at exit in the test logs | Open: backlog |
| WA-048 | Low | CI, balance | No check runs `balance_report --check` | Open: needs plan |
| WA-049 | Medium | Balance, tests | `balance_test` leaves quality out of its best cases | Open: user decision |
| WA-050 | Low | Balance | Some tool tiers add little | Open: playtest |
| WA-051 | Low | Data | The skills table shows quality for build and swim that nothing uses | Open: backlog |
| WA-052 | Low | Data | Numbers that describe content live in code constants | Open: backlog |
| WA-053 | Low | Content | The validator warns of a dead end and twins | Open: user decision |
| WA-054 | Medium | Documentation | The architecture overview is stamped 2026-11-09 and misses what was built since | Open: needs plan |
| WA-055 | Low | Documentation | The decisions page lacks rows for seven decisions | Open: backlog |
| WA-056 | Low | Documentation | The testing guide does not map interface and text changes to their tests | Open: backlog |
| WA-057 | Medium | Saves, web | A browser save can lose up to 30 s | Open: backlog |
| WA-058 | Medium | Security | Unencrypted ws:// on a local network (S-20) | Open: user decision |
| WA-059 | Medium | Security | No player accounts (S-22) | Open: user decision |
| WA-060 | Medium | CI | Required checks on main are not confirmed | Open: owner action |
| WA-061 | Medium | Performance | `progress_test` shows 2–6 s "browser" frames after a far teleport | Open: needs plan |
| WA-062 | Medium | Network | Animals' snapshots go over the whole world (net-8, net-m1) | Open: needs plan |
| WA-063 | Medium | Interface, performance | A setting change or a bag opening lays out the whole HUD (ui-big-3) | Open: needs plan |
| WA-064 | Medium | Balance | Balance items waiting for a playtest | Open: playtest |
| WA-065 | Medium | Process | The phone checklist that closes stage 1 is not confirmed | Open: user action |
| WA-066 | Low | Various | Lows carried from the stage audits (one entry, letters a–o) | Open: backlog |
| WA-067 | Low | Code | Blowing up the menu's sparrow prints an engine error | Open: backlog |

The ten «carried» problems (WA-057…WA-066) come from the stage audits and the balance stage; the
others are new. The full record of each open one is in [OPEN_ISSUES.md](OPEN_ISSUES.md).

**Suspicions to check next week** (seen by a reviewer, not confirmed, not counted above):
- chest contents (`PROPS` records, `CHEST` events) seem to reach every client, whatever the land's
  «chests» right;
- deleting one's own mods (`ModImport.clear`) seems to drop a saved world's bundles, cells and items
  silently;
- a kill during a server's save may leave chunks newer than the list of placed things;
- switching the playtest switches off on a playtest server may reset the rules and the time's pace for
  everyone;
- numbers and nesting in YAML from a hostile server (allocations, recursion): the bounds were not
  checked;
- markers, hands, modes and the explored map seem not to be saved when playing on a socket server;
- `ModFetch._open` may hold up to about 256 MB of partly received files in a phone's memory;
- the playtest link is public, so anyone can stop or reset a playtest session (looks intended).

## E. Fixes made

| ID | What | Files |
|---|---|---|
| WA-001 | A hello whose key begins with `BOT_KEY` is refused | `src/server/server.gd` |
| WA-002 | The blueprint's loader reads the cells and forms JSON keeps (`Plans.cell_of`); the format is unchanged and the ghosts in existing saves come back | `src/shared/game/plans.gd`, `docs/systems/interaction.md` (+`_RU`) |
| WA-003 | A failed download trims the mod cache too | `src/client/net/mod_fetch.gd` |
| WA-004 | A name that is a phrase key is refused as taken | `src/server/server.gd`, `docs/security/NETWORK_SECURITY.md` (+`_RU`), `SECURITY_TESTING.md` (+`_RU`) |
| WA-005 | `PlayerLink.drop_events` clears the outbox and the animals born for accounts with no connection | `src/server/player_link.gd`, `src/server/server.gd` |
| WA-006 | The comment on `may_cheat` | `src/server/requests.gd` |
| WA-007 | The threat model and the network page say what `access.json` keeps | `docs/security/THREAT_MODEL.md`, `NETWORK_SECURITY.md` (+`_RU`) |
| WA-008 | The balance tables' names through `Lang` in Russian, `Lang.drop()` before exit | `tools/balance_report.gd` |
| WA-009 | The check keeps an instance id, not the freed node | `tests/server_test.gd` |
| WA-010 | A one-shot connection instead of an await | `src/client/ui/join_screen.gd` |
| WA-011 | About 30 stale statements, below | 32 files of `docs/` and the two READMEs |

The statements of WA-011, each checked against the code: ROADMAP T10 and T11 (`NIGHT_FLOOR` 2.0, UI
tests and the APK exist); DATA_MODEL counts (218 items, 22 plants) and the fields `heal`, `visions`,
`quality_cap`; the material atlas uses 38 (30 materials and 8 barks) in `systems/content.md`, `DATA_MODEL.md` and
`specifications/BUNDLE_SYSTEM.md`; DECISIONS and INDEX range 1–189, ten skills, the renderer row for
Android (decision 188), 19 system pages; `systems/testing.md` lists every `run_tests` topic, and
TEST_COVERAGE has the counts of today and `ui_test`; ARCHITECTURE no longer lists Android as unbuilt
and names the APK job; README and `systems/ui.md` say ten skills, name the playtest step «Link for the
phone: open this step» and ask for the English «What's new» line too; `systems/territory.md` names
`Placed.beside(size)` instead of a constant that is gone; PROJECT_MAP has the Android preset and seven
new files; SYSTEMS' «not there» row keeps only roofs and decay; the balance pages say six spear blows
for a wolf, a wooden pickaxe weaker and in need of planks, and armour instead of the animals' bite in
the «Low» row.

**Also changed:** the new folder `docs/reports/weekly-audits/` with this report, `INDEX.md` and
`OPEN_ISSUES.md` (and their `_RU` copies), named in `docs/INDEX.md` and `docs/PROJECT_MAP.md`; dated
reports are left out of the documentation's path check and of the renaming tool like `docs/audit/`
(`tools/doc_index.py`, `tools/rename.py`), because they keep the paths of their day.

**Tests added.** `tests/unit/security_test.gd` `_test_door`: no one comes in with a bot's key (an
existing bot and one that is not there), and a name that is a phrase key is taken while a tag in
brackets is not. `tests/unit/plans_test.gd`: the ghost and its forms come back through JSON as the
world's file keeps them, and `Plans.cell_of` reads only the right forms. `run_tests` went from 5582 to
5586 checks. The cache trim of WA-003 has no test of its own: the limit is 200 MB; the existing fetch
tests pass.

**Checks after the fixes:** all those of CLAUDE.md (section F). Before the fixes the same suite gave
the same results, with the differences shown there.

## F. Quality metrics

Measured in this container (a busy, slow cloud machine) unless CI is named.

| Check | Before the fixes (`b35d371`) | After the fixes |
|---|---|---|
| `tools/lint.py` | 3376 files, 0 problems | 3376 files, 0 problems |
| `tools/doc_index.py --check` | OK | OK |
| `tools/lang_check.py --strict en,ru` | 2183 phrases, 0 problems; es, pt, fr, de, it, pl, tr, uk 2173 of 2183 | the same |
| `parse_check` | 284 scripts, 0 errors | 284 scripts, 0 errors |
| `validate` | OK: 30 materials, 218 items, 23 creatures, 20 trees, 6 bushes, 162 recipes, 22 plants; 2 warnings | the same |
| `content_report --check` | OK | OK |
| `balance_report --check` | stale | fresh |
| `run_tests` (29 topics) | 5582 checks, 0 failed | 5586 checks, 0 failed, 106 s |
| `save_test` | 84 checks, 0 failed, 30 s | 84, 0 failed, 31 s |
| `progress_test --part hunting` | 22, 0 failed, 187 s | 22, 0 failed, 325 s (run beside the others) |
| `progress_test --part other` | 183, 0 failed, 543 s | 183, 0 failed, 469 s |
| `server_test` | 182, 0 failures, 53 s; 276 ERROR lines | 182, 0 failures, 55 s; 3 ERROR lines (WA-047) |
| `frame_test` alone | 121 checks, 2 failed: idle 1.73 ms of 1.25, mowing 13.8 ms outside (2 over) | 121 checks, 2 failed: idle 1.27 ms of 1.25, night 2.06 ms of 2.00; mowing passed (8.8 ms, 0 over) |
| CI `frames` on `b35d371` | green: chunk 26.7 ms, idle 1.07 ms, mowing 7.9 ms (0 over), landing 11.3 ms (1 over, allowed) | not run in CI (nothing pushed) |
| Exports | Web 9 s, Windows 5 s, Linux 6 s, 0 errors and warnings | Web again for the browser test: 0 errors |
| Browser smoke test | — | passed: desktop, phone, upright phone (local Chromium); the upright run taps the join screen by the line WA-010 changed; one engine error after the menu's sparrow (WA-067) |
| Build sizes | Web: `.wasm` 38.0 MB + `.pck` 8.0 MB; Linux 70.2 MB + 8.0 MB; Windows 96.6 MB + 8.0 MB | — |
| Headless server | the test world (`--seed -1`): the land around in 1184 ms, listening | — |
| CI, main runs of the week | 195: 155 green, 23 red (13% of the finished), 16 cancelled, 1 queued | — |
| CI, pull request runs | 201: 154 green, 14 red, 28 cancelled, 5 other | — |
| CI time | a run on main ~11 min; the week's median 12.3 min (p90 18.1) | — |
| Known problems | 56 open | — |

The local `frame_test` failures are this machine's: every part of the idle frame is about 1.5 times
CI's (a chunk costs 28 ms here), the code changed by the audit runs on no client frame, and CI judges
(CLAUDE.md). They are in line with WA-031 and WA-032.

## G. Problems left open

| ID | Problem | Cause | Priority | Consequences | Actions | Due |
|---|---|---|---|---|---|---|
| WA-012 | Boats ignore land rights | `take_vessel` checks only reach, riders and death, and boarding nothing; a vessel has no owner. | Medium | A boat moored on someone's land can be put into anyone's bag or rowed away. | Plan: check the "build" right at the boat's cell in `take_vessel`, decide the right for boarding, add a test in `security_test`. | 2026-11-20 |
| WA-013 | `access.json` keeps players' keys as they are | Hosts, owners, bans and the whitelist are kept by key. | Medium | Whoever reads the world's folder gets the owner's key: full control of the server (`stop`, `op`). | Plan: keep `sha256_text()` of the keys and compare by hash, hashing old entries on load (a data format change, so a plan first). | 2026-11-27 |
| WA-014 | An in-game mod reload downloads a server's set without asking | `ModReload` starts `ModFetch` with `no_ask = true` for any set the server names in `MODS`. | Medium | A hostile server can push up to `SET_MAX` (256 MB) per reload with no prompt: mobile data and storage. | Plan: ask above `ASK_ABOVE` during play too, or limit reloads per server; a test in `mod_files_test`. | 2026-11-27 |
| WA-015 | A host, not only the owner, can switch the server to another world | The test commands `world`, `new` and `mod` need only `ROLE_HOST` off playtest servers, while `stop` needs the owner. | Low | A host can replace the world under everyone; each `new` makes a world folder. | Plan: owner only off playtest servers; update the permissions doc. | backlog |
| WA-016 | One address can take every mod-download slot | `_fetching()` counts slots for the whole server (`FETCHING_MAX` 32), and `_pending(address)` skips fetching connections. | Low | One client with the password keeps the others with other mods waiting (`WHY_WAIT`). | Plan: a cap per address (except the tunnel's local one). | backlog |
| WA-017 | The zip import unpacks an entry before checking its size | `zip.read_file(name)` runs before `data.size() > FILE_MAX`. | Low | A zip bomb the player picks can run the game out of memory. | Plan: read the sizes from the zip's directory first. | backlog |
| WA-018 | The server's password is passed on a command line and stored in plain text | Bot processes get `--password <pw>`; `user://server.cfg` keeps the password itself. | Low | Other local users can read it from the process list; the file is a secret. | Plan: pass it through the environment or stdin; store a hash (`_same` compares hashes already). | backlog |
| WA-019 | A host's playtest switches on a normal server are not logged | The `CHEATS` request is taken for a host (#490) but writes nothing to the security log, unlike `give`. | Low | Free items or teleports for the whole world leave no trace. | Plan: flag `cheats` with the keys changed when not on a playtest server. | backlog |
| WA-020 | A single-player save of a hosted world drops its teams, fights and the next player number | `SaveGame._write_world` builds the world's meta anew without `teams`, `fights` and `next_player`, which `ServerStore` writes; both use the same folder (`WorldStore.world_dir`). | High | After hosting, playing alone and hosting again: teams and newcomers' protection are gone, and a new player can get the id of a saved player who is offline, and with it their land and team. | Plan: the single-player save keeps the keys it does not own (start from the old meta); the server raises `next_id` past the highest saved player; a hosted → single → hosted scenario in `save_test`. | 2026-11-20 |
| WA-021 | Cell changes for a chunk waiting to be restored are dropped on the client | `Mirror` applies `CELLS` only to a chunk already in the world, while a chunk just received waits in `RemoteGen.packs`. | Medium | On joining and in new ground a cell stays as it was (dug, felled, wetted, a door's cut) until the chunk is sent again; `DROPS` can be overwritten the same way. | Plan: patch the waiting pack or keep the pending cells and apply them after the restore; a test in `net_test`. | 2026-11-27 |
| WA-022 | The server's rules never reach a remote client | The client makes its own `Rules.new()` and nothing carries the server's. | Low | On a server with free items the client shows no «get» buttons; the cheats switch sends the client's own values. | Plan: the rules in the welcome, or a `RULES` event. | backlog |
| WA-023 | «New world» over a saved world also erases the hosted data in that folder | `SaveGame.replace_world` erases the whole folder, `players/` and `access.json` too. | Low | Bans, hosts and players' records of a world hosted on this device go with it. | Plan: name the hosted data in the warning, or keep `players/` and `access.json`. | backlog |
| WA-024 | `main.gd` holds the client's connection and mod-download flow | Joining, hosting and taking the server's files grew into the scene's root (1163 → 1466 lines). | Medium | Against the rule "main.gd only builds the scene and runs the frame": the flow is hard to test or change. | Plan: a client module (for example `src/client/net/join_flow.gd`) with thin forwarding on Main. A structure change, so the user picks first. | stage 2 |
| WA-025 | Scripts past 1500 lines are not split into parts, and some functions are very long | Growth since 2026-11-07: `wildlife.gd` 1184 → 1942, `ui_style.gd` 1315 → 1880 lines. | Medium | Hard to review and merge; `wildlife.gd` keeps growing. | Plan: chains of parts as in decision 168; per-section functions. | when next touched |
| WA-026 | Two pairs of near-identical classes and a copy of the roles | `build_mode.gd` and `farm_mode.gd` share their scaffolding; the client's `bot.gd` and `server_bot.gd` share tasks and helpers; `test_commands.gd` re-declares `ROLE_HOST` and `ROLE_OWNER`. | Medium | A fix in one copy is missed in the other; the roles can drift. | Plan: a shared base for the modes, a shared bot brain, the server's roles used directly. | when next touched |
| WA-027 | Thirteen functions are never called | Left after changes. | Low | Reading cost; some may be meant for the next stage. | The owner decides what to delete. | backlog |
| WA-028 | Translated pieces are glued together | Some texts are built from a phrase and a fragment key instead of one phrase with values. | Low | Word order and punctuation are wrong in some of the ten languages; `lang_check` does not see it. | Plan: whole-phrase keys with `Lang.f`. | backlog |
| WA-029 | Ten phrases of the zip import and the seed warning exist only in English and Russian | #562 added them after #560 completed every language. | Low | Players in eight languages see those lines in English. | Translate the ten phrases (`tools/lang_check.py --write <lang>`). | 2026-11-27 |
| WA-030 | The main menu names a content id that is not core's | `main_menu.gd` asks for `animals:sparrow` by id. | Low | Against the rule "the engine asks for content by role". | Plan: a role in the YAML (an animal marked for the menu). | backlog |
| WA-031 | The frames check of mowing sits on a fixed one-off spike | The spike (a scythe swing, 7–9.5 ms worst outside) does not scale, while the allowance is 1 + frames/250; landing had the same problem until #575. | Medium | The job goes red on fast runners and slow machines, which hides real regressions behind reruns. | Plan: treat swings as events as #575 did for landing, or a floor under the limit; a test-only change. | 2026-11-20 |
| WA-032 | An idle frame leaves thin headroom | Idle is 0.96–1.20 ms against the 1.25 ms floor on slow CI runners, up about 10–20% from 0.9–1.0 ms on 2026-11-04; night 1.35–1.57 ms against 2.0. | Medium | By the project's 10× rule a phone spends about 10 ms of 16.7 doing nothing. | Profile the player part on a phone (stats panel, F3) before changing code. | 2026-11-27 |
| WA-033 | PC builds poll the mods' files on disk every frame | `ModReload.update` steps `ContentWatch` every frame, 120 files or folders a call, forever, whenever `content/` is beside the program. | Medium | Constant disk calls on Windows and Linux for a feature only modders use. | Plan: step every 0.25 s or every N frames; measure on Windows first. | 2026-11-27 |
| WA-034 | A teleport or a respawn costs one-off long frames | The animals round the new place, the view and the cut all move at once. | Medium | About 80–150 ms on a phone at a respawn or a cave teleport. | Plan: spread the animals' re-settling over several frames. See also WA-061. | backlog |
| WA-035 | The scare of fires scans every placed thing every half second | `Wildlife._find_fires` builds `placed.things + placed.lights` each time. | Low | O(all placed things) on the server's tick of a long-running or phone-hosted server. | Plan: keep a list of lit things that scare, updated when their light changes. | backlog |
| WA-036 | The edge haze recomputes its grid every frame | `EdgeHaze.update` walks the key grid and compares arrays each frame. | Low | At most about 1 ms on a phone. | Skip the work unless the home chunk, the built set or the screen changed. | backlog |
| WA-037 | Icon image caches are never cleared | `UiStyle._images` and `_outlined` are keyed by texture id; mod reloads make new textures. | Low | Each reload or server switch keeps one more copy of every icon. | Add `UiStyle.forget()` beside `ItemIcons.forget()`. | backlog |
| WA-038 | Two server dictionaries are never pruned | `_flag_at` (by player and kind) and `_wrong` (by address) only grow. | Low | Slow growth over a long uptime or an address spray. | Drop entries older than their windows when writing. | backlog |
| WA-039 | Parallel green pull requests still merge into a red main | Two PRs green apart break together; no merge queue or "up to date" rule. | Medium | A broken main until someone fixes forward. | A merge queue or "require branches to be up to date" (repository settings, the owner). | 2026-11-20 |
| WA-040 | Every pinned action still targets Node 20 | The pins are the Node 20 majors. | Medium | The jobs break when GitHub removes the shim. | Plan: bump each pin to its Node 24 major, pinned by SHA. | 2026-11-27 |
| WA-041 | The release Android keystore is given to every pull request from the repo | The `android` job passes the secrets on `pull_request` with no branch condition. | Medium | Anyone who can push a branch can read the release key from a PR run; PR APKs carry the release signature. | Plan: the secrets only on main, or a protected environment (PR APKs keep the temporary key). | 2026-11-20 |
| WA-042 | The playtest workflow downloads cloudflared with no checksum | Only the version is pinned. | Medium | A swapped binary would run with the job's token. | Pin its SHA-256 as the Godot sums are. | 2026-11-27 |
| WA-043 | Nothing orders the publishing jobs | `publish`, `publish-android` and `deploy` have no concurrency group; reruns of older main runs happen. | Medium | A late rerun can overwrite pc-latest, android-latest or Pages with an older build. | Plan: a `publish` concurrency group and a check that the commit is still main's head. | 2026-11-27 |
| WA-044 | Runs stuck in «queued» | GitHub never started them. | Low | #510 has no CI verdict of its own (later runs cover it). | Cancel them in the GitHub interface. | 2026-11-20 |
| WA-045 | The toolchain is not pinned | `ubuntu-latest`, the runner's Android build tools, `playwright-core` 1.48.2 against a floating Chrome. | Low | A runner update can change builds or the smoke test without a commit. | Plan: pin the image and the build tools, update `playwright-core`. | backlog |
| WA-046 | No licence file and no list of external dependencies | `docs/DEPENDENCIES.md` is the code-layer map only. | Low | Unclear terms of use; a new machine needs guesswork. | The owner picks a licence; list Godot, templates, Android SDK and JDK, cloudflared, Python and Pillow, Node and playwright-core, Chrome, the font. | backlog |
| WA-047 | Leaks at exit in the test logs | Objects or resources still alive when the tests quit. | Low | Noise; a real leak would hide among them. | Run with `--verbose` to name the owners. | backlog |
| WA-048 | No check runs `balance_report --check` | It could not pass until this audit (WA-008). | Low | The balance tables can go stale unnoticed. | Add it to the `checks` job and to `run_all.sh`. | 2026-11-20 |
| WA-049 | `balance_test` leaves quality out of its best cases | Quality 100 makes a tool 1.2× faster and 1.5× more durable, and is easy to reach. | Medium | The documented envelope no longer holds at the top; the next buff crosses it unnoticed. | Plan: count quality in the best cases, or lower `PACE_PER_POINT` (a balance formula: the user's pick). | 2026-11-27 |
| WA-050 | Some tool tiers add little | Wooden pickaxe, scythe and sword are weaker than their stone twins and need planks; a flint knife hits as hard as a stone sword sooner; copper → bronze shovel only adds durability. | Low | Pointless items in the early game. | A playtest question: give the wooden tools a niche or drop them. | backlog |
| WA-051 | The skills table shows quality for build and swim that nothing uses | `Quality.GETS` and `MAKES` have no build or swim. | Low | Only the generated table misleads. | Optional `quality: 0` for build and swim. | backlog |
| WA-052 | Numbers that describe content live in code constants | Kept as rule tunables. | Low | A mod cannot change them. | Move to YAML fields when a mod needs another value. | backlog |
| WA-053 | The validator warns of a dead end and twins | `core:rot` is only what food spoils into; blueberry and currant have the same food and bush rules. | Low | Harmless now. | A design choice: a use for rot (compost), different berries. | backlog |
| WA-054 | The architecture overview is stamped 2026-11-09 and misses what was built since | Not re-checked after the stage 2 work. | Medium | The entry page of the architecture is behind the code. | Re-check it against the code and stamp it again. | 2026-11-20 |
| WA-055 | The decisions page lacks rows for seven decisions | Rows were not added as decisions were taken. | Low | The code's decisions are harder to find. | Add the rows. | backlog |
| WA-056 | The testing guide does not map interface and text changes to their tests | `ui`, `lang`, `signs`, `fences`, `boat` and `mod_files` tests came after the guide. | Low | A change may skip the test that covers it. | Add the rows. | backlog |
| WA-057 | A browser save can lose up to 30 s | IndexedDB is synced in the main loop. | Medium | Closing the tab soon after a save loses the last seconds. | Plan: sync on save through the page. | backlog |
| WA-058 | Unencrypted ws:// on a local network (S-20) | TLS is only through the tunnel. | Medium | Traffic on a LAN can be read. | The owner's choice (keep the tunnel, or add certificates). | backlog |
| WA-059 | No player accounts (S-22) | The key is the only identity. | Medium | Bans and roles are only as strong as the key on one device. | A user decision. | backlog |
| WA-060 | Required checks on main are not confirmed | A repository setting, not visible in the repo. | Medium | A red PR could be merged. | The owner turns on required checks. | 2026-11-20 |
| WA-061 | `progress_test` shows 2–6 s "browser" frames after a far teleport | Not explained. | Medium | A real teleport or join may hit the same cost. | Find the cause (see WA-034). | backlog |
| WA-062 | Animals' snapshots go over the whole world (net-8, net-m1) | Only the people list is filtered by zone. | Medium | Traffic grows with the world's animals, not with what a player sees. | Plan: filter snapshots by zone as people are. | backlog |
| WA-063 | A setting change or a bag opening lays out the whole HUD (ui-big-3) | `hud_layout._place` redoes everything. | Medium | A hitch on a phone. | Plan: lay out only what changed. | backlog |
| WA-064 | Balance items waiting for a playtest | Building toughness and decay, survival thresholds with wear on, the 40-minute day. | Medium | The numbers are guesses until played. | The user plays and picks. | backlog |
| WA-065 | The phone checklist that closes stage 1 is not confirmed | 18 items in `plan/backlog.md` wait for the user's phone. | Medium | Stage 1 behaviour on a phone is unconfirmed while stage 2 goes on. | The user goes through the list on the phone. | backlog |
| WA-066 | Lows carried from the stage audits (one entry, letters a–o) | Deferred on purpose or waiting for the user. | Low | Small each. | (a) `progress_test` bloomery placement flake; (b) digging yield, fishing each/yield, crafting growth; (c) content-7, `+` on quantities replaces; (d) game-5, `can_mow` ignores the season; (e) ui-big-8, two double-tap confirmations; (f) tests-tools-13, any label reruns CI; (g) tests-tools-3, HUD checks inside `frame_test`; (h) the security log lives only in memory, the move tolerance is 2.5 cells, limits by address are shared behind the tunnel; (i) changed far chunks stay in memory; (j) CLAUDE.md lacks the paragraph on the order of PRs; (k) `plan/architecture/` docs never checked against the code, decision 163; (l) performance items deferred in stage 5; (m) the ground → role dictionary twice, the `server.cfg` path; (n) weather «as in life» unchecked on a phone; (o) T5 and T6 constants by design. | backlog |
| WA-067 | Blowing up the menu's sparrow prints an engine error | Not traced; likely `HUD._place` run from `unlock_testing` while the HUD is outside the tree in the main menu. | Low | An error line on the phone's console; harmless so far. | Find which call meets a node outside the tree and guard it. | backlog |

## H. Risks of the next week

1. **The client's trust in servers.** Stage 2 goes on with mods sent by servers (decision 189): the
   reload without asking (WA-014) and the unchecked bounds of hostile YAML (a suspicion) need care;
   every new request must follow `docs/security/`.
2. **Saves of hosted worlds.** WA-020 before a playtest of a world that was also played alone. The
   blueprint's loader now reads the "(x, y, z)" form: a change of `Plans.to_list` must keep reading
   it.
3. **A red main.** Parallel merges (WA-039) and the frames check (WA-031) keep main red about one run
   in eight and hide real breakage.
4. **The big files grow.** `main.gd`, `wildlife.gd`, `ui_style.gd` (WA-024, WA-025): each new feature
   there makes the split dearer.
5. **CI's platform.** Node 20 (WA-040) and the release key on pull requests (WA-041).
6. **Phones.** The idle frame's headroom and the one-off frames of a teleport (WA-032, WA-034) are
   CI's numbers; only the phone's count.
7. **Translations.** New phrases must reach all ten languages (WA-029 shows how they lag).

## I. Final assessment

**State.** Stable: builds, the whole headless suite and main's CI pass; the server's defences of
stage 7 hold (S-01…S-19 and S-21 are still fixed). **Dynamics.** The first weekly audit: against the
stage audits, about thirty earlier items are done, ten remain, and one new hole of the stage 7 class
(a bot's key) was found and closed. **The week's achievements:** stage 1 closed; stage 2 items 1
(Android) and 2 (the server's mod files) done; ten languages; the docs in English; the UI kit.
**Main risks:** WA-020 (saves of hosted worlds), WA-014 (mods pushed by a server), CI stability
(WA-031, WA-039), the architecture's drift in `main.gd` and the big files. **Recommendations:**
1. review and commit this audit's fixes;
2. next: WA-020, WA-012 (boats on claimed land), WA-031 (the mowing check), WA-048 (the balance
   check in CI), WA-054 (the architecture page);
3. the owner decides WA-041 (the keystore), WA-039 (a merge queue, in the repository settings),
   WA-024 (moving the connection flow out of `main.gd`), WA-049 (quality in the balance envelope);
4. profile an idle frame on the phone.

## Areas not fully checked, and why

- **A real phone or Android device:** none here. The 10× rule, Vulkan and touch were judged from CI
  and the code only.
- **Frame times:** this container is too slow and noisy; CI judges (`frame_test` was still run twice).
- **The repository's settings** (required checks, branch rules): not visible from the code.
- **Active security tests** ran only in a local copy; no public or playtest server was touched.
- **The library's `plan/` documents** were not checked against the code beyond the decisions 165–189.
- **By reading only, not run:** WA-020, WA-021, WA-022 and the suspicions above.

## Git state at the end

The working tree was clean when the audit began (`git status` empty at `b35d371`). Everything changed
is this audit's: the code and docs in section E, and the new files of `docs/reports/weekly-audits/`.
Nothing was deleted but a stray file `shared` that a reviewer's command had written in the root (not
the owner's). Nothing was committed, pushed, merged or published. The export folder `build/` is
ignored by git.
