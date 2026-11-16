# Open issues

The problems found by the weekly audits that are not fixed yet, the most urgent first. Each audit
adds the new ones, checks the old ones again, closes those fixed and changes a priority when there is
a reason; the history of each status stays in the weekly reports ([INDEX.md](INDEX.md)).

Last checked: 2026-11-14 ([WEEKLY_AUDIT_2026-11-14.md](WEEKLY_AUDIT_2026-11-14.md)), at commit
`b35d371` with that audit's fixes in the working tree. The fixes went into `main` on top of `e395528`: of the
four pull requests merged in between (#577–#580), #579 and #578 reach WA-031 and WA-043, noted there.
Closed since: WA-031 (#579, both main runs after it green), WA-040, WA-041, WA-042, WA-043, WA-045 (#583),
WA-048 (`balance_report --check` in CI and `run_all.sh`), WA-028, WA-029, WA-054, WA-055, WA-056 (#585),
WA-012, WA-013, WA-014, WA-015, WA-016, WA-017, WA-019, WA-022 (#587; WA-018 in part),
WA-024 (#586: `src/client/net/server_link.gd`, no forwarding left on Main),
WA-027 (the twelve uncalled functions deleted; the palettes' filters of the build and farming modes stay: kept with the player and tested, waiting for their buttons),
WA-026 (`work_mode.gd` under the build and farming modes, `bot_brain.gd` under the two bots, the server's roles used directly).
WA-049, WA-050 (the owner picked option A for each), WA-064 (the owner's playtest: the numbers kept).
WA-021 (#584), WA-020, WA-023, WA-057 (#596).
WA-033, WA-035, WA-036, WA-037, WA-038, WA-062, WA-063 (#589, checked in the code on 2026-11-15: the mods' files are stepped 12 a frame while the game is in front, fires are kept in a list, the haze skips its scan, `UiStyle.forget`, `Server._prune`, far animals left out of snapshots, the bag lays out only itself).
WA-030 (the owner picked the YAML mark: a creature field `menu`, `AiRules.menu_species`), WA-051 (`quality: 0` for building and swimming).
WA-018 (the owner, 2026-11-16: the password stays in `server.cfg` as it is; a hash would need typing it at each start, as the host and the bots join with it).
WA-052 (the owner picked "move now": vessels' `seats`/`board_swing`, seeds' `sow_swing`, cans' `water_swing`, creatures' `tend_swing`, trees' and bushes' `seeding`/`seed_reach`/`seed_tries`, trees' `seed_room`, biomes' `grass_back`; defaults equal the old constants).
WA-058 (the owner, 2026-11-15: keep ws:// on a local network, TLS only through the tunnel), WA-059 (the owner: no player accounts).
WA-025 (#696: `settings_menu._section_rows` one function per tab, `hud._ready` eight build steps, `land_layout._layout_row` two passes `_water_row` and `_cover_row`, the layout byte-identical and as fast on a bench).
WA-060 (checked 2026-11-15 on the `main protection` ruleset: a pull request and the checks lint, checks, tests, progress (hunting), progress (other), frames, export, pc, android are required).

| Critical | High | Medium | Low | All |
|---|---|---|---|---|
| 0 | 0 | 5 | 7 | 12 |

Statuses: «needs plan» — the fix touches what the rules say to plan first (architecture, protocol,
saves, data formats, balance formulas); «user decision» — a choice of the owner's; «owner action» —
a repository setting or a step in GitHub; «playtest», «needs phone data» — waits for playing or
measuring on the phone; «backlog» — small, done when the area is next touched. The due dates are
recommendations.

### WA-032 · Medium · Performance

- **Description:** An idle frame leaves thin headroom.
- **Cause:** Idle is 0.96–1.20 ms against the 1.25 ms floor on slow CI runners, up about 10–20% from 0.9–1.0 ms on 2026-11-04; night 1.35–1.57 ms against 2.0.
- **Confirmation:** CI `frames` logs (runs 43259077560 … 43516965633).
- **Files and systems:** `tests/frame_test.gd`; the player part (0.35–0.42 ms) is the largest
- **Consequences:** By the project's 10× rule a phone spends about 10 ms of 16.7 doing nothing.
- **Recommended fix:** Profile the player part on a phone (stats panel, F3) before changing code.
- **Status:** Open: needs phone data; first found 2026-11-14 (new); due 2026-11-27.

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
- **Status:** Open: owner action. Checked 2026-11-15: the `main protection` ruleset requires the checks but `strict_required_status_checks_policy` is off, so a branch need not be up to date (a personal repository has no merge queue); threads rebase before merging by hand; first found 2026-11-14 (new); due 2026-11-20.

### WA-061 · Medium · Performance

- **Description:** `progress_test` shows 2–6 s "browser" frames after a far teleport.
- **Cause:** Not explained.
- **Confirmation:** No fix commit since stage 5.
- **Files and systems:** `tests/progress_test.gd`, the world's streaming
- **Consequences:** A real teleport or join may hit the same cost.
- **Recommended fix:** Find the cause (see WA-034).
- **Status:** Open: needs plan; first found 2026-11-14 (stage 5); due backlog.

### WA-065 · Medium · Process

- **Description:** The phone checklist that closes stage 1 is not confirmed.
- **Cause:** 18 items in `plan/backlog.md` wait for the user's phone.
- **Confirmation:** `plan/backlog.md` «Проверить на телефоне».
- **Files and systems:** the whole game on a phone
- **Consequences:** Stage 1 behaviour on a phone is unconfirmed while stage 2 goes on.
- **Recommended fix:** The user goes through the list on the phone.
- **Status:** Open: user action; first found 2026-11-14 (stage 1); due backlog.

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
