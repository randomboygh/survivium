# Audit: UI, main.gd, settings, input, client game, audio, lang (prefix UI)

**What I read.** I read these in full or almost in full: `src/client/main.gd`; `settings.gd` lines 1-110 and 370-1286; `save_game.gd` 197-309; `input/controls.gd` 1-265 and 555-575; `input/build_mode.gd` 1-60, 600-714 and 796-812, 1004-1263; `ui/hud.gd` 370-550; `ui/craft_panel.gd` 365-475; `ui/settings_menu.gd` (constants, `_interface_rows`, `fit`, `_fill`); `shared/content/lang.gd` 95-323; `ui/editor/field_names.gd`; `audio/sound.gd` and `music.gd` (unlock and loop paths); `server/cheats.gd` 25-102; `tools/lang_check.py`; `tests/unit/ui_test.gd` (`run`, gallery).
**What I measured by grep or count.** Every file in `src/client/ui`, `ui/kit`, `ui/editor`, `input`, `game`, `audio`: `game.` chains, `Color(`, `add_theme_*`, `.connect(func`, `remove_child`, `_process`, `KEY_*`, null guards, static vars, function lengths. I also ran `tools/lint.py` (0 problems) and `tools/lang_check.py --strict en,ru` (0 problems, exit 0), plus a script that finds unused keys and checks the FieldNames formula.
**Only skimmed:** `host_screen.gd`, `world_setup.gd`, the `menu_*` chain, `map_view.gd`, `minimap.gd`, `perf_panel.gd`, `death_screen.gd`, `land.gd`, `team.gd`, `trip.gd`, `markers.gd`, `voices.gd`, `nature.gd`, `steps.gd`, the voxel editor, `browser_smoke.mjs`.
**Not opened:** `props.gd` and `creatures.gd` (not in my area), apart from `props.gd` 130-160.
**Could not do:** Godot is not installed, so nothing could be run. Every finding comes from reading the code.

---

### UI-1 · High · Duplication
- **What:** Single player writes and restores the world's save with its own client code. That code is a hand copy of the server's `ServerStore` and `server_main` code, key by key.
- **Where:**
  - Write: `src/client/save_game.gd:275-309` (`_write_world`) and `src/server/server_store.gd:175-198`.
  - Restore: `src/client/game/props.gd:136-160` (`place()`) and `src/server/server_main.gd:317-347`.
- **Evidence:**
  - Both writers list the same keys in the same shape: `"sky"`, `"placed"`, `"territory"`, `"plans"`, `"tame"`, `"vessels"`, `"ice_holes"`, `"decay"`, `"format"`, `"materials"`, `"levels"` and others, each read from the session (`game.session.territory.to_dict()` and `session.territory.to_dict()`).
  - Only the server writes `teams`, `fights` and `next_player`. The client keeps those by `meta.merge(own, true)`, which is the WA-020 workaround.
  - Both readers repeat the same `meta.get(x) is Dictionary/Array` + `from_dict` blocks.
  - The client version also lives in a view module: `props.place()` restores territory, plans, tamed animals, vessels, ice and decay into `game.session`.
  - `docs/systems/session.md:76` calls this transitional ("before С4, С5"). `ServerStore` now exists, but single player was never moved onto it.
- **Why it matters:** A new saved part of the session needs four edits in three folders. Missing the client pair means single-player worlds silently lose that state on reload while servers keep it (data loss). Restore code inside a 3D props view is also invisible to whoever works on saves.
- **Proposed refactoring:**
  1. Put `world_meta(session, info) -> Dictionary` and `restore_meta(session, meta, had_save)` in one shared place (`ServerStore` statics, or `src/shared/world/world_meta.gd`).
  2. Call both from `save_game.gd` and `server_main.gd`. Have `props.place()` only draw what it places.
  3. Better: let single player save through `LocalHost`'s `ServerStore`, so `save_game.gd` keeps only the player's sections.
  4. The save format does not change. The cut changes the structure of the save path, so it needs the owner's pick.
  5. Add a `save_test` check that every key `ServerStore` writes survives a single-player round trip.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### UI-2 · High · Duplication / Correctness
- **What:** The playtest switches ("Тестирование") take effect by two separate code paths, and two bugs have come out of that split:
  - In a world on this device, `settings.gd` writes them straight into server objects.
  - On a server, they go out as `Protocol.CHEATS` and `server/cheats.gd` applies them.
