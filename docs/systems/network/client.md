# The client side of the net

Part of [Protocol and server](../network.md). The connection, the copy of the world, mod files, the server inside the game, the link to a server.

- `src/client/net/connection.gd` — the client's side: `request(kind, args)` → `Reply` (`done`, `value`,
  `then(cb)` calls at once if the reply is already there), `receive(bytes)`, the counters `sent_bytes`,
  `received_bytes`, `coding_us`, `pending()`. The transport is a `Callable` that returns the reply's bytes at
  once (the loop) or `null` (a socket: the replies come through `receive`).
- `src/client/net/remote_gen.gd` (extends `world_gen.gd`) — the copy of the generator through a socket: the
  layout of the ground by the seed and the server's settings as its own (biomes, the map, where the animals
  live), but it generates nothing: `saved` — itself, a chunk's record from `chunk` (`take_chunk`, `packs`) is
  restored by the generator's work like a saved chunk (`start` only `TERRAIN` and only for those sent; the
  chunk is `SHAPED` at once; `cells` and `drops` that come for a chunk sent but not restored yet wait in
  `held` (`hold_cell`, `hold_drops`) and go in after its record, which would lay the old ones over them), `needed` — the chunk and its neighbours by 1 are sent (the mesher reads their
  cells at the edges; the visibility zone through a socket — `ZONE` − 1); what the session does through the
  loop (`Main.world_maker`): `make_chunk` (at once, the loading screen), `make_chunks(near_us, far_us)` (the
  nearest to `home` first within the frame's budget), `forget_far` is empty (the server forgets: `forget` →
  `forget` + `ChunkStreamer.unload_chunk`), `take_work` («restore»), `gen_us`, `stages_left`; a chunk sent
  anew is restored in place and the signal `changed` rebuilds its mesh (`remesh_chunk`). The cells `cells`
  are set by `Mirror` straight into the world's copy, giving `actions.cell_changed` once per column, from its
  lowest cell (as the server does at its side after a felling); `taken` → `actions.taken`; `drops` with a list
  → `world.drops`. The server's materials in another order — `material_map` (`Mat.remap`), as with a save.
- `src/client/net/socket.gd` — the client's socket to a server over the network: `WebSocketPeer` as the
  `Connection`'s transport (`net`; the replies come later, through `Reply.then`), `open(ws://…)`, `hello(name,
  key, password)` — the first request (what is sent before opening waits in a queue), `poll()` every frame
  (`opened`, incoming into `net.receive`, `closed(code, reason)` and `ended` / `close_code` / `close_reason`:
  −1 and "" — the link is lost or there is no server), `leave()` — `bye` and closing. The game itself plays
  through it (`game.link.join_url`) and the `server_test` bots enter by it.
- `src/client/net/updates.gd` — a newer build for «What's new»: a build of main (not `dev`, not a PR's `+pr`)
  asks for `latest.json` beside the web build (`tools/build_info.py --latest`) `WAIT` 3 s after the menu shows,
  once a run, quietly offline; a build whose PR merged later than this one's is newer (`latest`, signal `found`:
  the menu's dot). `note_run` keeps this and the build run before in `user://versions.cfg` (`before`,
  `is_new`); `coming` — the changes the newer build brings; `update` reloads the web page past the browser's
  cache, else opens the latest release's APK, Windows or Linux file.
- `src/client/net/mod_fetch.gd` — the game's side of the mods' files (decision 189): `begin(connection, hash,
  bundles)` finds where each file of the server's set is on this device (`plan`: the game's own file when its
  hash is the same, the built-in copy's, one kept from a server before), asks for the list (unless the set is
  kept) and for the files that are nowhere, puts the pieces together, checks each file (its hash,
  `ModFiles.may_be`) and keeps it (`ModCache`); `finished(ok)` with `table` (a path inside `content/` → the file
  that holds it) for `Content.serve`. More than `ASK_ABOVE` 50 MB waits for the player's yes (`state` «ask»,
  `allow`); a server quiet for `STALL` 20 s fails the taking. `src/client/net/mod_cache.gd` — the files kept on
  the device: `user://mod_cache/<hash>.<ext>`, the lists of the last `SETS_KEPT` 8 sets in `sets/`, `used.json`
  (when each was last used), `trim` past `LIMIT` 200 MB (the longest unused first, never a file of the set
  played), `clear` («Settings» → «Other» → «Clear server data»).
