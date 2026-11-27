# GAME audit: `src/shared/game/` (rules the server decides)

What I read: CLAUDE.md, docs/CONTRIBUTOR_RULES.md, docs/systems/session.md (whole). Code: `placed.gd` (function map
of all 156 funcs; read 228-330, 660-1012, 1780-1822, 1939-1975, 2067-2080, 2174-2260, 2640-2794), `plans.gd` (function map;
read 1-40, 95-114, 308-322, 879-1018, 1276-1365, 1690-1784), `character.gd` (function map; 120-150, 300-580, 625-642,
1020-1081), `body.gd` and `inventory.gd` (function maps; inventory 40-80, 382-400, 905-982), `session.gd` (130-330 whole
tick), save/load parts of `clock.gd`, `territory.gd`, `decay.gd`, `teams.gd`, `fights.gd`, `vitals.gd`, `craft_queue.gd`,
`workshop.gd` (update, cancel, _receive), `warmth.gd` fire_heat, `wildlife.gd` `_decide` outline. Outside the area, only
where the rules are called: `src/server/requests.gd` 170-330 and 561-566, `server_store.gd` 150-200, `server_main.gd`
285-360, `src/client/save_game.gd` 275-305, `src/client/game/props.gd` 125-170, `src/server/player.gd` 205-250,
`src/client/game/character.gd` 140-185. Long functions were measured by script over all 43 files.
Not covered in depth: the `actions_*.gd` chain (only grepped), wildlife move/fight/spawn internals, storms, ice, felling,
skill_set, knowledge, gestures, bot_brain. Nothing was run (no Godot).

---

### GAME-1 · High · Size
- **What:** `placed.gd` is a god object: 2794 lines (115 KB), 156 functions, 15 `is_*` predicates. It holds at least seven
  separate jobs behind one API that 58 files use (414 references outside it).
- **Where:** `src/shared/game/placed.gd` (whole file). It has one section marker (`# --- Lights set down`, :2493).
- **Evidence:** what is inside, by line range:
  (a) model shapes: `read_footprints` :264, `footprint_of_image`, `voxels_of_image`, `turn_voxels`, `open_voxels`,
  `swung_voxels`, `shut_voxels`, `footprint`, `_box_of`, fence boxes (:264-660). These are static and content-derived.
  (b) the registry and saving: `put` :670 (12 positional params), `put_plan`, `from_list` :728, `to_list`, `record` :762,
  `cut_from_list`, `at`, `cell_of`.
  (c) the spawn camp: `start_camp`, `camp_spot`, `_camp_spot` :826-863.
  (d) finding a place to put something: `put_spot` :1286, `_wall_near`, `_wall_spot` :1403, `_wall_cells`, `_across`,
  `_sunk`, `plane_turn`, `_backed`, `_backing`, `_spot_in_front` :2305, `_spot_at`, `_fits`, `_rests`, `_open`, `spot_near`,
  `_free_at`, plus the ghost variants `ghost_spot`, `ghost_move_spot` :1939-1972.
  (e) openings cut into walls: `cut_of` :2002, `opening_spot`, `flip_spot`, `_move_opening` :2067 (75 lines), `_mend`,
  `_leave_ghosts`, `_cut`.
  (f) fires, fuel, rain catchers, melting and spoiling: `put_out`, `light`, `feed`, `fuel_for`, `_burn_fire`, `_catch_rain`,
  `draw_water`, `step` :2640, `melt` :2662, `spoil` :2690.
  (g) doors, signs, graves, beds and seats: `swing`, `walk_open`, `hang_wreath`, `write`, `turn_sign`, `put_grave`,
  `bed_under`, `nearest_bed`, `lying_spot`, `seat_near`.
  (h) lights set down: :2493-2640.
  No earlier audit recorded this. CODEBASE_AUDIT game-4 only removed dead functions from it.
- **Why it matters:** every feature for placed things (signs, openings, graves, wreaths, snowmen) has gone into this one
  file. It is too big to read whole (CLAUDE.md says to grep first above 30 KB), so each change needs a map of it first.
  Search state such as `_ghosts`, `_moving` and `_swap_fences` (GAME-5) is shared across sections that have nothing else in
  common.
