# NET audit: server, protocol, client net layer

**What I read.** All of `src/server/server.gd` (1271), `requests.gd` (623), `player_link.gd` (854), `server_store.gd`,
`content_host.gd`, `tunnel.gd`, `test_commands.gd`, `cheats.gd`, `real_weather.gd`. The parts of `player.gd`
(`take_input`, `_take_claim`, `in_hands`), `server_main.gd` (start, renew/_swap_world, _open_world, _process) and
`config.gd` (fields, args) that matter here. All of `protocol.gd` except the 147 kind constants. On the client:
all of `local_host.gd`, `socket.gd`, `connection.gd`, `mirror.gd`, plus `remote_gen.take_chunk`, `mod_fetch._take`,
`mod_cache.store`, `server_link._on_socket_closed`, the chat display (`chat_box.hear`, `Lang.written/text_of`) and
`settings.gd` where it reaches `game.host`. Docs: `docs/security/NETWORK_SECURITY.md`, `SECURITY_REMEDIATION_REPORT.md`,
`network/server.md` (save part). Tests: I only counted which `Protocol.*` kinds `security_test.gd` and
`server_test.gd` use; I did not read them in full. Earlier audits: I grepped `CODEBASE_AUDIT.md` net-1..net-17.

**Request handlers checked** (`Requests._rule`, all 70 branches): DIG, PLACE, FRONT, GATHER (dict: drop/tree/bush),
PICKUP, VESSEL_TAKE, VESSEL_LAUNCH, PLANT, PLANT_AT, EAT, THROW, PROP_PUT (both forms), PROP_PUT_AT (4 forms),
LIGHT_PUT, PROP_TAKE, PROP_MOVE (both), PROP_FIRE, PROP_DRINK, PROP_OPEN, SIGN_WRITE, GESTURE, SIGN_TURN, PLAN, MEND,
BUILD, PLAN_CLEAR, PLAN_TURN, PLAN_UNDO/REDO, PLAN_THING, PLAN_THING_MOVE/TAKE, FARM (`Plans.mark`), FARM_WORK,
FARM_CLEAR, PROP_DESTROY, CRAFT (both; `Workshop.start` loop bounded by the queue), CRAFT_FREE, GIVE_ALL,
CRAFT_CANCEL, CRAFT_CANCEL_ALL, CRAFT_PAUSE, WEAR, TAKE_OFF, SLEEP, LIE_IN, SIT_ON, REPAIR, REDYE, BAG_PUT, BAG_MOVE,
BAG_ALL, SORT, BAG_DESTROY, CHAT, TEAM_INVITE/ACCEPT/DECLINE/LEAVE/KICK/NAME/CHAT, LAND_PAINT/RIGHTS/COLOR (`set_rights`
clamps 0..255), AI_DEBUG, CHEATS (`Cheats.apply`, every value clamped), MOD_PUT, FIGHT_BRAVE, REVIVE, PREPARE.
**Other messages:** HELLO (`_hello`, `_refusal`), BYE, INPUT (`take_input`), MOD_LIST, MOD_FILES (`_mods_asked`,
`ContentHost.ask/pieces`), console and chat commands (`command`, `COMMANDS`, `_on_chat`), `/test` (`TestCommands`).
**Client side:** every branch of `Mirror._on_event`, CHUNK decompress, MOD_DATA pieces, close reasons, `?server=`.

**Not covered:** `server_bot.gd`, `playtest_host.gd`, `test_mod.gd`, `mod_put.gd`, `updates.gd`, `server_list.gd`,
`remote_wildlife.gd`/`remote_placed.gd` beyond their callers. I did not read the shared rules each handler calls in
depth, only where the server-side bound lives (reach, `take_slot`, `pick_up`, `mark`, `set_rights`). Nothing was
run, so all timing is reasoned from loop counts, not measured.

---

### NET-1 · High · Correctness
- **What:** The server has no backpressure toward slow clients. It ignores every `put_packet` result. A chunk counts as
  "sent" even when its frame was dropped, so a client on a slow link silently loses deltas and chunks and its copies
  drift for good.
- **Where:** `src/server/server.gd:304-306` (flush), `:868-870`, `:1036-1038`; `src/server/player_link.gd:32`
  (`CHUNKS_PER_FLUSH := 2`), `:477-479` (`_sent[key] = true` right after appending the CHUNK); `server.gd:249-250`
  (`outbound_buffer_size = BUFFER` 4 MB, `max_queued_packets = 1024`).
- **Evidence:** `grep put_packet src/server` finds 12 calls and none checks the return value.
  `get_current_outbound_buffered_amount()` is read only for the mods' feed (`server.gd:266`), never for game events.
  `flush()` runs every frame (`server_main.gd:381`, `Engine.max_fps = 60`), so up to 120 chunks a second go to a
  joining player whatever the link can carry. A join pushes one ANIMAL event per animal in the world plus PROPS,
  PLANS and VESSELS in a single flush (`player_link.gd:367-375`), against a server queue limit of 1024 packets.
  When the 4 MB buffer or the packet limit is full, the WebSocket peer refuses the packet with an error code, which
  is thrown away.