- `src/client/net/local_host.gd` — the server inside the game: the only place where the client loads
  `src/server/`; `LocalHost.new(session, get_tree().root)` puts the server node `src/server/runner.gd` under the
  tree's root and under it `real_weather` (`src/server/real_weather.gd` on the session's clock, switched on by
  `Settings.apply` by the setting «Weather»; without a root — tests — there are no nodes, the test steps the
  session), `stop()` takes it off the tree and frees it (Main calls it in `_exit_tree`); `join()` makes a
  `PlayerLink` in the session and gives a `Connection`; `deliver(bytes)` passes a message through the link and
  returns the events and the reply; `flush(net)` after the tick; `player` and `workshop` — the server objects
  which, before С4/С5, saving and the «Testing» page go to directly. The server node — [session.md](../session.md).
- `src/client/net/mirror.gd` — the copies on the client: listens to `Connection.event` and hands out the events
  to `game.character` (`take`, `take_vitals`, `say`, `teleport`), `game.workshop` (`take`, `take_knowledge`,
  `made`), `game.props.show_drops`, `game.player.body.knock` / `nudge` (`push`), `game.placed` (`take_all`,
  `take_prop`, `take_gone`, `take_lit`, `take_chest`), `game.clock` (`from_snapshot`), `game.wildlife`
  (`take_born`, `take_gone`, `take_snap`, `take_step`), `game.others` (`take_people`, `take_gone`);
  `send_input()` sends the body, hands, screen, «on the ground» and the hands' work (the half-size of the low
  viewport in world units plus `SEEN_MARGIN` 4, along `PixelView.right`) every frame and before every request
  (`Connection.sending`), only if something changed (the hands are copied: the array from `controls.hands`
  shares data with it and would not differ).
- `src/client/net/remote_placed.gd` (extends `placed.gd`) — the copy of the things on cells: the same records
  `things`, `chest_items`, the signals `added` / `removed` / `lit_changed`; takes the cells of things
  (`world.blockers`, in the loop — the same as the server's) and changes nothing in the world (`_forget`, not
  `_remove`: with no `note_edit`); the copy's chest is an `Inventory` that `chest` fills by `from_dict` (the bag
  window listens to its `changed`). `remote_clock.gd` (extends `clock.gd`) — the clock's copy: `from_snapshot`
  once per 0.25 s, between snapshots `advance(delta)` runs the time of day itself (the sun moves every frame),
  `step` is empty; the season, the weather and its strengths — only from snapshots. `remote_wildlife.gd` — the
  animals' copy: its own `Animal` (number, kind, place, `lift`, `facing`, `flying`, `perched`, `moving`, `hop`,
  `left`, `near`, `state`, `tint`, `frame`, `fresh`, `aloft()`), the same signals `born` / `gone` / `stepped`;
  `fresh` is set by `snap`, `creatures.gd` takes it off when it has set the picture.
- `src/client/game/creatures.gd`, `props.gd`, `fire_shadows.gd`, `voices.gd`, `sky.gd`, the HUD, the sounds —
  read the copies as they read the rules; `props.place()` (the save's things, the start camp) and the
  «Testing» page (`settings.gd`: season, weather, hour, time speed) write into the server's
  `game.session.placed` / `session.clock` — before С4 and С5.
- `src/client/game/character.gd` — the copy of the player's character: it does not run the rules (`update`
  only sets the player after `go_to_column`), takes the bag, strength, death and home from `you`/`vitals`,
  death hides the player (`_fell`) and resets the save; it remains `who` for what the client reads from the
  rules itself (the cursor preview, `useful`, `front_choice`). `src/client/net/remote_workshop.gd` — the
  workshop's copy: the queue and pause from `shop`, knowledge from `knowledge`, it learns and does nothing
  itself.