- **Proposed refactoring:** split it as a chain of parts, the pattern already accepted (decisions 145/168):
  `placed_shapes.gd` (a, static) ← `placed_store.gd` (b, c) ← `placed_spots.gd` (d) ← `placed_openings.gd` (e) ←
  `placed_fires.gd` (f, h) ← `placed.gd` (g, signals, the public entry). Callers keep preloading `placed.gd`. No change to
  saves or the protocol. Do it in two PRs: first (a) and (d), the biggest and most self-contained, then the rest.
- **Effort:** M. **Risk:** low (moving code only, covered by actions/fences/signs tests). **Confidence:** high.

### GAME-2 · High · Performance
- **What:** every player, every tick, the rules scan all placed things linearly several times. There is no index by cell
  or by chunk. Fence posts are placed things, so a base with hundreds of fences makes each scan hundreds of dictionary and
  `Items.get_item` lookups, at up to 60 ticks a second. In single player this runs inside the phone's browser.
- **Where:**
  - `character.gd:390-391` → `_touch_fire` :543-545 → `Placed.burning` `placed.gd:920`. This runs every tick, because
    `_burn_wait` is 0 except just after a burn, and up to twice (`body.bumped`). Each pass over `things` calls `is_fire(e)`
    (an `Items.get_item`), because `e.lit` is true for every non-fire (`put` :672: `"lit": lit or not rec.fire`).
  - `character.gd:354` → `seat_near` `placed.gd:2701`, every tick while standing, once any seat item exists.
  - `workshop.gd:91` `stations_near` `placed.gd:900`: `center()` and `Items.get_item` for every thing, whenever stations are
    asked (crafting UI, `_can_work`).
  - `placed.at(cell)` `placed.gd:876` (over all things and then all lights) for every placed-thing request
    (`requests.gd:238`, `:562`, `player_link.gd:821`).
  - `walk_open` → `_shut_door_on` `placed.gd:1001`, a scan for each blocked cell a bumping body touches.
  - `Warmth.fire_heat` `warmth.gd:93`, every 0.5 s per player, and inside `Placed.melt` `placed.gd:2662` for each snow
    thing. That makes it snow things × all things every 0.5 s.
- **Evidence:** all of these are `for e in things:` loops with no early filter by distance. `scarers` (`placed.gd:196`,
  kept for wildlife) shows the project already uses the fix, a per-role list kept as things come and go.
- **Why it matters:** the per-tick cost grows with the size of the whole world's buildings, not with what is near the
  player. This goes against the rule "nothing map-sized per frame". The phone is about 10× slower.
- **Proposed refactoring:** keep `_by_cell` (north-west cell → e), like the existing `_fences` dict, and `_by_chunk`
  (chunk key → [e]) up to date in `put` and `_forget`. Also keep role lists like `scarers`: `_fires` (lit and not hearth),
  `_seats`, `_stations`. Then `at()` is O(1), and `burning`, `seat_near`, `fire_heat` and `stations_near` look only at the
  chunks around `p`. Measure with `tools/profile.gd` before and after. No save or protocol change.
- **Effort:** M. **Risk:** medium (index kept in sync on move, `take_up`, `fall_apart`). **Confidence:** high.

### GAME-3 · High · Architecture
- **What:** the session's world state is saved and loaded in four places, each with its own hand-written list of
  sections and its own load order. `Session` itself has no `to_meta`/`from_meta`.
- **Where:** server save `src/server/server_store.gd:187-196`; server load `src/server/server_main.gd:316-352`;
  single-player save `src/client/save_game.gd:291-298`; single-player load `src/client/game/props.gd:140-170`.
- **Evidence:** each lists sky/placed/territory/plans/tame/vessels/ice_holes/decay (the server also teams/fights). The load
  order matters but nothing states it: territory must be loaded before `placed` (placed's `removed` is wired to
  `territory.thing_removed`, `session.gd:145`), and `decay.from_dict` needs `world` set (`decay.gd:397`). The two loaders
  already differ. Only the client loader converts a pre-placement save (`props.gd:160-166`, the `"props"` key). The server
  loader ignores that key and makes a new camp. `props.gd` (a client view module) writes straight into
  `game.session.territory/plans/decay/placed`.
- **Why it matters:** a new session module (the last ones were decay, ice and vessels) must be added in four files. If one
  is forgotten, that state is silently lost in one mode only. Single player and server can drift apart (WA-020 was one such
  case).