- **Where:**
  - Local path: `src/client/settings.gd:693-766` (`apply`: rules, `session.clock` pins, `host.player.vitals/inventory/skills`) and `settings.gd:911-948` (`set_season/weather/moon/hour`).
  - Remote path: `settings.gd:1044-1059` (`send_cheats`), `settings.gd:1021-1030` (`set_cheats`) and `src/server/cheats.gd:35-94`.
- **Evidence:**
  - Adding one switch, for example `no_hunger`, takes 9 places:
    1. the `var` (335)
    2. `TEST_SAVED` (38)
    3. `SURVIVAL` (43)
    4. `apply` (759)
    5. the `send_cheats` dict (1048)
    6. the `set_cheats` "off" dict (1027)
    7. the setter (1081)
    8. the settings row (`ui/settings_menu.gd:547-548`)
    9. `cheats.gd` `VITALS` (29)
  - The names also differ between the two sides: `no_hunger` here, `"hunger"` (inverted) on the wire.
  - **Bug 1:** `set_cheats(false)` sends a hand-written "back to normal" dict (`settings.gd:1026-1028`) that has no `air_temp`, `wind` or `wind_dir`. `send_cheats` does send them (1051-1052). `Cheats.apply` only touches a key that is present (`_number` returns INF when it is missing, `cheats.gd:98-102`). So after turning cheats off, a pinned air temperature or wind stays on the server's shared clock for every player.
  - **Bug 2:** Both season paths write `clock.season = …; clock.season_clock = 0.0` directly: `settings.gd:914-919` and the `season` block in `cheats.gd:71-75`. Neither goes through `Clock._begin_season` (`clock.gd:335-340`), so a spring set this way does not reset `leaf_fall` (trees stay bare, `sky.gd:514`) and `season_changed` is not emitted.
  - The earlier audit recorded this as **game-m1** (`docs/audit/CODEBASE_AUDIT.md:130`), and `REFACTORING_ROADMAP.md` row 4 lists it as handled by #292. The direct writes are still there, and now there are two of them. The playtest key Z uses the correct `next_season()` (`controls.gd:215`).
- **Why it matters:** Every new playtest switch is a nine-place edit, and the two paths drift apart. Bug 1 is visible to all players on a playtest server.
- **Proposed refactoring:**
  1. Keep one path: build the same `CHEATS` dict locally and hand it to `LocalHost` too (`Cheats.apply(session, host.player, d)` already takes `session` and `who`). Delete the direct writes in `apply()` and `set_season/weather/moon/hour`.
  2. Generate `TEST_SAVED`, `SURVIVAL`, the send dict, the "off" dict (from the defaults, so it can never miss a key) and the settings-menu rows from one table, `SWITCHES := [{key, default, wire, invert, values}]`.
  3. Add a public `Clock.set_season(s)` that calls `_begin_season`.
  4. Add a test: cheats off restores every key that cheats on sends.
- **Effort:** M. **Risk:** low-medium. **Confidence:** high.

### UI-3 · High · Architecture / Size
- **What:** `main.gd` (1212 lines) holds a lot of feature state and per-frame game logic, which breaks its rule: "only builds the scene and runs the frame; new state goes into its module".
- **Where / Evidence:**
  - **Loading progress (state and caption logic, about 140 lines):**
    - `LOADING_HOLD`, `LOADING_SHARE`, `LOADING_WORK` (126-135)
    - `loading_stage`, `_stages_done`, `_stages_count`, `_work_shown`, `_work_since`, `_work_named`, `_stages_total` (289-301)
    - `loading_phase`, `_next_work`, `loading_part`, `loading_fraction`, `loading_progress`, `_loading_stage` (589-680)
    - the "world ready" block of `_process` (773-811)
    - The loading screen (`menu_loading.gd`) reads it back through `game.loading_*`.
  - **Render materials and meshes:**
    - 16 fields (`world_mat` … `tree_mesh`, 244-264) and `_build_materials` (1053-1126, 74 lines of shader-parameter setup), plus `low_variant` and `_material`.
    - Read as `game.<x>_mat` / `game.<x>_mesh` 60 times in 11 files (`chunk_streamer`, `props`, `ice_view`, `plan_blocks`, `sky`, `boats`, `plan_things`, `air_effects`, `water_effects`, `tree_hits`, `shader_warmup`).
  - **Per-frame sync of the character into the body:** `_process` 822-848 sets about 20 fields: `load_scale`, `swim_scale`, `vessel`, `windage`, `flow`, `riding`, `rowing`, `asleep`, `dead`, `bed_head`, `line_at`, `line_bite`, the seat position, others parting.
  - **Feature code:**
    - `_set_off` (736-745) repeats `ActionsBoat._set_off` (`actions_boat.gd:265-268`)
    - `_leave_footprints` with `last_print` and `left_foot` (267-268, 964-973)
    - `_on_spores` (585)
    - the Android back gesture made into Escape key events (936-946)
    - `_report_fps` and `fps_clock` (977-981)
    - `print_debug` (985-991)
  - **Server rules called from the client frame when the world is ready:** `host.player.start_bag()`, `find_home`, `session.start_wildlife(world_seed)`, `host.runner.playing = true` (790-797).
  - **Server budgets:** `_budget_server` writes `host.runner.near_us/far_us` and `host.session.wanted/wanted_only` (702-709).
  - **Long function:** `_process` is 174 lines (748-921).