- **Why it matters:** The players most exposed are phone players on mobile data, the platform the project targets.
  A lost CHUNK leaves a hole the server never fills again: `_sent` says the client has it, and it is resent only
  through `_again`, when its looks change. A lost PROP_GONE, CELLS or CHEST event leaves stale state until a full
  resync. Nothing logs it.
- **Proposed refactoring:** (1) In `Server.flush`, before `link.flush()`, read the peer's buffered amount. Above a
  high-water mark (for example 1 MB), skip that player's world streaming for the frame: pass a `budget` to
  `PlayerLink.flush`, so `_world_events` sends 0 chunks, SNAP/PEOPLE are skipped and only the dirty-flag state
  waits. (2) Check `put_packet`. On a failure, call `link.rejoin()` (full resync next flush) or kick with "too slow".
  (3) Tie CHUNKS_PER_FLUSH to bytes per second instead of chunks per frame. Protocol unchanged.
- **Effort:** M. **Risk:** medium (join pacing changes). **Confidence:** high on the code; the peer refusing
  packets when full is standard Godot `WebSocketPeer` behaviour.

### NET-2 · High · Security
- **What:** Anyone can block new players from joining by holding a few silent connections open. The per-address
  limit on connections without a hello also applies to `127.0.0.1`, so behind the Cloudflare tunnel, where every
  connection comes from that address, 4 idle sockets refused every 10 s shut out all newcomers. Without a tunnel,
  16 global slots allow the same slowloris from 4 addresses.
- **Where:** `src/server/server.gd:61-64` (the comment says "only the first counts for them"),
  `:243-246` (`_pending(peer.address) >= PENDING_PER_ADDRESS` with no `_local` exemption), `:279-284`
  (`HELLO_WAIT` 10 s, also for `STATE_CONNECTING`). Contrast `:953`, where the fetching limit does exempt
  `_local(peer.address)`.
- **Evidence:** A TCP connect that never finishes the WebSocket handshake counts as pending for 10 s. A fifth
  connection from the same address, which for a tunnel means anyone, is closed at once and logged at most once
  per 10 s (`flag` throttle).
- **Why it matters:** The tunnel is the documented way to play over the internet, and this denial of service needs
  no password and no account. The accepted item "limits by address behind a tunnel are shared" was about password
  lockout, not about refusing every new connection.
- **Proposed refactoring:** Exempt `_local` from `PENDING_PER_ADDRESS`, as `FETCHING_PER_ADDRESS` already is. Cut
  `HELLO_WAIT` for `STATE_CONNECTING` to 2-3 s. When `PENDING_MAX` is reached, close the oldest pending connection
  instead of refusing the newest. If the tunnel can pass the real client IP (`CF-Connecting-IP`), use it for
  per-address limits; that needs the handshake headers and an owner's pick. Add a `security_test` that opens 5 raw
  TCP sockets from localhost and checks that a sixth client still gets in.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-3 · High · Performance
- **What:** Every request message triggers a full `PlayerLink.flush()` for its sender, on top of the per-frame flush.
  Flush does work that grows with the zone and with the world: a full ring scan of the zone, the `_sent` sweep, and
  `Territory.used()` over all claims. A client may send 300 messages a second (`MSG_RATE`), so a player can
  multiply the server's per-player cost by about five without breaking any rule. Some unpaced requests also turn
  into full-state broadcasts to every player.
- **Where:** `src/server/server.gd:866-870` (every reply runs `link.flush()`); `src/server/player_link.gd:466-480`
  (ring scan), `:481-489` (sweep of `_sent`), `:337` (`territory.used`/`budget` every flush,
  `src/shared/game/territory.gd:204-209` loops all claims); `requests.gd:449-454` (LAND_RIGHTS, LAND_COLOR not
  PACED) → `claims_changed` → every link's `_claims = true` (`player_link.gd:561-562`) → full `claims_view()` to every
  player on the next frame; `requests.gd:472-494` (REVIVE/PREPARE while dead) → `Character.find_respawns`
  (`character.gd:920-945`), a loop over every placed thing in the world, unpaced.
- **Evidence:** The ring loop iterates the whole `(2r+1)²` square for each ring r and keeps only the border
  (`if maxi(absi(dx), absi(dz)) != r ... continue`). Once every chunk is sent, nothing breaks the loop early
  (`n` stays 0), so each flush walks Σ(2r+1)² cells: 286 at the default reach 5, 1771 at `ZONE_MOST` 10 (the
  client sets the reach through `view_half` up to `VIEW_MAX`). It does this for up to 3 homes, then sweeps up to
  (2·14+1)² = 841 `_sent` keys. An invalid request such as `["x", seq, []]` still returns a reply and so still
  flushes. Recorded as **net-7** ("`_world_events` re-scans the zone each flush", CODEBASE_AUDIT), deferred in
  REFACTORING_ROADMAP step 5; still open, and the per-request flush makes it reachable on purpose.
