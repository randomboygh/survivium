# Open issues

The problems found by the weekly audits that are not fixed yet, the most urgent first. Each audit
adds the new ones, checks the old ones again, closes those fixed and changes a priority when there is
a reason; the history of each status stays in the weekly reports ([INDEX.md](INDEX.md)).

Last checked: 2026-11-14 ([WEEKLY_AUDIT_2026-11-14.md](WEEKLY_AUDIT_2026-11-14.md)), at commit
`b35d371` with that audit's fixes in the working tree. The fixes went into `main` on top of `e395528`: of the
four pull requests merged in between (#577–#580), #579 and #578 reach WA-031 and WA-043, noted there.
Closed since: WA-031 (#579, both main runs after it green), WA-040, WA-041, WA-042, WA-043, WA-045 (#583),
WA-048 (`balance_report --check` in CI and `run_all.sh`), WA-028, WA-029, WA-054, WA-055, WA-056 (#585),
WA-012, WA-013, WA-014, WA-015, WA-016, WA-017, WA-019, WA-022 (#587; WA-018 in part).

| Critical | High | Medium | Low | All |
|---|---|---|---|---|
| 0 | 1 | 18 | 17 | 36 |

Statuses: «needs plan» — the fix touches what the rules say to plan first (architecture, protocol,
saves, data formats, balance formulas); «user decision» — a choice of the owner's; «owner action» —
a repository setting or a step in GitHub; «playtest», «needs phone data» — waits for playing or
measuring on the phone; «backlog» — small, done when the area is next touched. The due dates are
recommendations.

### WA-020 · High · Saves, data

- **Description:** A single-player save of a hosted world drops its teams, fights and the next player number.
- **Cause:** `SaveGame._write_world` builds the world's meta anew without `teams`, `fights` and `next_player`, which `ServerStore` writes; both use the same folder (`WorldStore.world_dir`).
- **Confirmation:** Read: `src/client/save_game.gd:229-246` against `src/server/server_store.gd:148-170`; `src/server/server_main.gd:208`; `src/server/server.gd:836-842`. Not reproduced in a run.
- **Files and systems:** `src/client/save_game.gd`, `src/server/server_store.gd`, `src/server/server_main.gd`, `src/server/server.gd`
- **Consequences:** After hosting, playing alone and hosting again: teams and newcomers' protection are gone, and a new player can get the id of a saved player who is offline, and with it their land and team.
- **Recommended fix:** Plan: the single-player save keeps the keys it does not own (start from the old meta); the server raises `next_id` past the highest saved player; a hosted → single → hosted scenario in `save_test`.
- **Status:** Open: needs plan (save format); first found 2026-11-14 (new); due 2026-11-20.

### WA-021 · Medium · Synchronization

- **Description:** Cell changes for a chunk waiting to be restored are dropped on the client.
- **Cause:** `Mirror` applies `CELLS` only to a chunk already in the world, while a chunk just received waits in `RemoteGen.packs`.
- **Confirmation:** Read: `src/client/net/mirror.gd:123-135`, `src/client/net/remote_gen.gd`. Not reproduced in a run.
- **Files and systems:** `src/client/net/mirror.gd`, `src/client/net/remote_gen.gd`, `src/server/player_link.gd`
- **Consequences:** On joining and in new ground a cell stays as it was (dug, felled, wetted, a door's cut) until the chunk is sent again; `DROPS` can be overwritten the same way.
- **Recommended fix:** Plan: patch the waiting pack or keep the pending cells and apply them after the restore; a test in `net_test`.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due 2026-11-27.

### WA-024 · Medium · Architecture

- **Description:** `main.gd` holds the client's connection and mod-download flow.
- **Cause:** Joining, hosting and taking the server's files grew into the scene's root (1163 → 1466 lines).
- **Confirmation:** Read: `src/client/main.gd:489-713` and 11 static vars at 287-324; tests write them (`tests/server_test.gd:751`).
- **Files and systems:** `src/client/main.gd`, the menu callers, `tests/server_test.gd`, `docs/systems/network.md`
- **Consequences:** Against the rule "main.gd only builds the scene and runs the frame": the flow is hard to test or change.
- **Recommended fix:** Plan: a client module (for example `src/client/net/join_flow.gd`) with thin forwarding on Main. A structure change, so the user picks first.
- **Status:** Open: user decision (structure); first found 2026-11-14 (new); due stage 2.

### WA-025 · Medium · Maintainability

- **Description:** Scripts past 1500 lines are not split into parts, and some functions are very long.
- **Cause:** Growth since 2026-11-07: `wildlife.gd` 1184 → 1942, `ui_style.gd` 1315 → 1880 lines.
- **Confirmation:** Counted: `wc -l`; longest functions `settings_menu._section_rows` 350 lines, `land_layout._layout_row` 303, `hud._ready` 276.
- **Files and systems:** `src/shared/game/wildlife.gd`, `src/client/ui/ui_style.gd`, `src/client/ui/settings_menu.gd`, `src/shared/world/land_layout.gd`
- **Consequences:** Hard to review and merge; `wildlife.gd` keeps growing.
- **Recommended fix:** Plan: chains of parts as in decision 168; per-section functions.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due when next touched.

### WA-026 · Medium · Duplication

- **Description:** Two pairs of near-identical classes and a copy of the roles.
- **Cause:** `build_mode.gd` and `farm_mode.gd` share their scaffolding; the client's `bot.gd` and `server_bot.gd` share tasks and helpers; `test_commands.gd` re-declares `ROLE_HOST` and `ROLE_OWNER`.
- **Confirmation:** Read: `src/client/input/build_mode.gd:140-178` against `farm_mode.gd:115-155`; `src/server/server_bot.gd` header; `src/server/test_commands.gd:28-29`.
- **Files and systems:** `src/client/input/`, `src/server/server_bot.gd`, `src/server/test_commands.gd`
- **Consequences:** A fix in one copy is missed in the other; the roles can drift.
- **Recommended fix:** Plan: a shared base for the modes, a shared bot brain, the server's roles used directly.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due when next touched.

### WA-032 · Medium · Performance

- **Description:** An idle frame leaves thin headroom.
- **Cause:** Idle is 0.96–1.20 ms against the 1.25 ms floor on slow CI runners, up about 10–20% from 0.9–1.0 ms on 2026-11-04; night 1.35–1.57 ms against 2.0.
- **Confirmation:** CI `frames` logs (runs 43259077560 … 43516965633).
- **Files and systems:** `tests/frame_test.gd`; the player part (0.35–0.42 ms) is the largest
- **Consequences:** By the project's 10× rule a phone spends about 10 ms of 16.7 doing nothing.
- **Recommended fix:** Profile the player part on a phone (stats panel, F3) before changing code.
- **Status:** Open: needs phone data; first found 2026-11-14 (new); due 2026-11-27.

### WA-033 · Medium · Performance

- **Description:** PC builds poll the mods' files on disk every frame.
- **Cause:** `ModReload.update` steps `ContentWatch` every frame, 120 files or folders a call, forever, whenever `content/` is beside the program.
- **Confirmation:** Read: `src/client/mod_reload.gd:48-50`, `src/shared/content/content_watch.gd:15`; about 3700 entries, a pass every ~31 frames, ~7000 stat calls a second at 60 fps. Not measured.
- **Files and systems:** `src/client/mod_reload.gd`, `src/shared/content/content_watch.gd`
- **Consequences:** Constant disk calls on Windows and Linux for a feature only modders use.
- **Recommended fix:** Plan: step every 0.25 s or every N frames; measure on Windows first.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due 2026-11-27.

### WA-034 · Medium · Performance

- **Description:** A teleport or a respawn costs one-off long frames.
- **Cause:** The animals round the new place, the view and the cut all move at once.
- **Confirmation:** The #575 commit message: the first two frames after the jump are 8–15 ms past the budgets on CI. Not verified in code or on a phone.
- **Files and systems:** `src/shared/game/wildlife.gd`, the view
- **Consequences:** About 80–150 ms on a phone at a respawn or a cave teleport.
- **Recommended fix:** Plan: spread the animals' re-settling over several frames. See also WA-061.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due backlog.

### WA-039 · Medium · CI

- **Description:** Parallel green pull requests still merge into a red main.
- **Cause:** Two PRs green apart break together; no merge queue or "up to date" rule.
- **Confirmation:** GitHub runs: 23 of 178 completed main runs failed in 7 days (13%), two real breakages (43100842215 parse error, 43449990373 `run_tests`).
- **Files and systems:** `.github/workflows/build.yml`, repository settings
- **Consequences:** A broken main until someone fixes forward.
- **Recommended fix:** A merge queue or "require branches to be up to date" (repository settings, the owner).
- **Status:** Open: owner action; first found 2026-11-14 (new); due 2026-11-20.

### WA-049 · Medium · Balance, tests

- **Description:** `balance_test` leaves quality out of its best cases.
- **Cause:** Quality 100 makes a tool 1.2× faster and 1.5× more durable, and is easy to reach.
- **Confirmation:** Computed from `quality.gd` and the tables: a steel axe at chopping 10 and quality 100 empties stamina in 7.7 s (the test's floor is 8 s); an oak falls in 0.6 s (floor 0.5).
- **Files and systems:** `tests/unit/balance_test.gd`, `src/shared/game/quality.gd`
- **Consequences:** The documented envelope no longer holds at the top; the next buff crosses it unnoticed.
- **Recommended fix:** Plan: count quality in the best cases, or lower `PACE_PER_POINT` (a balance formula: the user's pick).
- **Status:** Open: user decision; first found 2026-11-14 (new); due 2026-11-27.

### WA-057 · Medium · Saves, web

- **Description:** A browser save can lose up to 30 s.
- **Cause:** IndexedDB is synced in the main loop.
- **Confirmation:** No sync code in `src/` or `tools/web_patch.py`; listed in `plan/backlog.md`.
- **Files and systems:** `src/client/save_game.gd`, the web export
- **Consequences:** Closing the tab soon after a save loses the last seconds.
- **Recommended fix:** Plan: sync on save through the page.
- **Status:** Open: backlog; first found 2026-11-14 (stage audits); due backlog.

### WA-058 · Medium · Security

- **Description:** Unencrypted ws:// on a local network (S-20).
- **Cause:** TLS is only through the tunnel.
- **Confirmation:** No `TLSOptions` in `src/`; `src/server/tunnel.gd`.
- **Files and systems:** `src/server/`, `src/client/net/`
- **Consequences:** Traffic on a LAN can be read.
- **Recommended fix:** The owner's choice (keep the tunnel, or add certificates).
- **Status:** Open: user decision; first found 2026-11-14 (stage 7); due backlog.

### WA-059 · Medium · Security

- **Description:** No player accounts (S-22).
- **Cause:** The key is the only identity.
- **Confirmation:** `plan/backlog.md`; a ban by name is evaded by another name.
- **Files and systems:** `src/server/server.gd`
- **Consequences:** Bans and roles are only as strong as the key on one device.
- **Recommended fix:** A user decision.
- **Status:** Open: user decision; first found 2026-11-14 (stage 7); due backlog.

### WA-060 · Medium · CI

- **Description:** Required checks on main are not confirmed.
- **Cause:** A repository setting, not visible in the repo.
- **Confirmation:** Cannot be checked from the repository.
- **Files and systems:** repository settings
- **Consequences:** A red PR could be merged.
- **Recommended fix:** The owner turns on required checks.
- **Status:** Open: owner action; first found 2026-11-14 (stage 5); due 2026-11-20.

### WA-061 · Medium · Performance

- **Description:** `progress_test` shows 2–6 s "browser" frames after a far teleport.
- **Cause:** Not explained.
- **Confirmation:** No fix commit since stage 5.
- **Files and systems:** `tests/progress_test.gd`, the world's streaming
- **Consequences:** A real teleport or join may hit the same cost.
- **Recommended fix:** Find the cause (see WA-034).
- **Status:** Open: needs plan; first found 2026-11-14 (stage 5); due backlog.

### WA-062 · Medium · Network

- **Description:** Animals' snapshots go over the whole world (net-8, net-m1).
- **Cause:** Only the people list is filtered by zone.
- **Confirmation:** Read: `src/server/player_link.gd` `_snap` has no zone test.
- **Files and systems:** `src/server/player_link.gd`
- **Consequences:** Traffic grows with the world's animals, not with what a player sees.
- **Recommended fix:** Plan: filter snapshots by zone as people are.
- **Status:** Open: needs plan; first found 2026-11-14 (stage 4); due backlog.

### WA-063 · Medium · Interface, performance

- **Description:** A setting change or a bag opening lays out the whole HUD (ui-big-3).
- **Cause:** `hud_layout._place` redoes everything.
- **Confirmation:** Read: `src/client/ui/hud_layout.gd`; not measured again.
- **Files and systems:** `src/client/ui/hud_layout.gd`
- **Consequences:** A hitch on a phone.
- **Recommended fix:** Plan: lay out only what changed.
- **Status:** Open: needs plan; first found 2026-11-14 (stage 4); due backlog.

### WA-064 · Medium · Balance

- **Description:** Balance items waiting for a playtest.
- **Cause:** Building toughness and decay, survival thresholds with wear on, the 40-minute day.
- **Confirmation:** `docs/balance/GAME_BALANCE_ROADMAP.md`.
- **Files and systems:** the balance docs, the data
- **Consequences:** The numbers are guesses until played.
- **Recommended fix:** The user plays and picks.
- **Status:** Open: playtest; first found 2026-11-14 (balance stage); due backlog.

### WA-065 · Medium · Process

- **Description:** The phone checklist that closes stage 1 is not confirmed.
- **Cause:** 18 items in `plan/backlog.md` wait for the user's phone.
- **Confirmation:** `plan/backlog.md` «Проверить на телефоне».
- **Files and systems:** the whole game on a phone
- **Consequences:** Stage 1 behaviour on a phone is unconfirmed while stage 2 goes on.
- **Recommended fix:** The user goes through the list on the phone.
- **Status:** Open: user action; first found 2026-11-14 (stage 1); due backlog.

### WA-018 · Low · Security, secrets

- **Description:** The server's password is stored in plain text (the bots' command line no longer carries it, #587).
- **Cause:** Bot processes get `--password <pw>`; `user://server.cfg` keeps the password itself.
- **Confirmation:** Read: `src/server/test_commands.gd:242`, `src/server/config.gd:111`.
- **Files and systems:** `src/server/test_commands.gd`, `src/server/config.gd`
- **Consequences:** Other local users can read it from the process list; the file is a secret.
- **Recommended fix:** Plan: pass it through the environment or stdin; store a hash (`_same` compares hashes already).
- **Status:** Open: needs plan (the host's window shows the password, so a hash changes what it can show); first found 2026-11-14; bots' argv fixed by #587; due backlog.

### WA-023 · Low · Saves

- **Description:** «New world» over a saved world also erases the hosted data in that folder.
- **Cause:** `SaveGame.replace_world` erases the whole folder, `players/` and `access.json` too.
- **Confirmation:** Read: `src/client/save_game.gd:105-118`; a two-tap warning guards it.
- **Files and systems:** `src/client/save_game.gd`
- **Consequences:** Bans, hosts and players' records of a world hosted on this device go with it.
- **Recommended fix:** Plan: name the hosted data in the warning, or keep `players/` and `access.json`.
- **Status:** Open: user decision; first found 2026-11-14 (new); due backlog.

### WA-027 · Low · Dead code

- **Description:** Thirteen functions are never called.
- **Cause:** Left after changes.
- **Confirmation:** `grep -w` over src, tests, tools, docs: `land.has_mine`, `farm_mode.next_filter`, `icon_tabs.set_tip`, `scroll_column.add_item`, `clear_items`, `set_shown`, `boats.vessel_at`, `actions_base.put_block`, `actions_water.biome_under`, `placed.is_steps`, `workshop.condition`, `shader_probe._body`; filter state "not shown for now" in the modes.
- **Files and systems:** the files named
- **Consequences:** Reading cost; some may be meant for the next stage.
- **Recommended fix:** The owner decides what to delete.
- **Status:** Open: user decision; first found 2026-11-14 (new); due backlog.

### WA-030 · Low · Content by role

- **Description:** The main menu names a content id that is not core's.
- **Cause:** `main_menu.gd` asks for `animals:sparrow` by id.
- **Confirmation:** Read: `src/client/ui/main_menu.gd:45, 120`; it falls back when the bundle is off.
- **Files and systems:** `src/client/ui/main_menu.gd`
- **Consequences:** Against the rule "the engine asks for content by role".
- **Recommended fix:** Plan: a role in the YAML (an animal marked for the menu).
- **Status:** Open: needs plan; first found 2026-11-14 (new); due backlog.

### WA-035 · Low · Performance

- **Description:** The scare of fires scans every placed thing every half second.
- **Cause:** `Wildlife._find_fires` builds `placed.things + placed.lights` each time.
- **Confirmation:** Read: `src/shared/game/wildlife.gd:827, 841`.
- **Files and systems:** `src/shared/game/wildlife.gd`
- **Consequences:** O(all placed things) on the server's tick of a long-running or phone-hosted server.
- **Recommended fix:** Plan: keep a list of lit things that scare, updated when their light changes.
- **Status:** Open: needs plan; first found 2026-11-14 (new); due backlog.

### WA-036 · Low · Performance

- **Description:** The edge haze recomputes its grid every frame.
- **Cause:** `EdgeHaze.update` walks the key grid and compares arrays each frame.
- **Confirmation:** Read: `src/client/world/edge_haze.gd:53-72`; CI idle `chunks` part 0.06–0.10 ms.
- **Files and systems:** `src/client/world/edge_haze.gd`
- **Consequences:** At most about 1 ms on a phone.
- **Recommended fix:** Skip the work unless the home chunk, the built set or the screen changed.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-037 · Low · Memory

- **Description:** Icon image caches are never cleared.
- **Cause:** `UiStyle._images` and `_outlined` are keyed by texture id; mod reloads make new textures.
- **Confirmation:** Read: `src/client/ui/ui_style.gd:1374-1376`, `remember` at 1461; no `forget`.
- **Files and systems:** `src/client/ui/ui_style.gd`, `src/client/mod_reload.gd`
- **Consequences:** Each reload or server switch keeps one more copy of every icon.
- **Recommended fix:** Add `UiStyle.forget()` beside `ItemIcons.forget()`.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-038 · Low · Memory

- **Description:** Two server dictionaries are never pruned.
- **Cause:** `_flag_at` (by player and kind) and `_wrong` (by address) only grow.
- **Confirmation:** Read: `src/server/server.gd:901, 998-1000`.
- **Files and systems:** `src/server/server.gd`
- **Consequences:** Slow growth over a long uptime or an address spray.
- **Recommended fix:** Drop entries older than their windows when writing.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-044 · Low · CI

- **Description:** Runs stuck in «queued».
- **Cause:** GitHub never started them.
- **Confirmation:** GitHub runs: main 43097752659 (#510) and three PR runs queued since 2026-11-11; one startup failure.
- **Files and systems:** GitHub Actions
- **Consequences:** #510 has no CI verdict of its own (later runs cover it).
- **Recommended fix:** Cancel them in the GitHub interface.
- **Status:** Open: owner action; first found 2026-11-14 (new); due 2026-11-20.

### WA-046 · Low · Dependencies

- **Description:** No licence file and no list of external dependencies.
- **Cause:** `docs/DEPENDENCIES.md` is the code-layer map only.
- **Confirmation:** `ls LICENSE*` finds nothing (only `assets/fonts/OFL.txt`); the Python tools import Pillow with no requirements file.
- **Files and systems:** the repository root, `docs/DEPENDENCIES.md`
- **Consequences:** Unclear terms of use; a new machine needs guesswork.
- **Recommended fix:** The owner picks a licence; list Godot, templates, Android SDK and JDK, cloudflared, Python and Pillow, Node and playwright-core, Chrome, the font.
- **Status:** Open: user decision; first found 2026-11-14 (new); due backlog.

### WA-047 · Low · Tests

- **Description:** Leaks at exit in the test logs.
- **Cause:** Objects or resources still alive when the tests quit.
- **Confirmation:** Run: "ObjectDB instances leaked" in `run_tests` and `server_test`; `server_test` keeps 3 ERROR lines (a thread exit, pages in use, resources in use).
- **Files and systems:** the scene tests
- **Consequences:** Noise; a real leak would hide among them.
- **Recommended fix:** Run with `--verbose` to name the owners.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-050 · Low · Balance

- **Description:** Some tool tiers add little.
- **Cause:** Wooden pickaxe, scythe and sword are weaker than their stone twins and need planks; a flint knife hits as hard as a stone sword sooner; copper → bronze shovel only adds durability.
- **Confirmation:** The balance tables (regenerated in a copy, equal to the committed ones).
- **Files and systems:** the tools' YAML
- **Consequences:** Pointless items in the early game.
- **Recommended fix:** A playtest question: give the wooden tools a niche or drop them.
- **Status:** Open: playtest; first found 2026-11-14 (new); due backlog.

### WA-051 · Low · Data

- **Description:** The skills table shows quality for build and swim that nothing uses.
- **Cause:** `Quality.GETS` and `MAKES` have no build or swim.
- **Confirmation:** Read: `src/shared/game/quality.gd`; the character window hides it (`person_panel.gd:251-254`).
- **Files and systems:** `content/core/data/skills.yaml`, `docs/balance/GAME_BALANCE_TABLES.md`
- **Consequences:** Only the generated table misleads.
- **Recommended fix:** Optional `quality: 0` for build and swim.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-052 · Low · Data

- **Description:** Numbers that describe content live in code constants.
- **Cause:** Kept as rule tunables.
- **Confirmation:** Read: `src/shared/game/vessels.gd:21` `SEATS`, `actions_nature.gd:25-31` seed chances, swing times in `actions_farm.gd`, `actions_boat.gd`, `actions_tame.gd`.
- **Files and systems:** the files named
- **Consequences:** A mod cannot change them.
- **Recommended fix:** Move to YAML fields when a mod needs another value.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.

### WA-053 · Low · Content

- **Description:** The validator warns of a dead end and twins.
- **Cause:** `core:rot` is only what food spoils into; blueberry and currant have the same food and bush rules.
- **Confirmation:** Run: `tools/validate.gd`, 2 warnings.
- **Files and systems:** `content/core`, `content/plants`
- **Consequences:** Harmless now.
- **Recommended fix:** A design choice: a use for rot (compost), different berries.
- **Status:** Open: user decision; first found 2026-11-14 (new); due backlog.

### WA-066 · Low · Various

- **Description:** Lows carried from the stage audits (one entry, letters a–o).
- **Cause:** Deferred on purpose or waiting for the user.
- **Confirmation:** Re-checked by grep at the cited places.
- **Files and systems:** see the list
- **Consequences:** Small each.
- **Recommended fix:** (a) `progress_test` bloomery placement flake; (b) digging yield, fishing each/yield, crafting growth; (c) content-7, `+` on quantities replaces; (d) game-5, `can_mow` ignores the season; (e) ui-big-8, two double-tap confirmations; (f) tests-tools-13, any label reruns CI; (g) tests-tools-3, HUD checks inside `frame_test`; (h) the security log lives only in memory, the move tolerance is 2.5 cells, limits by address are shared behind the tunnel; (i) changed far chunks stay in memory; (j) CLAUDE.md lacks the paragraph on the order of PRs; (k) `plan/architecture/` docs never checked against the code, decision 163; (l) performance items deferred in stage 5; (m) the ground → role dictionary twice, the `server.cfg` path; (n) weather «as in life» unchecked on a phone; (o) T5 and T6 constants by design.
- **Status:** Open: backlog; first found 2026-11-14 (stage audits); due backlog.

### WA-067 · Low · Code

- **Description:** Blowing up the menu's sparrow prints an engine error.
- **Cause:** Not traced; likely `HUD._place` run from `unlock_testing` while the HUD is outside the tree in the main menu.
- **Confirmation:** Run: the local browser smoke test (phone) logs `ERROR: Condition "!is_inside_tree()" is true` at `Node::can_process` right after «easter egg: the sparrow blew up».
- **Files and systems:** `src/client/ui/menu_backdrop.gd` `_explode`, `src/client/ui/hud_menus.gd` `unlock_testing`
- **Consequences:** An error line on the phone's console; harmless so far.
- **Recommended fix:** Find which call meets a node outside the tree and guard it.
- **Status:** Open: backlog; first found 2026-11-14 (new); due backlog.