- **Why it matters:** `main.gd` gets edited for unrelated features (boats, fishing, beds, loading captions), so parallel PRs collide here (compare WA-039). The 60 material reads make every renderer depend on Main.
- **Proposed refactoring (moves inside the client layer; the owner picks the layout):**
  1. `src/client/ui/loading_progress.gd`: owns the stages and captions; Main calls `loading.stage(text)` and `loading.update()`.
  2. `src/client/view/world_materials.gd`: owns the materials and meshes; modules get `game.mats.world`, and so on.
  3. `player.sync_from(character, others, boats, delta)` in `view/player.gd`.
  4. Footprints into `tracks.follow(player)`. Spores into `effects`. The back key into `hud`.
  5. `LocalHost.begin_play(seed, has_save)` for the world-ready server calls.
  6. Budgets into `chunk_streamer` or `LocalHost`.
  7. Target: `_process` under 80 lines, made only of module calls and perf notes.
- **Effort:** M (two or three PRs). **Risk:** medium (order of the frame). **Confidence:** high.

### UI-4 · High · Coupling
- **What:** Every client module gets the whole Main node as `game` and reaches through it deeply. That couples all 85 files to Main's field names and to an implicit build order.
- **Where:** All of `src/client`. Construction is in `main.gd:306-400` and `996-1212`.
- **Evidence:**
  - `game.` is used 2317 times in 85 files. There are 327 chains three deep (`game.a.b.c`) and 17 four deep (for example `game.session.actions.vessels.from_list`, `game.hud.perf.freeze_log.clear`, `game.host.session.players.size`).
  - The most common deep chains:
    - `game.character.inventory.count` (13)
    - `game.settings.values.world_seed` (10)
    - `game.hud.perf.mark` (10)
    - `game.character.inventory.slots` (10)
    - `game.plan_view.things.hold_hole` (6)
  - Modules reach into other modules' private fields: `build_mode.gd:867` `game.controls._ray(pos)` and `bot.gd:84` `game.wildlife._by_id`.
  - There are 252 null guards of the form `game.x != null` or `== null`: `settings.gd` 30, `controls.gd` 16, `chunk_streamer` 15, `camera_rig` 13, `mirror` 13, `mod_reload` 12. They exist because modules are built in different phases (`_ready`, then `start_world`, then `_build_scene`).
  - The build order is implicit:
    - `settings.gd:793-796` documents a bug this order caused: the menu came up at «обычный» size, fixed by calling `size_hud` early (`main.gd:1005`).
    - `creatures.perf = hud.perf` (1168) only works because `_build_ui` runs before `_build_scene`.
    - `character.clock` and `character.placed` are wired by hand (370-371).
    - `link := ServerLink.new(self)` runs in a field initialiser, before `_ready` (203).
  - Modules are built in three different shapes:
    - `X.new(self)`: controls, build, settings, …
    - `X.new()` then `x.game = self`: `team` and `land` at 385-386, `ice_view`, `others`, `sign_labels`, `boats`, `fire_shadows`, `sun_rays`
    - `X.new()` with no `game`, then fields set: `markers`, `tracks`, `creatures`, `cursor`
- **Why it matters:** Renaming or moving any field on Main or on a module breaks distant files. The null guards hide ordering bugs instead of preventing them, and nothing documents the order.
- **Proposed refactoring:**
  1. Give each module a small facade, so callers never go two deep:
     - `character.count(id)` and `character.slots()`
     - `perf` as a Main-owned object passed in at construction
     - `settings.get(key)`
  2. One construction shape: `X.new(game)`, then an explicit `world_ready()` phase called by Main in a listed order, so modules stop null-checking each other.
  3. A lint rule against `game\.\w+\._` and against chains deeper than 3.
  4. Do it file by file, `controls.gd` (193 uses), `build_mode.gd` (166) and `settings.gd` (107) first.