- **Why it matters:** Server CPU grows as players × (frame rate + message rate) × reach³. A single client toggling
  LAND_COLOR can make the server send the full claims list to every player 60 times a second.
- **Proposed refactoring:** (1) In `_world_events`, walk only the ring border (8r cells). Skip the ring search and the
  forget sweep entirely while the home chunk, the reach and the set of newly SHAPED chunks are unchanged (a dirty
  flag set from `Session` chunk-ready and `who.moved`). (2) After a request, send only the outbox and the dirty-flag
  state, not the world streaming, SNAP or PEOPLE: split `flush()` into `flush_events()` and `flush_stream()`.
  (3) Cache `Territory.used(id)`, invalidated on `claims_changed`. (4) Rate-limit LAND_RIGHTS, LAND_COLOR, TEAM_NAME and
  GESTURE (a cooldown like `_chat`, or add them to PACED), and cache `find_respawns` until `placed` or `teams` change.
- **Effort:** M. **Risk:** low. **Confidence:** high on the loop counts; per-iteration time is not measured.

### NET-4 · High · Performance
- **What:** Every player who leaves (lingering ended, kick, a goodbye on their own land) triggers a whole world save.
  Any player can repeat this by reconnecting with their key and sending BYE while standing on their own land
  (linger 0). Independently, the 10 s autosave serialises the whole `world.json` (every placed thing with chest
  contents, plans, territory, decay) in one frame, with no dirty check.
- **Where:** `src/server/server.gd:1230-1236` (`_forget` → `store.save(self)`), `:852-855` (BYE sets linger to
  `linger_of`), `:1224-1225` (0 at home); `src/server/server_store.gd:97-134` (save: all unsaved chunks + all players
  + `_world_meta`), `:174-198`; `src/shared/world/world_store.gd:231` (`JSON.stringify(d, "\t")`).
- **Evidence:** The header of `server_store.gd:13-14` and `docs/systems/network/server.md:139` say a leave saves
  "that player's record alone"; the code saves everything. This is how **net-5** (leaving player saved outside
  the snapshot) was fixed: the fix traded correctness for a full save on every departure.
- **Why it matters:** It breaks the rule "nothing map-sized in one frame". A long-lived world's `world.json` grows
  with every building, so the autosave hitch grows with the world. The reconnect loop needs only a known key, which
  `NEW_PLAYERS` does not limit, and turns into disk and CPU load.
- **Proposed refactoring:** (1) In `_forget`, write only that player's record plus the chests they touched. Simpler:
  set a "save soon" flag that the autosave honours at most once every N seconds. Consistency holds if the player's
  file and `world.json` are written in the same snapshot, so defer the leave save to the next snapshot and keep the
  departed player's record in memory until then. (2) Track dirty sections (placed, plans, teams, territory) and
  skip unchanged ones, or move `world.json` to per-section files. (3) Drop the "\t" indent for server saves. (4) Fix
  the two docs. Touches saves; the format stays compatible if only the timing changes.
- **Effort:** M. **Risk:** medium (save consistency). **Confidence:** high (code); the hitch size is not measured.

### NET-5 · Medium · Correctness
- **What:** `PlayerLink.rejoin()` resets the "send again" flags one by one and forgets `_holes`. A player who
  reconnects to a character that is still in the world (a page reload, another device) never gets the ice holes
  until the ice changes again. The deeper cause: the list of what a new connection needs is duplicated between
  the field initialisers (`player_link.gd:66-115`) and `rejoin()` (`:217-251`), kept in sync by hand.
- **Where:** `src/server/player_link.gd:74` (`var _holes := true`), `:217-251` (`rejoin`, no `_holes`),
  `:385-387` (ICE_HOLES sent only when `_holes`); `src/client/net/mirror.gd:120-126` (the client's world copy gets
  holes only from ICE_HOLES); `src/shared/game/ice.gd:148-152` (`take_list` clears and refills).
- **Evidence:** `grep -n '_holes' player_link.gd` finds only lines 74, 160, 191, 385-386 and 681-682. The client
  restarts its scene on rejoin (`server_link` → `game.restart`), so its world copy is empty.
- **Why it matters:** The world looks different to this player than to the others (holes where they can fall
  through), which no test catches. Every new event with a dirty flag carries the same trap.
- **Proposed refactoring:** Move every per-connection "what the client has" field into a `ClientView` inner class.
  `_init` and `rejoin` both do `view = ClientView.new()` so the two lists cannot drift. Add a `server_test` check that
  a client rejoining with its key gets the same set of event kinds as a fresh join.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-6 · Medium · Security
- **What:** Any player over a socket may come back to life where they died, next to their death sack, instead of at
  a respawn point. The game's own client offers this only with the playtest switch `revive_at_death`.