- One's own server from the PC menu (С5.2): `LocalHost.host(values, root)` makes the same node as a server from
  the terminal (`server_main.gd` with `hosted`: the settings are given, not read; `start()` at once — the
  world is open, the bundles on, the port listened to; the node under the tree's root survives scene restarts,
  `PROCESS_MODE_ALWAYS`, with no frame limit and no terminal, `log_lines` for the window, the signal
  `stopped`; `failed` — why it did not start, «Port N is busy»), writes the settings to `user://server.cfg`.
  `ServerLink.host_server` puts the settings in `ServerLink.host_ask` and restarts the scene; the new scene in `_ready`
  before everything (`start_hosting`) makes the server (`ServerLink.hosted`) and enters it as a client by `ws://127.0.0.1:port` with
  its bundles (`pending_mods`), the menu opens the server's window; `stop_server` — `stop` (saves the world),
  on `stopped` the node is freed and the scene is one's own world. While the server runs, the closing of the
  socket by it is not counted as a failed login (`ServerLink.server_stopping`).
- `src/client/net/server_link.gd` (`game.link`, made with the Main node) — the way onto a server through a socket, apart from the scene `main.gd` builds; what lives over a scene restart is static in it (`join_url` from the static `ServerLink.join` — set by the «Join» screen
  (`join_server`, a scene restart) or `--join <url>` with `--name`, `--password` at the first start; a test
  sets `join_url` itself; `leave_server` clears `join`, and the next start is one's own world; on the web
  `?server=` only opens «Join» with the address, `ServerLink.offered`; with `--bot` the game plays itself —
  `src/client/input/bot.gd`, below): `open` from `Main._ready` — the socket, `hello` with the key of this server
  (`src/client/net/server_list.gd`: `user://servers.cfg` — keys by address, recent servers with the title from
  the welcome (`title`), the player's name; `normalize` — an address typed by hand: with no scheme — `ws://` for
  numbers and `localhost`, otherwise `wss://`, `ws://` with no port — `Protocol.PORT`; `problem` — `ws://`
  from a page over https the browser will not allow), `mirror.watch(net)` at once (events before the world is
  built are piled up by `Mirror._pending`, `replay` after); `start_world` → `_join_world` → `wait_welcome`: waits for the
  welcome (`JOIN_WAIT` 15 s; a refusal — words on the loading screen: «The server does not answer», «The
  game's version is different — refresh the page», «Wrong password», «The server is full»), with other
  bundles — `pending_mods` and a scene restart (decision 153, 5А); with other mod files (the refusal `mods`,
  decision 189) — `_take_mods`: the game's own files for the server's bundles if their hash is the server's,
  else `ModFetch` over this link (the loading screen: «Mod data: 1.2 of 3.4 MB»; over 50 MB the player is told
  the size and joins again to agree), then `server_mods` {url, digest, table} and a scene restart: `use_mods`
  serves the table (`Content.serve`) before `Mods.activate` while the game is on that server, and the game's
  own files again afterwards; a server made in this game is told its own hash; `ModReload.watch_server` takes
  the server's reloads in the world (`mods` → `ModFetch` → `Content.serve` → `reload()`; over 50 MB the
  game leaves the server telling the size, as on joining, and joining again agrees); then `RemoteGen` by
  the seed and the
  server's settings, the map and materials as usual, `actions` — its own `WorldActions` over the world's
  read-only copy (the cursor preview, what a bush gives; the signals are given it by `Mirror`), the body at
  `welcome.at`; `host`, `session`, `storms` — null (the «Testing» page and saving do not touch them),
  `world_maker` — the generator-copy; in the frame `socket.poll()` first thing, `_world_made()` — the
  restoring of sent chunks within the streamer's budget instead of `runner.take_spent()`; `_exit_tree` —
  `socket.leave()`. The «Server» line shows the address.
- `src/client/main.gd` — the copies `clock`, `placed`, `wildlife` in `_ready`; the server's clock and things
  (`Clock.new()`, `Placed.new()`) in `start_world` only for the session (saving and the weather from outside
  of the server inside the game write to them), `host` (with the server node), `net`, `mirror` there too, the
  first `host.flush(net)` at the end of `start_world` (the copies are full before the menu); saving follows
  the server's objects (`save.track(host.player…)`, `session.clock.to_dict()`, `session.placed.to_list()`);
  in the frame: the server node did the tick before Main → `clock.advance` → the sky … `host.flush(net)` (the
  tick's events) → `player.step` → `character.update` → `mirror.send_input()` (the next frame's tick will take
  it); the «Server» line in «Test data» (`settings_menu.gd`) shows the connection's counters.
