# The world session and the rules of play

Status: ACTIVE (the server is built, stages С1–С7, decision 153; the plan `plan/architecture/server.md`). A
Russian copy: [session_RU.md](session_RU.md).

**Purpose.** One point that holds the world with the rules over it and the characters in it and makes the
tick: what the server node (`src/server/runner.gd`) runs every frame: in the game — under the tree's root
before the client's frame, on a server without a window — up to 60 times a second (`FPS` in
`src/server/server_main.gd`). The session also orders the world: it generates chunks around each player
within a budget and forgets the far ones; the client only builds the meshes of what is made. The rules of
play that the server's host sets for everyone (free building, wear, instant crafting) are a separate object
that the rules read as is.

**Files**
- `src/shared/game/session.gd` — the session: takes the world, the generator, the clock, the rules and the
  things on cells, itself makes `WorldActions`, `Storms`, `Wildlife`; `add_player(who, workshop)` /
  `remove_player(who)` (a character gets the world, the clock and things; beasts see the characters as
  people); `start_wildlife(seed)`; `tick(delta)` = `step_clock` (time and weather; weather is felt at the
  first player while there is no climate by districts) → `step_players` (each character and its workshop, a
  frame up to `CATCH_UP` 1 s is counted whole, the body — in steps of 0.05 s; longer — the rest is lost) →
  `step_things` (a placed light burns down, `Placed.step`) → `step_wildlife` (the beasts on the players'
  screens are looked at — `look_from` by `Character.view_right` / `view_half`, a circle `Wildlife.NEAR`
  without a screen; they walk every step, the others once per 0.1 s) → `step_storms` (the wind around the
  players in turn); `sleep_speed()` — `SLEEP_SPEED` (12) while all live players sleep, otherwise 1: the
  runner (`src/server/runner.gd`) multiplies the tick's `delta` by it, and the night passes quickly;
  `push_on(who)` — what the beasts pushed the player with, taken once (the link sends it as the event
  `push`). The world around the players: `zones()` — each player's chunk and the first respawn point of a
  dead one; `make_chunks(near_us, far_us, reach)` — generates the chunks within `reach` (`reach()`: `ZONE` 5
  or more for the widest screen of the players, `reach_for(view_half)` — half the screen's diagonal in
  chunks + 1, up to `ZONE_MOST` 10) of the zones by a step of the job within a budget (`near_us` while the
  chunk is within `NEAR` 4 of a zone, otherwise `far_us`; at least a step per call), the nearest non-SHAPED
  first with what it needs (`WorldGen.needed`) — the rings are counted around a point ahead of the walking
  player (`_update_leads`: half the path in `LOOK_AHEAD` 1.5 s, no further than `LEAD_MOST` 3 chunks, only
  the chunks within `reach` of its zone), so what is ahead is made earlier than what is behind, — then the
  terrain and trees at the edge; the job lives between calls (`_gen_job`); when everything is made there is
  nothing to scan (`_all_made`) until a zone moves or a chunk is forgotten; `make_chunk(key)` — whole, after
  the current job (the loading screen, tools); `forget_far(n)` — up to `n` chunks farther than `drop()`
  (`reach()` + 4) from all zones (`WorldGen.forget`, the changed ones stay), the queue is built when a zone
  moves; `gen_us`, `work_us` / `take_work()` by kinds («terrain», «saved», «trees», «shapes»);
  `stages_left(reach)` — how many stages are still to do (the loading progress).
- `src/shared/game/rules.gd` — the rules of play: `free_build`, `tool_wear`, `instant_craft`, `free_items`;
  `of(dict)`, `to_dict` / `from_dict`. On the client they are set by the «Testing» page (`Settings.apply`),
  the server will take them from the config.
- `src/server/runner.gd` — the server node («ServerRunner», `PROCESS_MODE_ALWAYS`, `process_priority` −10:
  goes before Main) under the tree's root, not under the client's scene: it survives the scene's `restart()`
  (a server from the menu, С5). In `_process`: the session's steps (the clock always; characters, beasts,
  storms — when `playing`), then `make_chunks` within the budgets `near_us` / `far_us` set by the client, and
  `forget_far`. In single player the tree's pause (the menu) stops the steps but not generation, and that
  goes on (`PAUSE_ZONE` 7); the server sets `pausable = false`. What each step took is `took_us`, generation
  — `spent_us` (`take_spent()` gives it once). It is made and stopped by `local_host.gd`
  ([network.md](network.md)).
- `src/client/main.gd` — creates the rules in `_ready`, the session in `start_world` (when there is a world,
  with its own clock and things on cells) and the host with the server node under `get_tree().root`; in
  `_process` there are no session steps: it takes `host.runner.took_us` into the F3 panel (`perf.add`),
  `host.flush(net)` first thing of the game frame (the tick's events), after
  `chunks.run_jobs(host.runner.take_spent())` it sets the budgets to the node (`_budget_server`:
  `chunks.gen_budgets()`), in `_exit_tree` it stops the host (`host.stop()`) if the node is not `keep`;
  Main's `actions`, `storms` are references to the session's, `clock`, `placed`, `wildlife` — the client's
  copies ([network.md](network.md)).

**Who uses it.** Main, `src/server/runner.gd`, `chunk_streamer.gd` (through `game.world_maker`: the session
by the loop, the generator's copy `remote_gen.gd` through a socket — `make_chunk`, `forget_far` when built
whole, `take_work`, `gen_us`, `stages_left`), `tools/profile.gd` (the steps separately, the server node off),
tests. The session's players are the server's characters (`src/server/player.gd`) brought by `PlayerLink`;
the client reads `game.actions`, `game.storms`, `game.rules` as before, the character, the workshop, things on
cells, the clock and beasts — by their copies, and asks the rules through `game.net` — by protocol requests to
the server inside the game ([network.md](network.md)). Saving and the «Testing» page write into
`session.clock` and `session.placed` (before С4, С5).

**Limits.** The player's body is moved by the client (`player.gd`), not the session: by decision 153 the
server will check the movement with the same `body.gd` and correct it. The node's tick takes the last
frame's input (the client sends `input` after the tick), the tick's events the client reads at the start of
its frame: the copy lags behind the server by a frame. The made chunks the client reads from the shared
world, over the network they will go as messages (С3). Beasts belong to the ground: each made chunk gets its
own by the share `Wildlife.wanted` and its biomes, with the forgotten ground they leave
(`Wildlife._settle_new`, `_leave`), the eaten are refilled by `_refill`. Real weather is the server's service
`src/server/real_weather.gd` on the session's clock ([time-weather.md](time-weather.md)).

**Tests.** `tests/unit/session_test.gd` (`rules`: the dictionary and back, free building; `session`: the tick
moves the time, both characters and both workshops, beasts at both players, the wind in turn, pushes, a
player's leaving; `making`: the player's zone, a step on a tiny budget and the job between calls, the stages
around a zone in the order «its own chunk first», the accounting of work, a chunk whole, forgetting farther
than `DROP` after leaving, no players — nothing to do); `tests/save_test.gd` (the server node under the root
and leaves with the scene); `tests/unit/body_test.gd` (the things' shapes read by the session from models
match the models); `tests/unit/net_test.gd` (copies through the loop).