- **Where:** `src/server/requests.gd:472-478` (REVIVE), `:498-509` (`_revive_at` returns `at` when it is within
  `REVIVE_NEAR` of `death.at`, with no `may_cheat` check), `:483-486` (PREPARE, same path);
  `src/client/ui/death_screen.gd:291-293` (offered only `if game.settings.revive_at_death`);
  `src/client/settings.gd:37` (`revive_at_death` is in `TEST_SAVED`, the playtest switches).
- **Evidence:** The client learns where it died from the YOU event (`death.at`). `NETWORK_SECURITY.md` ("revive
  ... or where they fell") documents the server rule, so the doc and the client disagree.
- **Why it matters:** A crafted client skips the walk back from the fire and recovers its sack at once, which
  defeats the death penalty on PvP servers. The earlier **net-3** fixed "revive the living, anywhere" but left this.
- **Proposed refactoring:** In `_revive_at`, accept the death spot only when `may_cheat or not paced`; otherwise
  snap to the nearest respawn point. Update the doc and add a `security_test` case. This is a game-rule decision,
  so it needs the owner's pick.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-7 · Medium · Security
- **What:** What a player holds, as their own client claims it, is forwarded unchecked to every other player
  nearby. PEOPLE carries the raw `hands` from INPUT, not the checked `in_hands()`. A crafted client can show itself
  holding any item, including a light the others' clients render, and push arbitrarily long strings, up to the
  256 KB frame, into every nearby client 20 times a second.
- **Where:** `src/server/player.gd:113` (`hands = [str(args[3][0]), str(args[3][1])]`, no length cap or id check),
  `:179-189` (`in_hands` filters by the bag, used only for rules); `src/server/player_link.gd:517` (`p.hands.duplicate()`
  into PEOPLE); `src/client/view/others.gd:315-318`, `:390-393` (hands drive the sprite and the lights).
  Related: `player.gd:126` (`work[1]` length and `args[16]` unbounded, also forwarded at `player_link.gd:518`).
- **Evidence:** As quoted. `work[0]` is cut to 32 characters; `hands` is not cut at all.
- **Why it matters:** It lets a player show tools and lights they do not have, adds a bandwidth and memory cost
  on every receiver, and contradicts the doc's "the hands — only what is in the bag" (S-02 fixed this for rules,
  not for what others see).
- **Proposed refactoring:** Put `in_hands()` into PEOPLE, cut `hands` strings to the id length at
  `take_input`, and clamp `work` length and count. Add a `security_test` case.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-8 · Medium · Coupling
- **What:** Who may run a command is decided in four places that must agree, and the roles are recomputed with
  several SHA-256 hashes on every message.
- **Where:** `src/server/server.gd:95-102` (`COMMANDS`), `:639` (`_on_chat` lets non-hosts through for `/test` on a
  playtest server), `:432-433` (`command` "test" re-checks), `src/server/test_commands.gd:61-69` and `:87-88`
  (third and fourth checks: world/new/mod need the owner, "stop" needs the owner); `server.gd:860-865` (`_take`
  calls `is_host` twice and `may_author` once per message; each `role_of` → `kept(key)` → `sha256_text`).
- **Evidence:** `"test": ROLE_PLAYER` in the table only means "go on and ask TestCommands". `/test stop` follows
  its own role rule, separate from the table's `"stop": ROLE_OWNER`.
- **Why it matters:** A new `/test` subcommand or a role change has to be made in three files. One missed check
  becomes privilege escalation on non-playtest servers. The per-message hashing is wasted CPU, about 4 hashes per
  message at up to 300 messages a second per player.
- **Proposed refactoring:** One table `{command or "test sub": min_role, min_role_on_playtest}` checked once in
  `Server.command`; TestCommands only does the work. Cache `role` and `may_author` on the `Account`, refreshed by
  `op`/`deop`/`author`/`unauthor` and on world swap, instead of hashing per message. Keep `security_test._test_commands`
  and add a case per `/test` subcommand.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-9 · Medium · Architecture
- **What:** `server.gd` (1271 lines) is a god object. It holds the transport, the handshake and its limits,
  access lists and roles, the admin commands, chat routing, mod hosting and hot reload, the security log, account
  lifecycle and bots, and the event broadcast.
- **Where:** `src/server/server.gd`: transport and rate limiting `237-310`, `1106-1150`; command dispatch and
  handlers `331-447`, `675-796` (about 240 lines); mods `454-552`; access and roles `555-630`, `668`; chat
  `634-665`; kick/stop/forget/linger `801-835`, `1203-1245`; message intake `838-888`; bots `895-927`; handshake
  `930-1101` (`_hello` is 109 lines); security log `1157-1200`.
- **Evidence:** 69 top-level members; 14 preloads; two inner classes. `Account` setup is copy-pasted between `_hello`
  (`:982-1019`) and `add_bot` (`:896-919`): `PlayerLink.new`, `who.id/player_name`, `paced`, chat signals,
  `find_home`, `teams.seen`, the `wild`/`start_wildlife` block.