- **Effort:** L. **Risk:** medium. **Confidence:** high.

### UI-5 · Medium · Correctness
- **What:** The playtest keys Z (next season), X (rain on/off) and T (time ×100) work for every player in single player. They are not gated by developer mode (`Settings.testing_unlocked`) or `may_cheat()`, and the docs do not mention them.
- **Where:** `src/client/input/controls.gd:213-224`.
- **Evidence:** `KEY_Z: if game.session != null: game.session.clock.next_season()`, `KEY_X: game.settings.set_raining(...)`, `KEY_T: s.set_time_boost(... FAST_FORWARD)` (100×). Developer mode only hides the test buttons (`hud.gd:128`, `hud_menus.gd:286`). Ctrl+Z is "undo" only inside build mode (180-185), so a plain or Ctrl Z outside build mode changes the season. A grep of `docs/systems` finds no mention of these keys.
- **Why it matters:** A player can change the season or run time at 100× by accident, which breaks crops, decay and survival in their world. It also undermines the meaning of "developer mode".
- **Proposed refactoring:** Gate Z, X and T behind `settings.testing_unlocked and settings.may_cheat()`, and move them into a small debug key handler next to the F3/F4 handler in `hud.gd:383-389`. Document the playtest keys in `docs/systems/ui/maps-settings-debug.md`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### UI-6 · Medium · Architecture
- **What:** Build mode's pointer handling is a state machine kept in untyped Dictionaries of six shapes, plus four ad-hoc timers. The recent building-UX PRs keep adding special branches and flags to it.
- **Where:** `src/client/input/build_mode.gd:604-708` (`start_stroke`), `1004-1110` (`_drag_new`, `_drag_ghost`, `_drag_opening`), `1183-1248` (`release`, `_release_ghost`). Also `controls.gd:80` (`_stroke`), `controls.gd:148-161` and `build_mode.gd:98-131`.
- **Evidence:**
  - `start_stroke` returns six different dict literals:
    - put beside: 630
    - light: 643
    - prop: 657
    - ghost thing: 669
    - new from the bag: 688
    - plan: 702
  - Across build mode and controls there are about 32 distinct stroke keys. Some are read with defaults because only some shapes have them: `s.get("led", false)`, `s.get("lifted", false)`, `s.get("face", -1)`, `s.get("found_turn", s.turn)`.
  - `release` dispatches on `s.has("put")`, then `s.has("ghost_thing")`, else prop (1186-1207).
  - Other state lives on the module:
    - `_tap_wait`, `_ghost_wait`, `_second`, `_dragged`, `_dragged_ghost`, `kept_turns`, `picking`, `replacing`
    - six `_need*` fields
    - two double-tap windows: `DOUBLE_TAP_MS` 180 and `GHOST_TAP_MS` 400
  - `build_mode.gd` carries 22 dated user-request comments (2026-11-2x).
  - Controls and build mode depend on each other: controls refers to `game.build` 26 times, build mode refers to `game.controls` 24 times, including the private `_ray`.
  - The tests drive it through private fields (`save_test.gd:99-314`: `main.build._dragged`, `main.controls._stroke`).