- **Proposed refactoring:** add `Session.to_meta() -> Dictionary` and `Session.from_meta(meta, has_save)` in
  `session.gd`, with the load order in one place and the old-save shims there. `server_store`/`server_main` and
  `save_game`/`props.gd` call them. The server-only sections (teams, fights, next_player) are written only when the session
  is a server's, via a flag. Add a test that saves a session, loads it into a fresh one, and compares `to_meta()`. This
  changes the structure (who owns the save), so the owner picks it first. The save format stays the same.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### GAME-4 · Medium · Coupling
- **What:** the contract for the `who` a rule acts on is implicit. The shared base `character.gd` does not declare methods
  that rules call. They exist only in two subclasses with different implementations. Callers sometimes guard with
  `has_method` and sometimes do not.
- **Where:** `held()`, `teleport()`, `overlaps_cell()`, `feet()`, `facing_step()`, `tool()` are defined in
  `src/server/player.gd:210-245` and `src/client/game/character.gd:145-180`, not in `src/shared/game/character.gd`.
  Unguarded calls: `territory.gd:179` `p.teleport(back)`, `placed.gd:953` `who.overlaps_cell(c)`, `plans.gd:882`
  `who.held()`. Guarded calls: `placed.gd:943`, `:1124`, `quality.gd:53`, `wildlife.gd:142`, `wildlife_fight.gd:141,171,222,249,307`.
  Fields read by name: `placed.gd:1772` `who.get("id")`, `who.get("player_name")`; `territory.gd:_id`; `workshop.gd:186`
  `who.get("skills")`.
- **Evidence:** as above. `grep -c 'has_method\|\.get("'` over `src/shared/game/*.gd` gives 463 hits (most are dictionary
  `.get`, but the `who.*` ones are mixed).
- **Why it matters:** a rule cannot be read or tested against `character.gd` alone. A test double or a bot (`server_bot.gd`)
  missing one method causes a runtime error only on that path. The `has_method` guards hide mistakes.
- **Proposed refactoring:** declare the "what the rules ask of the one who acts" methods in the shared `character.gd` as
  stubs that subclasses override (`held() -> String: return ""`, `teleport`, `overlaps_cell`, `feet`, `facing_step`,
  `tool`), plus `id`/`player_name` vars. Then drop the `has_method` guards. Check whether the client character's
  implementations are still reached by shared rules at all (unverified: since S4 the rules run on the server `Player`).
- **Effort:** S. **Risk:** low. **Confidence:** high.

### GAME-5 · Medium · Correctness
- **What:** placement search switches modes by setting instance fields around a call and clearing them after. If a runtime
  error happens inside, the field stays set for good, and later real placements see the blueprint's ghost blocks as solid.
- **Where:** `placed.gd:1939-1943` `ghost_spot` (`_ghosts = ghosts … _ghosts = null`), `:1950-1970` `ghost_move_spot`
  (`_ghosts`, `_ghost_self`), `_moving` (:221, set in opening moves), `_swap_fences` (:214, `put_at`). They are read in
  `_solid` :1974, `_ghost_taken` :1979, `_walled` :1335, `_rests` :2393, `_open` :2406, `_in_open_door` :2415.
- **Evidence:** GDScript has no try/finally, and a runtime error aborts only the current function (CONTRIBUTOR_RULES
  gotcha), so the reset line never runs.
- **Why it matters:** this is a sticky, hard-to-diagnose bug: "can't place anything here" until the server restarts. It
  also makes `placed` unsafe to use for two searches at once. Today that cannot happen, but it is a hidden ordering
  dependency.
- **Proposed refactoring:** pass a small `Spot` context (ghosts, ghost_self, moving, swap_fences) down the search
  functions (`put_spot` → `_fits` → `_solid`…) instead of instance fields. This fits naturally with the `placed_spots.gd`
  part from GAME-1.
- **Effort:** M. **Risk:** medium. **Confidence:** high (pattern verified; no observed failure).

### GAME-6 · Medium · Correctness
- **What:** items silently vanish when the bag is full. Several rules call `who.give(...)` or `inventory.add(...)` and
  ignore what did not fit. A give-or-drop helper exists, but only privately in `workshop.gd`.