- **Why it matters:** Every security fix (S-08..S-19 all touched this file) and every mod/editor feature lands
  here, and the responsibilities are tested together only through the slow `server_test`.
- **Proposed refactoring (structure change, owner's pick):** keep `Server` as transport + accounts + flush (about 450
  lines). Move out `server_access.gd` (access dict, kept/roles/bans/whitelist/load/save), `server_commands.gd`
  (COMMANDS table, `command`, `_give/_tp/_ban/...`, the one role check of NET-8), `server_door.gd` (`_refusal`,
  password/new-player limits, `_same`, `_prune`), `server_mods.gd` (reload, mods_over, put_mod, _join_bundles),
  `security_log.gd` (`flag`, `_flag_at`, lines). Make one `_new_account(key, name, bot)` for `_hello` and `add_bot`.
  These are separate modules, not a chain of parts: each has its own state. Option B: a chain of parts
  `server.gd ← server_*.gd`, as decisions 145/168 allow; cheaper but keeps one object. Recommendation: modules,
  because access and commands are testable alone.
- **Effort:** L. **Risk:** medium. **Confidence:** high.

### NET-10 · Medium · Size
- **What:** The protocol is dispatched by long string `match` statements, and adding a request or event means
  editing 5-8 places by hand, with nothing checking they agree.
- **Where:** `src/server/requests.gd:176-495` (`_rule`, about 320 lines, 70 branches);
  `src/client/net/mirror.gd:77-306` (`_on_event`, about 230 lines); `src/server/player_link.gd:307-413` (`flush`,
  about 107 lines); `src/shared/net/protocol.gd` (147 string constants); `requests.gd:47-54` (PACED and RECORDED
  arrays searched with `in` on every request).
- **Evidence:** A new request needs: the `Protocol` const and doc, a `_rule` branch with `_fit`, PACED/RECORDED if
  it applies, the client call, the `NETWORK_SECURITY.md` table, and a `security_test` case. A new event needs: the
  const, a dirty flag and its initialiser, the `connect` in `PlayerLink._init` and `disconnect` in `leave` (30 pairs
  kept by hand; I diffed them and they pair today), the emit in `flush`, the reset in `rejoin` (see NET-5), and a
  `Mirror` branch. Several handlers use ad-hoc checks instead of `_fit` (`BAG_PUT/BAG_MOVE/BAG_ALL/SORT/BAG_DESTROY`
  at `:383-416`); CRAFT_CANCEL_ALL and TEAM_LEAVE accept any args.
- **Why it matters:** Each step that can be forgotten is a protocol or security bug waiting (NET-5 is one). The
  security doc's table is hand-maintained and cannot be checked against the code.
- **Proposed refactoring:** A table in `requests.gd`: `const TABLE := {Protocol.DIG: {"args": [[V3I, V3I]],
  "paced": true, "do": "_dig"}, …}`, with each branch a small method. `_do` checks `_fit` against the listed shapes,
  pacing and history from the table. A unit test then walks `TABLE` and sends malformed args of each kind (wrong
  count, wrong types, NaN vectors, huge ints, `INT64_MIN` slots), expecting `null` or `false` and no `SCRIPT ERROR`.
  `tools/doc_index.py` could print the table into the doc. Do the same for `Mirror` (a `{kind: method}` dict). The
  protocol on the wire does not change.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### NET-11 · Medium · Architecture
- **What:** Single player (the in-process loop) and a socket run different code for the same game. The loop link
  turns off world sending, move checks and pacing; the client reads and writes the server's own objects directly;
  and the playtest switches are applied by two separate implementations.
- **Where:** `src/client/net/local_host.gd:104-110` (`PlayerLink` with `send_world`, `check_moves` and `paced` all
  false); `src/client/settings.gd:756-760`, `:1142-1160` (writes `game.host.player.inventory/vitals`,
  `game.session.territory`, `who.give`); `src/client/view/death_fx.gd:147` (`game.host.session.players`);
  `src/server/cheats.gd:31-102` (`Cheats.apply`, the socket path) against `settings.gd` applying the same switches
  to `game.host.player` (the loop path). 29 `host == null`/`host != null` branches in `src/client`.