- **Why it matters:** Every new gesture adds a branch and a key that every other branch must ignore correctly. A typo in a key is a silent default, never an error.
- **Proposed refactoring:**
  1. Typed stroke objects (`input/strokes.gd`): `PlanStroke` and `CarryStroke` (kinds: new, prop, ghost, opening), each with `press/drag/second_finger/release`.
  2. `controls` only routes pointer events to the active mode's stroke.
  3. Make `_ray` public as `ray()`.
  4. One double-tap helper (the kit's `two_tap.gd` pattern).
  5. Unit-test the transitions (tap, hold, drag, double tap, second finger) without a scene.
- **Effort:** M-L. **Risk:** medium. **Confidence:** high.

### UI-7 · Medium · Size / Architecture
- **What:** `settings.gd` (1286 lines) mixes five jobs, and `apply()` pushes every setting into about 15 modules on each change.
- **Where:** `src/client/settings.gd`.
- **Evidence:**
  1. Saved player settings: 69 keys in `DEFAULTS` (60-226), with 7 old-key migrations in `load()` (397-428).
  2. `apply()` (693-790): writes into sky, chunks, view, effects (`fx.air`, `fx.water`, `fx.nature`), fire shadows, player, `host.player`, character, Sound buses, Engine, RenderingServer, controls and hud. It has 20 null checks.
  3. 27 playtest switches as plain fields (286-355) with 36 `set_*` setters, most of them `x = v; apply()`.
  4. Developer actions with nothing to do with settings (1113-1286): `go_to_death`, `give_tools`, `clear_land`, `start_test_server`, `join_test_server`, `host_with_bot`, `server_worlds`, `test_mod`, `reset_test_world`, `wipe_all`, `wipe_data`.
  5. The fullscreen JavaScript bridge (818-907).
  - `set_value` calls `apply()` and `save()` on every arrow step of a settings row. That includes `RenderingServer.directional_shadow_atlas_set_size` (773) each time. Whether that is cheap when the size is unchanged is unverified.
  - The settings menu repeats each key twice in getter and setter lambdas: 80 `func() -> int` getters, for example `settings_menu.gd:761-800`.
- **Why it matters:** Settings is a hotspot that is touched by player features, playtest work and dev tools alike. Pushing everything on every change makes `apply()` the place where any new module must be added.
- **Proposed refactoring:**
  1. Split by the chain convention or by module: `settings.gd` (values, load, save, migrations, a `changed(key)` signal), `playtest.gd` (the switch table from UI-2), `dev_actions.gd`.
  2. Turn `apply()` into a table `{key: Callable}`, or let modules read their own keys on `changed`.
  3. In `settings_menu`, add `_switch_row(label, key)` and `_pick_row(label, key, names)` helpers.
- **Effort:** M. **Risk:** low-medium. **Confidence:** high.

### UI-8 · Medium · Duplication
- **What:** The rule for "which items are wall openings" (door, window, hatch, gate) is written out inline six times in the client, in four different variants. One of them disagrees with the shared rule.
- **Where:**
  - shared: `src/shared/game/placed.gd:1920-1922` `is_opening`: `(door or window) and not fence`
  - `src/client/input/build_mode.gd:804`: `(door or window) and not hatch`
  - `build_mode.gd:1119` `cut_cells`: `(door or window) and not hatch`, fence not excluded
  - `build_mode.gd:1149` `shown_where_fits`: `door or window`, which includes hatches and gates
  - `build_mode.gd:619`: `door and fence` (a wicket)
  - `src/client/view/voxel_props.gd:25`: `not hatch and not fence`
- **Evidence:** These are the quoted conditions above. `cut_cells` does not exclude fences, so a gate (door + fence) held over solid cells would compute "holes" (unverified on screen). The comment on `shown_where_fits` ("a door, a window or a hatch, a wicket or a gate") shows the intent is not tied to one rule.
- **Why it matters:** The client preview and the server rule can disagree about what goes into a wall. Each new opening-like item (for example a hatch variant) needs all six places found.
- **Proposed refactoring:** Add `Items.is_wall_opening(id)`, `Items.is_hatch(id)` and `Items.is_gate(id)` (or Placed statics) in `src/shared`, and use them in `placed.gd`, `build_mode.gd` and `voxel_props.gd`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### UI-9 · Medium · Tests
- **What:** The biggest screens have no direct test. The scene tests that do reach them depend on private fields.
- **Where:** `tests/unit/ui_test.gd` (744 lines, 19 tests), `tests/frame_test.gd`, `tests/save_test.gd`.
- **Evidence:**
  - `ui_test.gd` checks kit parts (two_tap, choice_rows/switch rows, window, strip, fading_list), the gallery, the vitals panel, chat lines, PC scales, saved size, kept test switches, map fit and crowns, the sparrow, vibration, fling, updates, coordinates and the last log.
  - Nothing builds `inventory_window.gd` (1206), `craft_panel.gd` (930), `settings_menu.gd` (1672), `host_screen.gd` (868), `world_setup.gd` (670), `land_page`, `team_page`, `person_card`, `character_page`, `level_up`, `farm_bar` or `gesture_wheel`. A grep for their names and class names in `tests/` finds no unit test.
  - The scene tests reach UI and input internals 153 times: `frame_test` 108 (`hud._strip` alone 22), `save_test` 45 (`main.build._dragged`, `main.controls._stroke`).
- **Why it matters:** Layout regressions on a portrait phone are found only by the browser smoke test or by the user (WA-065). Renaming a private field breaks frame_test.
- **Proposed refactoring:**
  1. Add a "screens" test in the style of `_test_gallery` (`ui_test.gd:249-287`): build each window out of the tree.
  2. Fit it to 1280×720, 800×360 and 360×800.
  3. Check that the panel rect is on screen and that `Lang.keys_shown` is empty.
  4. Give the scene tests small public hooks instead of `_fields`.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### UI-10 · Medium · Architecture
- **What:** There is no input-action layer. Keys are hard-coded physical keycodes spread over about 16 files, the game keys are split between two handlers, and there is no gamepad path.
- **Where:**
  - game keys: `src/client/input/controls.gd:164-254` and `ui/hud.gd:370-397` (Esc, F3, F4, C, Enter)
  - menu and list navigation, each with its own WASD and arrow handling: `controls.gd:670-689` (movement), `ui/kit/choice_rows.gd:240-246`, `settings_menu.gd:1648`, `main_menu.gd:218`, `character_page.gd:129-132`, `host_screen.gd:863`
- **Evidence:** `project.godot` has no `[input]` section. Code uses `Input.is_physical_key_pressed(KEY_*)` or `physical_keycode` matches throughout. The only joypad code is one `InputEventJoypadMotion` check (`camera_rig.gd:421`).
- **Why it matters:** Keys cannot be rebound, gamepad support would touch every screen, and the key hints can drift from the real bindings.
- **Proposed refactoring:** Declare InputMap actions, or a static `Keys` table in `src/client/input/`. Put the game's keys in one dispatcher (controls), with hud keeping only the window keys. Have the kit's list navigation use `ui_up`/`ui_down`. This changes the structure, so it needs the owner's pick.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### UI-11 · Low · Duplication / Tooling
- **What:** The content editor's `field_names.gd` is a 368-entry table that can be derived by formula and must be kept in sync with `content_schema.gd` by hand.
- **Where:** `src/client/ui/editor/field_names.gd:6-374`.
- **Evidence:** Every entry is `"<kind>.<field>": ["[field.<kind>.<field>]", "[field.<kind>.<field>.about]"]`. A script checked all 368 and found none that differ. The file exists so that `tools/lang_check.py` (`code_phrases`, a scan for literals) sees these keys and `--write` does not drop them. Kinds repeat the common fields `tags`, `provisional` and `was`. The form itself is already built from the schema (`record_form.gd:2-3`).
- **Why it matters:** A new schema field needs a hand-written entry here. `editor_test._test_field_names` catches a missing one, but only after the fact.
- **Proposed refactoring:** Make `FieldNames.of(kind, field)` compute the keys. Have `lang_check.py wanted()` derive the `[field.*]` keys from `content_schema.gd`. Then delete the table.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### UI-12 · Low · Docs / Duplication
- **What:** The kit doc says all windows use the kit, but half of the big ones still build their own frame and do their own layout. Spacing and colour literals are spread across the screens.
- **Where:** `docs/systems/ui/kit.md:6-7` ("all the game's windows are already moved to the kit") against the code.
- **Evidence:**
  - Only 8 screens use `kit/window.gd`: host, join, sign, gallery, world_list, world_setup, content_editor, voxel_editor.
  - These extend `PanelContainer` or `Control` and have their own `fit()`: `settings_menu.gd`, `inventory_window.gd`, `death_screen.gd`, `map_view.gd`, `person_card.gd`, the main menu. For example `settings_menu.gd:1141-1181`, with literals `2 * 8`, `6` and `TAB_HEIGHT`.
  - Kit-like parts live outside `ui/kit/`: `ui_style.gd`, `tab_row.gd`, `icon_tabs.gd`, `scroll_column.gd`, `drag_scroll.gd`, `text_field.gd`.
  - Outside the kit there are 134 `add_theme_constant_override` calls (`"separation", 6` ×30, `4` ×22, `2` ×12).
  - There are 74 literal `Color(…)` outside `ui_style.gd` and the kit (`editor/slice_grid.gd` 8, `menu_backdrop.gd` 7, `figure_preview.gd` 7, `hotbar_slot.gd` 6, `minimap.gd` 5, `item_icons.gd` 5, `hud_parts.gd` 5).
  - The loop "remove every child and `queue_free`" is written out 10 or more times (for example `team_page.gd:54`, `land_page.gd:79`, `world_list.gd:60`, `settings_menu.gd:330`).
  - By contrast, buttons and labels do go through the kit (235 `Kit.` uses, only 8 `Button.new()` outside it).
- **Why it matters:** This is drift, not breakage. Style and spacing changes need many-file edits.
- **Proposed refactoring:** Correct `kit.md`. Add spacing tokens (`UiStyle.GAP_S/M/L`) and `Kit.clear(box)`. Moving the kit-like files into `ui/kit/` changes paths, so it needs the owner's pick.
- **Effort:** S-M. **Risk:** low. **Confidence:** high.

### UI-13 · Low · Data (translation)
- **What:** Translation status, and the gaps that `lang_check` does not catch.
- **Where:** `tools/lang_check.py`, `content/*/lang/*.yaml`, `src/shared/content/lang.gd:255-268`.
- **Evidence:**
  - `python3 tools/lang_check.py --strict en,ru`: `lang: 3502 phrases, 0 problems`, exit 0. en and ru have 3502 of 3502. es, pt, fr, de, it, pl, tr and uk each have **2318 of 3502** (66%; missing words fall back to English, `lang.gd:112-113`).
  - No Russian or English literal reaches a Label (greps for `.text = "…"` with words and for Cyrillic found none).
  - One unused key: `[inventory]` in core's en. `lang_check` never reports unused keys; only `--write` drops them.
  - `glued()` misses joins of translated pieces: `inventory_window.gd:966` (two sentences joined with `+`), `hud_messages.gd:72`, `person_panel.gd:342`, `inventory_window.gd:1073` (`"%s: %s"`), `gesture_wheel.gd:61` (`"%s (%d)"`). In these the punctuation and order are not translatable (French `" : "`).
  - The scene tests' sweep for missed keys judges only Russian (`Lang.seen` builds a ru table; `Settings.language_override`), while English is the default language.
- **Why it matters:** The language picker offers 8 languages that are a third English. Glued phrases cannot be fixed by translators.
- **Proposed refactoring:** Have `lang_check` report unused keys and treat a `Lang.t(…) + Lang.t(…)` join as glued. Move the joined pairs to keyed templates. Run the key sweep in English too.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### UI-14 · Low · Size
- **What:** Two `_ready` functions build a whole window in one go. `hud._ready` was split for the same reason in #696.
- **Where:** `src/client/ui/inventory_window.gd:184-431` (about 245 lines) and `src/client/ui/craft_panel.gd:147-335` (about 188 lines).
- **Evidence:** Function lengths from `grep -n '^func'`. ROADMAP T9 records the split of `settings_menu._section_rows` and `hud._ready`, not these two.
- **Why it matters:** These are the hardest windows to change safely, and they have no unit test (UI-9).
- **Proposed refactoring:** Split by part: `_build_tabs`, `_build_bag_page`, `_build_bottom`, `_build_chests` and so on, as `hud._ready` was.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### UI-15 · Low · Architecture
- **What:** Static caches outlive scene restarts and are reset from scattered lists. A new cache must be remembered in the right list.
- **Where:** `src/client/main.gd:350-351` (`PixelTextures.forget()`, `MeshFaces.forget()`), `src/client/mod_reload.gd:71-75`, `135` and `147-148` (`Lang.reread`, `VoxelProps`, `ItemIcons`, `Figure`), `item_icons.gd:68` (`UiStyle.forget`), `main.gd:725` (`Lang.drop`).
- **Evidence:** There are 133 `static var` in `src/client` (`server_link` 12, `ui_style` 11, `tree_sprites` 10, `pixel_view` 10, `figure` 10, `start_times` 9). Restarts (`main.gd:422-426`, and 519-523 for other bundles) depend on these hand-picked resets.
- **Why it matters:** A stale cache after a restart with other bundles is the kind of bug that appears only on servers with other mods.
- **Proposed refactoring:** One `client/caches.gd` with `forget_all()` (static, no autoload), called on restart and in `forget_files`.
- **Effort:** S. **Risk:** low. **Confidence:** medium.

### UI-16 · Low · Duplication
- **What:** Each screen decides "portrait", "narrow" or "phone" by its own rule.
- **Where:** `ui/hud_layout.gd:57` (`size.x < size.y`), `ui/world_setup.gd:436` (`screen.x < screen.y`), `ui/editor/voxel_editor.gd:309` (`screen.x > screen.y * 1.15`), `ui/settings_menu.gd:1150-1151` (a two-column width rule), `ui/build_bar.gd:250` (`COLUMNS_PORTRAIT`), `ui/host_screen.gd:314` (`phone := not OS.has_feature("pc")`).
- **Evidence:** These are the quoted expressions. "Narrow" or "wide" appears in 20 UI files (28 times in `inventory_window.gd`).
- **Why it matters:** A screen size between the rules lays screens out inconsistently.
- **Proposed refactoring:** `UiStyle.portrait(screen)` and `UiStyle.columns_for(width, row_width)`, used everywhere.
- **Effort:** S. **Risk:** low. **Confidence:** medium.

### UI-17 · Low · Data
- **What:** `ui_icons.gd` (1386 lines) is already pure data, but there is a second source of UI pictures alongside it.
- **Where:** `src/client/ui/ui_icons.gd:9` (`const ICONS`, 126 ASCII-pixel icons; `ui_style.gd` extends it) and `assets/ui/*.png` (21 files, loaded by `item_icons.gd:58` and `ui_style.gd:287`).
- **Evidence:** "sleep" exists in both (`ICONS.sleep` and `assets/ui/sleep.png`). 16 icon names are only built by prefix (`g_*`, `filter_*`, `change_*`), so a name grep cannot tell whether they are used.
- **Why it matters:** The cost is small. The ASCII form is easy to review in diffs and costs nothing at load time; turning it into PNGs would lose that. It matters only if mods should add UI icons.
- **Proposed refactoring:** Keep `ui_icons.gd` as it is. Note in `docs/systems/ui` which source holds which kind of icon. If mods need icons, move `ICONS` to a data file read through `Content`.
- **Effort:** S. **Risk:** low. **Confidence:** medium.

---

## Healthy
- **Audio:** Nothing sounds before the first input. `Sound.unlocked` (`sound.gd:69`, `230-236`) gates `play`, the loops (`l.want if unlocked`, 508), loading and music (`sound.gd:475-476`). There are 5 loops (wind, rain, hail, blizzard, crickets) and 2 spots (water, fire), plus the music pad. The buses are made only if missing, with the web caveat documented (`sound.gd:134-146`).
- **Lang:** `Lang.f` and `Lang.line` work with keys, with English fallback in the table (`lang.gd:103-116`). `lang_check` checks format order per language. en and ru are complete, and no Cyrillic or English literal reaches a Label.
- **Craft and inventory refresh:** Changes are batched with dirty flags (`craft_panel.gd:368-461`: `refresh()` marks dirty, cells are cached by recipe id and made a few a frame). The HUD's per-frame work is throttled (`hud.gd:479-549`: clock every `CLOCK_EVERY`, the rest every `STATE_EVERY`). Settings values are polled every 0.5 s and updated in place (`settings_menu.gd:1117-1138`).
- **Build mode reuses the shared rules for placement** (`Placed.put_spot`, `ghost_spot`, `opening_spot`, `in_reach`, `Plans.within_reach`: `build_mode.gd:1071`, `1100`, `1131-1141`) instead of re-implementing them. Only the item-kind predicates (UI-8) are duplicated.
- **Signals and leaks:** UI windows connect bound methods to long-lived `game.*` signals (29 such connections), which Godot disconnects when the node is freed. The 69 `.connect(func` lambdas all go to signals of the window's own child controls, so none hits the documented self-capture cycle. `.free()` is used only twice, on nodes already taken out of the tree.
- **Kit adoption for controls:** 235 `Kit.` uses, only 8 raw `Button.new()` outside the kit.
- **The content editor builds its forms from the schema** (`record_form.gd`) and checks values with `ContentEdits.check`, as the loader does. Only the names table duplicates the schema (UI-11).
- **`lint.py`:** 4317 files, 0 problems.

## Not covered
- `props.gd` and `creatures.gd` (another area), except the save-restore block in UI-1.
- The `menu_*` chain, `host_screen.gd`, `map_view.gd`, `minimap.gd`, `perf_panel.gd` and `death_screen.gd` were only skimmed. They may hold more literal-style or rebuild cases than the counts above show.
- The real cost of `RenderingServer.directional_shadow_atlas_set_size` on each `apply()` (UI-7) is unverified and needs a profile.
- Nothing was run (no Godot): the on-screen effect of `cut_cells` for gates (UI-8) and the leaf-fall effect of a season set by playtest (UI-2) are inferred from the code.
- `browser_smoke.mjs` and `view_test.gd` were not reviewed in depth.