- **Where:** `placed.gd:1808` (a door's wreath on `take_up`: the door takes the last slot, so the wreath is lost);
  `plans.gd:981` (the ground or block dug out when building a ghost cell); `fishing.gd:104`, `:115` (the bait given back);
  `actions_water.gd:251` (the skilled angler's extra fish). The helper is `workshop.gd:288` `_receive`: give, then
  `who.lay(...)` the rest.
- **Evidence:** `give` returns how many fit and only nags (`character.gd:627-637`). The callers above discard the result.
- **Why it matters:** players lose things without seeing why. The same bug will be repeated by every new rule.
- **Proposed refactoring:** move `_receive` into the shared `character.gd` as `give_or_lay(id, n, worn, q, text)` and use
  it at the sites above. Add a test: take up a door with a wreath into a bag with one free slot, and the wreath lies at the
  feet.
- **Effort:** S. **Risk:** low. **Confidence:** high for wreath, dug ground and bait.

### GAME-7 · Medium · Layering
- **What:** some land-rights checks live in the request handler, not in the rule. Reach is checked by four different
  helpers.
- **Where:** `requests.gd:254-261` (PROP_FIRE: the `territory.may(..."build")` check before `placed.put_out(e)`; `put_out`
  `placed.gd:2174` takes no `who` at all). `requests.gd:262-267` (PROP_DRINK: the `"chests"` check before
  `placed.draw_water`). Compare `swing`, `write`, `take_up`, `move`, which check territory inside `placed.gd` (:945, :1133,
  :1781, :1876). The reach helpers are `requests.gd:561` `_near` (→ `WorldActions.within_hand`, `actions_base.gd:81`),
  `Placed.in_reach` `placed.gd:1601` (Tools.PLACE_REACH), and `Plans.within_reach` `plans.gd:310` (PLAN_REACH). Most
  `placed` rules (`take_up`, `swing`, `feed`…) do not check reach themselves and rely on `_near`.
- **Evidence:** as quoted. This breaks "a rule takes the one acting as `who`": `put_out` cannot know who acts.
- **Why it matters:** another caller (a bot, the console, a future request) of `put_out`/`draw_water` skips the land
  check. The security rules (`docs/security/`) are then spread over two layers, and a test of the rule alone does not cover
  them.
- **Proposed refactoring:** add `put_out(who, e)` with the territory check inside, and move the `"chests"` check into
  `draw_water`. Keep `requests.gd` to type and bounds checks plus `_near`. Write down in `CONTRIBUTOR_RULES` which layer
  owns reach (the request) and which owns land rights (the rule). Add `security_test` cases for both.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### GAME-8 · Medium · Size
- **What:** `plans.gd` (1784 lines, 78 functions) holds three systems: the blueprint (shapes, draw, replace, earthwork,
  build), ghost things, and the farming mode's marks. Farm marks are stored in the same `cells` dictionary as blueprint
  cells and told apart by string tests.
- **Where:** `plans.gd:1089` `# --- Ghost things`, `:1342` `# --- The farming mode's marks`. `is_mark` `:1362`:
  `v.begins_with("~") or Tools.use_of(v) in ["plant", "sow"]`. `from_list` :1726 special-cases `CUT` and `WORK_MARKS`.
  Long functions: `build` :879 (139 lines), `draw` :322 (107), `shape` :114 (70), `earthwork` :514 (66). Nearly every
  function takes `actions` as its first parameter and reaches through it: `actions.world`, `actions.rules`,
  `actions.can_place`, `actions.territory_allows`, `actions.work`, `actions.skilled`, `actions.build_cell`,
  `actions.cell_swing` (`build` :880-994).
- **Evidence:** as above. `build` also mixes picking the next cell (the sort comparator, :923-938) with doing the work.
- **Why it matters:** a seed id whose tool use is `plant`/`sow` is read as a farm mark wherever `cells` is read. Every
  reader of `cells` must remember to filter with `is_mark`. `build` is hard to change: the order rules come from several
  dated user picks.
- **Proposed refactoring:** move farm marks into their own dict (`marks`) or their own small file `farm_marks.gd`,
  saved under their own key. This is a save change: read the old mixed list once. Split `build` into
  `_pick_ready(who) -> Array` and `_build_cell(actions, who, c)`. Optionally make `plans.gd` a chain
  (`plans_shapes.gd` static ← `plans_things.gd` ← `plans.gd`).
- **Effort:** M. **Risk:** medium (save shape for marks). **Confidence:** high.

### GAME-9 · Medium · Data
- **What:** the two central records are untyped and positional. A placed thing is a Dictionary with about 15 optional keys
  whose meaning depends on the item's flags. A bag slot is a positional Array whose 6th field means either sign text or dye
  id. A third tuple shape exists for crafting materials.
- **Where:** placed thing keys: `placed.gd:183-191` (item, cell, turn, items, lit, fuel, wet, water, melt, by, text,
  grave, open, wreath, cut, plus light records with burnt/light). They are kept in sync by hand in `put` :670 (12
  positional params), `from_list` :728-744 and `record` :762-797. Slot shape: `inventory.gd:42-49`
  `[id, count, worn, contents, quality, text]`. The "text" is a dye id for dyed things (`dye_of` :101). The craft "took"
  tuple `[id, count, worn, quality]` is at `inventory.gd:391`, `craft_queue.gd:46,121-134`, and is read as `s[3]` =
  quality at `workshop.gd:166`, while in a slot `s[3]` is the contents.
- **Evidence:** 157 positional `s[2..5]`/`slot[2..5]` reads outside `inventory.gd` (grep), across server, client UI and net.
  `Inventory.remove` drops text/dye from `took`, so cancelling a job gives back undyed materials (low impact: unverified
  that any recipe takes dyed inputs).
- **Why it matters:** adding a field to a placed thing means changing three functions and the client mirror. A wrong index
  (`s[3]` meaning two different things) gives no error, only wrong data.
- **Proposed refactoring:** add accessor statics and use them everywhere: `Inventory.count_of(s)`, `worn_of`,
  `quality(s)` (exists), `text_of` (exists), `dye_of` (exists). Make `took` use the slot layout, or name it with a
  Dictionary. For placed things, make `record`/`from_list` table-driven (a const list of optional keys with
  their type and clamp) so `put` takes the record dictionary instead of 12 params. No save change.
- **Effort:** M. **Risk:** low-medium. **Confidence:** high.

### GAME-10 · Medium · Performance
- **What:** some session "things" steps go over the whole world's records every 0.5 to 1 s, not only those near players.
- **Where:** `session.gd:266-285` `step_things` (the runner calls it every `THINGS_EVERY` 0.5 s, `runner.gd:19`).
  `Placed.spoil` `placed.gd:2690` (every chest in the world, with a `roof_level` each), `Placed.melt` :2662 (each snow
  thing × `fire_heat` over all things), `actions_farm.gd:632` `grow_fields` (every bed of every chunk each `FIELD_TICK` 1 s,
  71 lines), `Placed.step` :2640 (every light, with `world.chunk_at`/`get_cell`).
- **Evidence:** loops over `things`, `world.fields.keys()` and `lights` with no budget and no spread across ticks. Decay
  already uses an incremental job (`decay.gd:_scan`, `_job`, `_order`), which shows the pattern.
- **Why it matters:** on a long-lived server, or in a big single-player world, each 0.5 s things step grows without limit.
  On the phone that shows up as a periodic hitch.
- **Proposed refactoring:** do `spoil` lazily per container: record the time last spoiled and apply the elapsed days when
  the chest is opened or saved. Spread `grow_fields` over chunks (a cursor, N chunks a tick) the way `decay` does. Give
  `melt` the fire index from GAME-2. Measure first: it is unverified how many beds and chests a real save has.
- **Effort:** M. **Risk:** medium (gameplay timing). **Confidence:** medium.

### GAME-11 · Medium · Size
- **What:** `character.gd` (1080 lines) and `body.gd` (1014) each mix several concerns, and each has one very long
  function.
- **Where:** `character.gd`: lights burning in the hands (:53-130), hazards (`_touch_fire`, `_touch_hot`, `_touch_spines`,
  `_fall` :422-603), weather on the body (`_warm`, `_rain_into_bag`, `_spoil` :477-537), consuming (`eat` :662 69 lines,
  `_drink_vessel`, `wear`), sleep, beds and seats (:731-788), death, sack, grave and respawn (:834-968), and
  save (`to_dict`, which is also the network `state`, `player_link.gd:315`). `update` :336 (68 lines) drives all of it.
  `body.gd`: `_step_cells` :266 (125 lines), plus sailing and rowing (`floats`, `_hull_surface`, `_sail`, `_row`,
  `_sail_wind` :491-598) and the weather pace inside the walking body.
- **Evidence:** function-length scan. The other long functions in the area are `wildlife.gd:119` `_decide` (226 lines, the
  longest; string states `"bait"`, `"bite"`, `"flee"`, `"wander"`, 35 string comparisons across `wildlife*.gd`) and
  `wildlife_move.gd:257` `_move` (102).
- **Why it matters:** the vitals and hazard logic runs every tick for every player and is the riskiest to change. Every
  hazard edit touches the same 68-line `update`. Because `to_dict` doubles as the wire format, a field added for the save
  is also sent to every client.
- **Proposed refactoring:** split `character.gd` as a chain: `character_hazards.gd` (fire, hot, spines, fall) ←
  `character_needs.gd` (warm, rain, spoil, eat, drink, sleep) ← `character.gd` (death, respawn, save). Split `body.gd`
  into `body_sail.gd` (vessel physics) and break `_step_cells` into the stages it already comments. Split `_decide` into
  `_threat`, `_prey`, `_wander` (wildlife). Separate the network `state` from the save `to_dict` only if fields start to
  differ.
- **Effort:** M per file. **Risk:** low-medium. **Confidence:** high.

### GAME-12 · Low · Correctness
- **What:** the clock's save keeps only time and season. The weather and what it leaves on the ground (snow lying, wet,
  puddles, clouds, the current weather and `weather_left`) are not saved.
- **Where:** `clock.gd:516-529` `to_dict`/`from_dict` vs the fields at `clock.gd:155-190` and the full `SNAPSHOT` list
  :532.
- **Evidence:** `to_dict` returns day, time, season, season_clock, leaf_fall, warm_days, soak, shrooms. A reload in
  winter starts with `snow = 0` and the default weather.
- **Why it matters:** players see the snow cover vanish and the weather change on every load or server restart. If this
  is intended, it is not written down (docs/systems/time-weather.md says nothing).
- **Proposed refactoring:** add weather, weather_left, snow, wet, puddles and clouds to `to_dict`, with defaults on read.
  Or record in time-weather.md that weather resets on load. The owner should confirm the intent.
- **Effort:** S. **Risk:** low. **Confidence:** high (that it is not saved); medium (that it is a bug).

### GAME-13 · Low · Coupling
- **What:** `Placed` keeps content-derived tables as `static var` (`sizes`, `middles`, `seats`), and an instance method
  rebuilds them alongside instance tables (`footprints`, `turned`, `opened_boxes`). `opened_boxes` is never cleared on a
  re-read. This is the only `static var` in `src/shared/game/`.
- **Where:** `placed.gd:230-238`, `read_footprints` :264-273 (clears footprints, turned, sizes, middles and seats, but
  not `opened_boxes`, which it fills at :318).
- **Evidence:** as above. Two sessions in one process share `sizes`/`middles`/`seats` through the statics. That is
  harmless while content is global, but each `Placed` (server and client copy) rebuilds the shared statics.
- **Why it matters:** a door kind removed by a hot reload (`Mods.rescan`) keeps its open boxes. The static/instance mix
  hides which state belongs to the world. Everything else in the area is clean for two sessions per process.
- **Proposed refactoring:** move all footprint tables into one static cache in `placed_shapes.gd` (GAME-1), rebuilt once
  per `Content.generation`, and clear `opened_boxes` with the rest.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### GAME-14 · Low · Tests
- **What:** some risky logic has no direct unit test.
- **Where / evidence (grep over `tests/`):** no round-trip test of `teams.to_dict/from_dict`; no test that the server and
  single-player writers save the same session sections (GAME-3); no test of full-bag losses (GAME-6); no test that
  weather/snow survive a save (GAME-12); no test that the search flags reset (GAME-5); no test of `push_on` after a player
  leaves. `wildlife.pushes` is index-aligned to `players` (`session.gd:313-319`, `wildlife_move.gd:496`), and
  `remove_player` shifts the indexes until the next wildlife step. Covered today: `walk_open`, `move_opening`, `cut_of`,
  `melt`, `seat_near`, `draw_water`, `hang_wreath`, `burning` (`actions_test.gd`), `step_walk` (`territory_test.gd:329`),
  `decay` save (`decay_test.gd:98`), `put_grave`/`expire_sacks` (`character_test.gd`).
- **Proposed refactoring:** add these with the fixes above. Each is a few lines in an existing `*_test.gd`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### GAME-15 · Low · Dead code
- **What:** the old-save shims cannot be retired, because the save format never changes version. `WorldStore.FORMAT` has
  been 1 throughout, and each shim instead checks whether a field is present.
- **Where:** `world_store.gd:20` `FORMAT := 1`. Shims: `props.gd:160-166` (the `"props"` save, client only, see GAME-3);
  `inventory.gd:227-234`, `:977-981` (worn things "apart" from the bag); `placed.gd:681-684`, `:735` (an opening with no
  `cut`); `craft_queue.gd:104-107`, `:121` (jobs before serials and quality); `character.gd:268` (a sack with no end).
- **Why it matters:** each shim is a branch that must keep working and is rarely exercised. Without a version number
  nobody can say which saves still need it.
- **Proposed refactoring:** bump `FORMAT` to 2 in the next PR that changes a save, converting format-1 saves in one
  `WorldStore` upgrade step. Delete shims once the owner declares format 1 unsupported. Owner's pick (affects old saves).
- **Effort:** S per shim. **Risk:** low. **Confidence:** high.

### GAME-16 · Low · Coupling
- **What:** minor state and duplication problems.
- **Where / evidence:**
  - `plans.gd:70,912,991` `_last_built` is keyed by `get_instance_id()` and never cleared when a player leaves
    (`session.gd:191` `remove_player` clears only fishing and `_motion`).
  - Gameplay odds use the global `randf()` (`actions_dig.gd:122,142,151` rubble/bonus/finds, `actions_fight.gd:100,198`,
    `character.gd:838`), while other rules use seeded `rng` (`actions_gather.gd:637`, `felling.gd`). The global odds cannot
    be fixed in a test.
  - `Plans.is_fence(id)` (`plans.gd:100`) and `Placed.is_fence(e)` (`placed.gd:380`) repeat the same rule.
  - `Character.find_home` hard-codes the respawn offset from the campfire, `Vector3(2.5, 0.0, 0.5)` (`character.gd:328`).
  - Survival balance numbers are code constants (`vitals.gd` has 49 numeric consts, for example `HUNGER_PER_DAY`, `THIRST_PER_DAY`,
    `FALL_PER_LEVEL`), not mod YAML. That may be intended as engine rules; `docs/balance` treats them as code.
- **Proposed refactoring:** clear `_last_built` in `remove_player` (or key it by `who`); pass the session's rng to dig and
  fight; keep one `is_fence` (`Placed.is_fence_item(id)`); name the offset. The owner decides whether vitals numbers
  should move to a `core` YAML.
- **Effort:** S. **Risk:** low. **Confidence:** high.

## Healthy
- Layering inside the area holds: `src/shared/game/` preloads nothing from `src/client/` or `src/server/`, and the only id
  named in code is core's `core:campfire` (`placed.gd:79`). Code asks for content by role and item flags.
- Static mutable state is nearly absent (only GAME-13). `Session` builds its own Teams, Territory, Decay, Plans, Fights,
  Fishing and Ice per instance, so many sessions per process (tests, single player in process) are safe.
- Most module saves are symmetric and defensive: `territory`, `decay`, `teams`, `fights`, `vitals`, `craft_queue`,
  `inventory` and `character` check types, clamp, canonicalise ids through `Items.canon`/`Crafting.canon`, and drop
  unknown content.
- The session tick order is explicit and documented (`session.gd:229-235`, docs/systems/session.md), with `CATCH_UP` and
  body sub-steps. Wildlife uses throttled looks (`LOOK_EVERY`) and the `scarers` index, and decay has an incremental job.
  These are good models for GAME-2 and GAME-10.
- The `world_actions` ← `actions_*` and `wildlife` ← `wildlife_*` chains are in good order (each part under 710 lines).
- `requests.gd` type and bounds checks (`_fit`, turn and face ranges) are consistent across placed and plan requests.

## Not covered
- The `actions_*.gd` chain (4.7k lines) beyond grep: its duplication with `plans.gd` (the earthwork digging in
  `_dig_out` vs `actions_dig.dig`) is suspected, not verified.
- Wildlife movement, fight and spawn internals, `storms.gd`, `ice.gd`, `felling.gd`, `skill_set.gd`, `bot_brain.gd`.
- Real counts of things, beds and chests in a played save (needed to rank GAME-2 and GAME-10 by measurement).
- Whether the client's `character.gd` rule methods (`held`, `tool`, `feet`) are still reached by shared rules (GAME-4).