- **Evidence:** The `local_host.gd:11-12` header calls direct access to `player` and `workshop` temporary ("until the
  saves move to the server (С4) and the playtest page gets its commands (С5)"); both stages are done and the reach-ins
  remain. The `cheats.gd` header says it does "as the game in one's own world does (Settings.apply)", a copy kept in
  sync by hand.
- **Why it matters:** Most tests and most playtesting run over the loop. A feature that works there because the
  client sees the server's world may be missing or wrong over a socket (see NET-5), and a switch added to `settings.gd`
  may never reach `Cheats`.
- **Proposed refactoring:** Make the loop send `Protocol.CHEATS` too: `LocalHost` sets `may_cheat = true`, and
  `settings.gd` calls `game.net.request(CHEATS, …)` in both modes; delete the direct writes. Give `give_tools` and
  `clear_land` a request each. Long term (owner's pick): a CI job that runs `server_test`-style play over a loopback
  socket for the scene tests, so the socket path is the one exercised.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### NET-12 · Medium · Performance
- **What:** Snapshots resend fields that never change. A PEOPLE entry is 20 fields, including the player's name,
  looks dictionary, worn gear and gear dyes, and the whole entry goes again whenever any field changes, which
  means every 50 ms while the player walks. YOU resends the whole inventory and character state on any bag change.
- **Where:** `src/server/player_link.gd:517-524` (entry, sent whole when `_people.get(p.id) != e`), `:398-400`
  (`PEOPLE_EVERY` 0.05 s per receiver), `:309-316` (YOU = `inventory.to_dict()` + `who.to_dict()` + respawns on
  `_you`), `:128-129` (any `inventory.changed` or `state_changed` sets `_you`).
- **Evidence:** Per frame, each player's flush is O(players) for PEOPLE (every third frame), each building 20-element
  arrays with 4 `duplicate()` calls; O(N²) entries a tick in all. SNAP is per moved animal per player every 0.1 s
  (11 fields). **net-8** (sending everything to everyone) was fixed for SNAP by zone (WA-062). Static fields were
  never split out.
- **Why it matters:** Phone bandwidth and server CPU both grow with crowd size. Each item picked up resends the
  whole bag (dozens of slots with quality and wear).
- **Proposed refactoring:** Split PEOPLE into PERSON (name, looks, gear, dye: on change only) and a compact MOVE
  (id, pos, facing, flags as a bit field, work). Send YOU's inventory only when the inventory changed, separate from
  state. Changes the protocol: bump `Protocol.VERSION`.
- **Effort:** M. **Risk:** medium. **Confidence:** high on structure; bandwidth not measured.

### NET-13 · Medium · Correctness
- **What:** When the server moves to another world, it carries hosts, bans and the whitelist over but drops the
  authors, and the merged lists are never written into the new world's `access.json`.
- **Where:** `src/server/server_main.gd:251` (`for k in ["banned_keys", "hosts", "owners", "listed_keys"]`; no
  `"authors"`), `:251-257` (merge, no `server._save_access()`); `src/server/server.gd:201-202` (access has `authors`).
- **Evidence:** As quoted. `load_access` ran in `_open_saves` before the merge, so a restart in the new world forgets
  the carried-over bans and hosts.
- **Why it matters:** A banned player returns after a `/test new` and a restart. Authors lose the right to put mods
  after any world swap.
- **Proposed refactoring:** Move the carry-over into `ServerAccess.merge(old)` (NET-9), covering every key, and save
  after it. Add a test in `server_test._renew`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-14 · Medium · Robustness
- **What:** Dead connections are not detected. Neither the server nor the client sets a WebSocket heartbeat or an
  idle timeout after the hello. A phone that drops off the network leaves a half-open connection: its character
  stays "online" and never starts its LINGER countdown, and events pile up toward the 4 MB buffer until the OS TCP
  timeout, which is minutes. The client does not reconnect by itself after a lost connection, only after
  `CLOSE_RENEW`.
- **Where:** `src/server/server.gd:247-252` (peer setup), `:275-286` (timeouts only before the hello);
  `src/client/net/socket.gd:39-46`; `src/client/net/server_link.gd:339-361` (lost connection → error text, no retry).
  `grep -rn heartbeat src/` finds nothing.
- **Evidence:** As above. The `Peer` keeps no "last message at" time to time out on, even though the client sends
  INPUT whenever it changes.
- **Why it matters:** The LINGER design ("a page reloaded comes back to it") assumes drops are seen quickly. A
  phone switching networks costs the player a trip through the menu, and a ghost character stays in the world.
- **Proposed refactoring:** Set `heartbeat_interval` on both sides (exists on `WebSocketPeer` in recent Godot 4;
  confirm for 4.5.1), or add `Peer.heard_at` and close after 20 s of silence, with the client sending a tiny ping
  when idle. On the client, retry joining with the saved key for up to LINGER seconds before showing the error.
- **Effort:** S-M. **Risk:** low. **Confidence:** medium (heartbeat API availability unverified).

### NET-15 · Low · Correctness
- **What:** A save cut off midway can leave the world inconsistent, contrary to the docs. Chunks are moved into
  place before `world.json` is even written, and the final moves are file by file. A crash between them pairs new
  chunks or player files with an old `world.json`, so items placed or chest contents can be duplicated or lost.
  The autosave also ignores save failures.
- **Where:** `src/server/server_store.gd:110-117` (chunks written and renamed first), `:124-130` (sequential
  `move_over`), `:97-101` (`update` drops the return value); `docs/systems/network/server.md:146-148` ("the save
  itself is whole").
- **Evidence:** As quoted. `write_chunk` → `_replace` renames each chunk at once (`world_store.gd:161`).
- **Why it matters:** Rare (it needs a crash inside the save), but it is the exact item-duplication case the
  snapshot design was meant to rule out. Repeated autosave failures, such as a full disk, are only visible as
  engine errors.
- **Proposed refactoring:** Write chunks beside their files (`.tmp`) like the JSON, and move all files after all
  writes succeed. Or write a `save.id` generation into `world.json` and into each player file, and ignore files
  newer than `world.json` on load. Make `update` log and count failures (`saves_failed`) and say it in `who`.
  Touches saves.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### NET-16 · Low · Security
- **What:** A malicious server can make the client allocate as much memory as it names: the client trusts the
  server-sent uncompressed size of a CHUNK. Some vector events are taken without a finiteness check.
- **Where:** `src/client/net/remote_gen.gd:60` (`bytes.decompress(size, ZSTD)`, where `size` comes from
  `mirror.gd:135-139`); contrast `src/client/net/mod_fetch.gd:194-198` (`PIECE_MAX` bound). `mirror.gd:184-186`
  (TELEPORT with no `is_finite`), `:196-202` (KNOCK floats and PUSH unchecked), while FLOW and SPORES are checked
  (`:179`, `:194`).
- **Evidence:** As quoted.
- **Why it matters:** A shared `?server=` link can crash a web or phone client through an out-of-memory error, or
  put NaN into the player's body. Low, because joining a server is a trust choice, but the mods path shows the
  intended standard.
- **Proposed refactoring:** Cap `size` (for example `WorldData` chunk bytes × 2) and check finiteness for TELEPORT,
  KNOCK and PUSH. Add a `net_test` case.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-17 · Low · Security
- **What:** Player records grow without limit on a public server. `NEW_PLAYERS` allows 10 new keys a minute
  (14,400 a day). Each joins with a fresh key, gets a `players/<hash>.json` on the next save, and is never pruned.
  `known_players()` parses every one of them at startup.
- **Where:** `src/server/server.gd:77-78`, `:984-986`; `src/server/server_store.gd:67-82`, `:119-122`.
- **Evidence:** As quoted. Nothing deletes player files.
- **Why it matters:** Disk use and startup time grow on a no-password tunnel server under a simple script.
- **Proposed refactoring:** Do not write a record for a new player who left with nothing (empty bag, no claims)
  within the first minutes. Keep `next_player` in `world.json` as the source of truth, so `known_players` need not
  read every file. Optionally have a host command prune records unseen for N days.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### NET-18 · Low · Security
- **What:** A crafted client can jump without paying stamina. The server's simulated body jumps when the claimed
  height rises, but stamina is charged only when the client sets its own "jumped" flag.
- **Where:** `src/server/player.gd:155-158` (`jump = jumped_told or (claim.y > _sim.y + …)`, then
  `body.jumped = jumped_told`); `src/shared/game/character.gd:384-387` (`vitals.spend("jump")` only if `body.jumped`).
- **Evidence:** The comment at `:157` says "The jumps counted and paid for are the client's".
- **Why it matters:** Infinite stamina for climbing and escaping fights over a socket.
- **Proposed refactoring:** Set `body.jumped = jump` (the server's own decision) when `check_moves` is on.
- **Effort:** S. **Risk:** low (check that the client's own jump does not count twice). **Confidence:** medium.

### NET-19 · Low · Tests
- **What:** About half of the request kinds are never sent over a socket in `security_test.gd` or `server_test.gd`.
  No test sends malformed args for every kind, and none covers a slow client, a rejoin getting the full state, or
  pending-slot exhaustion.
- **Where:** `tests/unit/security_test.gd` (731 lines), `tests/server_test.gd` (1138 lines).
- **Evidence:** Counting the `Protocol.X` names used in both files, these appear in neither: PICKUP, GATHER, PLACE,
  FRONT, PLANT, PLANT_AT, EAT, THROW, LIGHT_PUT, PROP_FIRE, PROP_OPEN, PROP_DESTROY, BUILD, PLAN_CLEAR, FARM_WORK,
  FARM_CLEAR, CRAFT_CANCEL(_ALL), WEAR, TAKE_OFF, SLEEP, LIE_IN, SIT_ON, REPAIR, BAG_PUT, BAG_ALL, BAG_DESTROY,
  TEAM_DECLINE, TEAM_KICK, TEAM_NAME, LAND_PAINT, LAND_RIGHTS, LAND_COLOR, CHEATS (by name), FIGHT_BRAVE, REVIVE. Some
  rules have unit tests of their own, but not through `Requests` with hostile args.
- **Why it matters:** The "each fix gets a test" rule covers the past findings only. A type mistake in an untested
  branch becomes a `SCRIPT ERROR` on the server or a hole.
- **Proposed refactoring:** The table-driven malformed-args test of NET-10. A test that a rejoin gets the same event
  kinds as a join (NET-5). A test with 5 silent localhost sockets (NET-2). A test that fills a peer's outbound buffer
  and checks resync (NET-1).
- **Effort:** M. **Risk:** low. **Confidence:** high (on kinds absent from these two files).

### NET-20 · Low · Security
- **What:** Small loose ends. (a) The host command `tp` does not clamp coordinates (any `is_valid_int`), while the
  playtest teleport clamps to `Cheats.MOST_FAR` 1e6. (b) `real_weather.gd` sends the server's IP to ipapi.co or
  ipwho.is and puts no size limit on the response body. Both are opt-in.
- **Where:** `src/server/server.gd:717-721`; `src/server/cheats.gd:27`, `:98-99`; `src/server/real_weather.gd:11-12`,
  `:40-43`, `:60-61`.
- **Evidence:** As quoted.
- **Why it matters:** A typo in `tp` sends a player to 1e18 and starts world generation there. The weather feature
  discloses the server's location to third parties.
- **Proposed refactoring:** Clamp `tp` with `Cheats.MOST_FAR`. Set `HTTPRequest.body_size_limit` (64 KB). Mention
  the IP services in the setting's tooltip.
- **Effort:** S. **Risk:** low. **Confidence:** high.

---

## Design notes the brief asked for (no separate finding)

- **Protocol versioning.** `Protocol.VERSION` (2) plus an exact build-version match (`server.gd:1047`) means no
  compatibility between builds at all. It is simple and safe; `VERSION` adds little beyond the build check. Every dev
  run reports "dev" and so matches every other dev run, so two different dev checkouts can join each other unchecked.
- **Snapshot/delta design.** Events are dirty flags plus an outbox per link. World state is pushed, nearest chunks
  first, by a fixed number per flush; animals as diffs per receiver (`_snapped`); people as whole entries per
  receiver. Per frame and per player the cost is the zone scan (NET-3), `territory.used` over all claims, and
  `fights.view`. Every third frame it adds O(N) for PEOPLE (O(N²) overall); every sixth frame, O(moved animals) for
  SNAP. There is no per-client bandwidth budget (NET-1).
- **Client prediction.** The client owns its body. The server re-simulates it (`_take_claim`) with a 2.5-cell
  tolerance and a TELEPORT after 10 strikes; there is no rollback or reconciliation beyond that. Inventory, crafting
  and placement are not predicted: the client waits for replies (`Controls._wait_reply`). The client copies reuse the
  shared classes (`client/game/character.gd extends shared/game/character.gd`, `Placed.take_*`), so there is little
  copied rule logic. The drift risk is in the event plumbing (NET-5, NET-11), not in duplicated rules.
- **Earlier audit items still open in this area:** net-7 (NET-3), net-8 partly (NET-12), net-10 partly (only the
  pre-hello path still decodes twice, `server.gd:842` and `:931`), net-9 (the loop flushes twice per frame; not
  re-checked).

## Healthy
- **Content host** (`content_host.gd`): files are found only by hash in a list read from disk, never by a path from
  the socket. Hashes are re-checked before sending, the feed is rate- and byte-limited, and there is a list-count cap.
  No path traversal is possible.
- **Mod download on the client** (`mod_fetch._take`, `ModCache.store`): every piece's size is checked against the
  list, `decompress` is bounded by `PIECE_MAX`, the hash is verified, and files are stored under their hash with a
  closed set of extensions. Only data is loaded.
- **Requests checks.** `Requests._fit` checks types before any rule runs, `Inventory` slots are bounds-checked inside
  `take_slot` and `sort`, things are reached only through `_near` (hand reach) and land rights, and `MOD_PUT` checks
  piece size, order and pacing.
- **The greeting and keys.** The password is compared by hash in constant time (`_same`). Keys are kept as hashes
  in `access.json` and player files. The bot key prefix is refused at the greeting. Names are cleaned
  (`Protocol.clean_text`), with `Lang.is_key` and reserved names refused. `bytes_to_var` is used without objects.
- **`take_input`.** It checks the shape before taking any field, rejects NaN and infinities, and caps the view
  (`VIEW_MAX`), so the server's body re-simulation decides the position.
- **Processes started by the server.** `test_commands.add_bot` passes the password by environment and uses
  `sh -c 'exec … "$@"'` with positional args (no injection). `find_world` refuses paths. The tunnel's arguments are
  a fixed `PackedStringArray`.
- **The save writer.** Each JSON file is written beside its place and renamed into place; leftover `.tmp` files are
  cleaned at start.

## Not covered
Load or bandwidth measurements (Godot not installed). The shared rules behind each handler, beyond the bound
checks named above. `server_bot.gd`, `playtest_host.gd`, `test_mod.gd`, `mod_put.gd`, `updates.gd`,
`server_list.gd`, `remote_wildlife.gd`, `remote_placed.gd`. The Russian docs. Whether Godot 4.5.1's `WebSocketPeer`
allocates its buffers upfront per connection, which would make each pending connection cost about 4 MB; this is
unverified and would sharpen NET-2.
