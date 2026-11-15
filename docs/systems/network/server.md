# The server

Part of [Protocol and server](../network.md). The character on the server, the link of a player, the server node, saving, settings, the tunnel, the console.

- `src/server/player.gd` (extends `src/shared/game/character.gd`) — the player's character on the server,
  `who` for the rules: the body and hands are as the client sent them in `input` (`take_input`: the place, the
  feet's cell, the gaze step, hands, the hand at work, the brush, walking, swimming, jumped, jumps in the air,
  pressed against something, the screen — the direction of its width along the ground and the half-sizes in
  world units, `Character.view_right` / `view_half`, on the ground, the hands' work); `_where` gives the
  accepted place. Through a socket the sent place is checked (`check_moves`, decision 153, 3А): the server's
  body `ServerBody` (the same `body.gd`, with the session's world and clock) goes from its place (`_sim`) to
  the sent one in the time since the last `input` — no more than `CLAIM_GAP_MAX` 0.5 s and no more than has
  passed, so frequent messages give no extra path, walked in steps of 0.05 s (`Body.STEP_MOST`: a phone back from
  the background no longer drops the server's body through the floor into a cave) — by the world's rules: walls, slopes, water, the pace from
  load and weather; a place farther than `MOVE_TOLERANCE` 2.5 cells from where the body got to, or inside a wall
  (`Body.blocked`), is not taken, the player stays where the body got to, and after `STRIKES` 10 such in a row
  the client is put there (`moved` → `teleport`); to the accepted place the server's body is pulled no faster
  than `CATCH_UP` 2 cells per second (ice, corners). Also there: the feet are the accepted place's cell, the
  gaze is a step of 8, the test page's jumps in the air are not taken, the screen up to `VIEW_MAX`, an `input`
  with NaN is skipped, the hands — `in_hands`: only what is in the bag
  ([../security/NETWORK_SECURITY.md](../../security/NETWORK_SECURITY.md)). Through the loop everything is taken as
  it is. A fire's push moves the server's body and goes out as a signal. What it says, lays on the ground,
  where it is put and how it is pushed — the signals `said`, `laid`, `moved`, `knocked`, `tool_used` (it does
  not hold the workshop: the workshop holds it).
- `src/server/player_link.gd` — one player on the server: makes `Player`, `Workshop`, `Requests`, enters the
  session (`add_player`, `leave` — and disconnects from the session's signals); `handle(bytes)` — a request →
  the reply's bytes, the event `input` → the body; the rules' signals set flags, `flush()` gives the events at
  once: `you` (the bag, strength, the state `to_dict` — with it the raft or boat one sits in, `riding`, the
  home, where one was thrown from), `vitals` only when changed, `line` (the player's line float and a bite,
  `Character.line` / `bite`, when changed), `knowledge` when a recipe is learned, `skills` (the skill points,
  no more than once a second, at once on a new level), `shop` (the queue, pause), `clock` (the clock's snapshot
  `Clock.snapshot`) on entry and then once per `CLOCK_EVERY` 0.25 s, on entry `props` (all things
  `Placed.to_list`), `vessels` (rafts and boats `Vessels.record`; then `vessel` on launching and moving,
  `vessel_gone` when taken up) and `animal` for each animal, then the accumulated `say`, `made`, `drops` (a
  chunk), `teleport`, `knock`, `prop` (a thing placed, the record as in `to_list`), `prop_gone` (a cell),
  `prop_lit` (a cell, lit), `prop_fuel` (a cell, seconds of fuel), `chest` (a cell, `Inventory.to_dict` — the
  chest's signal `changed` is connected with the cell in `bind`, not with the record), `animal` (number, kind,
  tint, place), `animal_gone`, `step` (a paw's track); at the end `snap` — the animals that stepped since the
  last `flush` and stand not where they were named (`_snapped` by number; looks only at `Wildlife.moved` and
  those born since the last snapshot, after a full `flush` — at all), and `push` (what the animals pushed the
  body with, `Session.push_on` is taken once), and `people` / `person_gone` — other players in the zone whose
  record changed (`_people` by number; a dead one — left), through a socket once per `people_every` 0.05 s. The
  host calls `flush` after every request (the events come before the reply) and after every tick. `snap_every`
  — seconds between snapshots of the animals (0 — every `flush`, the loop; the server over the network sets
  `Server.SNAP_EVERY` 0.1); an animal more than `Session.reach_for(view_half) + 1` chunks from the player is
  left out of the snapshots and its paw prints (`_far`, `_far_ones`) and told once it comes nearer, even
  standing still; `rejoin()` — the player came back on a new link: the request numbers are from one
  again, the next `flush` is full, as on entry; while a full `flush` lies ahead, `born` is not piled up (the
  animals come with the first player, and each would be named twice). `send_world` (set by `Server`: through a
  socket) — the link keeps the copy of the client's world: `_sent` — the chunks the client has; in every
  `flush` (`_world_events`) — `cells` by edits (`actions.cell_changed`, `actions.cells_set` — all cells of a
  felled tree, `placed.cell_changed`) in the client's chunks, the chunks whose look changed (`looks_changed`:
  berries, a bush — the chunk is sent anew whole, the record carries `turf`, bushes, trees), `grass` — grass cells cut short (`grass_changed`), `spores` where the client holds the world, then the
  missing chunks of the zone around the body by its screen (`Session.reach_for(who.view_half)`, not less than
  `Session.ZONE`), the nearest first, `CHUNKS_PER_FLUSH` 2 per `flush` and only ready ones (`SHAPED`: the
  cells of a ready chunk are no longer changed by generation — the neighbours' trees have already grown into
  it), and `forget` for chunks farther than this zone + 4; `drops` — by `actions.drops_changed` and `who.laid`,
  through a socket with the list `world.drops[key]`; `taken` — only through a socket (through the loop the
  client listens to the rule itself); `ice_holes` — by `session.ice.changed` (and on entry), through a socket with the list
  `Ice.to_list`, which the client checks (`Ice.take_list`), through the loop empty (the world is the same).
- `src/server/server.gd` — the server over the network: `listen()` on the config's port (`TCPServer`), `poll()`
  accepts links every frame (`WebSocketPeer.accept_stream`, the outgoing buffer `BUFFER` 4 MB for С3.2's
  chunks, the incoming `INBOUND` 256 KB; with no greeting no more than `PENDING_MAX` 16 links, from one address
  `PENDING_PER_ADDRESS` 4; messages no more often than `MSG_RATE` 300 a second, the extra are not read, a flood
  `FLOOD_KICK` 3 s — disconnection with code 4003), before the welcome it reads only `hello` (anything else, or
  after `HELLO_WAIT` 10 s — closes with code 4000), checks the version, the name (up to `NAME_MAX` 24 characters,
  `Protocol.clean_text`; not from `RESERVED_NAMES` and not taken by another key in the world), the password
  (in constant time; after `PASSWORD_TRIES` 8 wrong in a minute from an address, new players from there wait, a
  player with a known key gets in), no more than `NEW_PLAYERS` 10 new per minute and the room (`_refusal`),
  makes an `Account` (number, name, key — 16 random bytes in hex, a `PlayerLink` with the start bag, the body at
  the start point `teleport` → the event `teleport`, home) or finds it by the key (the same link from another
  device — the old one is closed with code 4002); the reply to `hello` goes **before** the entry events (the
  client learns who it is before the copies fill), to any other request the events go before the reply, as
  through the loop; `input` and requests — to the link; `flush()` after the tick — events to everyone. If the
  link breaks, the character waits `LINGER` 30 s (also after `bye`; on one's own land or one's team's — not at
  all: `linger_of`, `Territory.at_home`, the step Т4), then `leave()` from the session, saving the whole world
  with it (`store.save(server)`: a thing between a chest and a bag is not doubled); a key that is not among
  the characters in the world is looked up in the save (`store.read_player`) — the player returns to their
  character with the same number even after a restart; `next_id` — from the save. The animals come with the
  first player (`session.start_wildlife`: they settle around people, without people they do not come,
  `Wildlife._spawn`). The host's commands `command(line)` → words to print: `who`, `say <words>` (into the chat
  to everyone from «Server»), `kick <name or number>` (the event `kick`, code 4001, the character leaves at
  once), `stop` (first `store.save`, then `stopping`: the port closed, code 1001 to all, `done()` when the links
  are closed), `help`; С5.3 (can be with `/`): `give <who> <item> [how many]` (the item by id, the end of the
  id or the title, `Character.give`), `tp <who> <x> <y> <z>` (cells) or `tp <who> <to whom>` (`teleport` →
  `teleport` to the client), `ban <who or name>` (the key and name, the player is put out), `unban <name>`,
  `bans`, `whitelist on|off|add <name>|remove <name>` (switching on puts those on the server into the list);
  С6: `op <who>`, `deop <name>`, `hosts` — who may give commands in the chat; `security [kind or name]` — the
  security log (`flag`, `security_log`, [../security/ANTI_CHEAT.md](../../security/ANTI_CHEAT.md)); `reload` —
  reread the mods' data from disk (`reload_mods`, hot reload, decision 184: `Mods.rescan(true)` and
  `Session.reread`, to the players the line «The server reread the mods' data»; `mods_reread` reads the list
  of the files again and, when they changed, sends every player's game the event `mods`, decision 189). The rights are one table
  `COMMANDS` with roles (`role_of` by the key: a host by `op`, the owner — who made the server in the game, the
  terminal): `op`, `deop`, `stop` — to the owner and the terminal
  ([../security/COMMAND_PERMISSIONS.md](../../security/COMMAND_PERMISSIONS.md)). Who may enter — `access`
  (`banned_keys` key → name, `banned_names`, `listed_only`, `listed`, `listed_keys` name → the key with which
  the listed name came first, `hosts` and `owners` key → name; names in lower case), kept in the world's save
  `access.json` (`ServerStore.read_access`/`write_access`, read at start by `load_access`); the refusal of
  `hello` — `banned` or `list` (the words on the client: «The server's host has blocked you», «The server lets
  in only its own…»). In the «Create a server» window the same commands are a field under the log. The log is
  the lines `lines`, the scene prints them with the time.
- `src/server/content_host.gd` — what the server gives of its mods' files (decision 189, `Server.content`):
  the list of the files its world plays with (`ModFiles.of_set`: every YAML under `content/`, the pictures and
  sounds of the world's bundles and of their mods), the hash that names them (`digest`), the list packed for
  the wire (`packed`), read at `listen()` and again by `read()` (the host's `reload`, `Server.mods_reread`). At
  `hello` the server compares the game's hash with its own: another one — the refusal `mods`, the link stays
  open without a character (`Peer.fetching`, up to `FETCH_WAIT` 900 s, `FETCH_IDLE` 30 s asking for nothing, `FETCHING_MAX` 32 such links, `FETCHING_PER_ADDRESS` 4 from one address but this machine's) and takes only `mod_list`, `mod_files`
  and another `hello` (`Server._mods_asked`; the same two events are taken from a player in the world after a
  reload). Files go by pieces of `PIECE` 96 KB (several small files in one message, YAML packed with zstd), to
  each link no faster than `RATE` 2 MB a second and not while it has `BUFFERED_MAX` 512 KB waiting
  (`pieces`, called from `Server.poll`; `Feed` — one link's queue); a link gets the list `LISTS_MAX` 8 times at
  most, `ASK_MAX` 256 hashes in a message, `QUEUE_MAX` in the queue, bytes `SENT_MAX` 3 times the set's size. A
  file that is not what it was when the list was read is not sent (`changed`: the server's log tells the host
  to `reload`); a file the server cannot read (a picture in a phone's build is there only as imported) comes
  as a piece with the size -1. Files may be put over the mods' own (`ContentHost.over`, of the process: path →
  file; the test mod): the list names them, they are given like any other, and the server reads its own data
  through `table()` (`Server.mods_over` → `Content.serve`, `Mods.rescan`, the players' games are told).
- `src/server/server_main.gd` — the root of `scenes/server.tscn`, a server from the terminal: `godot --headless
  --path . -- --server [--port N] [--world <folder>] [--seed N] [--players N] [--password <word>]
  [--config <file>] [--tunnel] [--real-weather]` (from a PC build — `Survivium.console.exe --headless --
  --server` on Windows, a wrapper shows the log in the terminal, or `./Survivium.x86_64 --headless -- --server`
  on Linux; the builds are the release `pc-latest`, [testing.md](../testing.md)); `main.gd` on `--server` first
  thing goes to this scene by a string path (`change_scene_to_file`, deferred: in `_ready` the tree is busy),
  having built nothing of the client. It opens the world like the game: a save under `user://saves` (bundles
  `Mods.of_world`, materials `Mat.remap`, the clock `sky`, things `placed`) or a new world by seed and
  settings (the config's bundles or all, `Mods.resolve`); makes the ground within `SPAWN_REACH` 2 chunks around
  the guess of the start (`Session.make_chunk`), finds the start (`WorldGen.find_spawn`), in a new world puts
  a camp (`Placed.start_camp`, the test world's things), hangs the server node `runner.gd` (`pausable = false`,
  `playing`), listens. In the frame: the server node did the tick → the console's lines → `server.poll()` →
  `server.flush()`; after `stop` it waits for the links to close up to `STOP_WAIT` 1 s and exits
  (`quit_on_stop = false` in a test). `Engine.max_fps` `FPS` 60; `run/flush_stdout_on_print` in
  `project.godot`, so that the log through a pipe goes at once. Saving — `ServerStore` (unless `--no-save`): at
  start it removes what an interrupted save left unwritten, in the frame `saves.update`. With `config.tunnel`
  after `listen` — `open_tunnel()` (`Tunnel`), in the frame `tunnel.poll()`: the address and link into the log
  («from the internet», «link for friends») or «tunnel: <why not>»; `close_tunnel()` in `_quit` and
  `_exit_tree`.
- `src/server/server_store.gd` — the server's saving (С4) in the world's folder, like the game's (`WorldStore`:
  a single-player world is opened by the server and vice versa; the game's `players/local.json` the server does
  not read). Every `every` seconds (`Config.autosave`, 10 s), on `stop` and in `save()`: first the changed
  chunks (`WorldData.unsaved`, each to its own place), then a snapshot in one frame — `world.json` (the seed,
  settings, bundles, materials, the clock, things with the chests' contents, `next_player`) and the record of
  each player in the world `players/<sha256 of the key, 32 characters>.json` (number, name, the body's place,
  bag, strength, character, knowledge, the queue — the sections as in `save_game.gd`), everything first
  beside (`WorldStore.write_json_beside`, `.tmp`), then by moving into place (`move_over`), `world.json` last;
  there is no gap between the parts of a tick, so a thing from a chest is in a bag or in a chest, not in both.
  If writing fails — the `.tmp` are removed, the old files are whole; an interrupted save leaves `.tmp`, which
  `clean()` removes at start (`WorldStore.remove_beside`). `read_player(key)`, `restore(link, record)` (the
  sections, `workshop.settle`, `teleport`). Ctrl+C on Linux ends the process at once (the engine does not tell
  the script): the time since the last save is lost, the save itself is whole; the right way is `stop`.
- `ServerMain.apply_settings(values)` — the settings changed while a server made in the game runs (its window's «Settings»): players, autosave, day length, real weather, the rules; at once and into `server.cfg`.
- `src/server/config.gd` — the server's settings: `user://server.cfg` (the sections `server`: title, port 7777,
  players 8, password, bind, autosave 10, save; `world`: folder, seed, WorldGen settings, mods; `rules`: the
  keys of `Rules.to_dict` over the defaults, `Rules.of(config.rules)`, for example `territory_decay`), over it —
  the arguments (`--autosave <seconds>`, `--no-save` — do not save the world; С7: `tunnel`, `cloudflared` —
  `--tunnel`, `--no-tunnel`, `--cloudflared <file>`; `real_weather` — `--real-weather`, `--no-real-weather`:
  the weather from outside where the server is, `src/server/real_weather.gd`,
  [time-weather.md](../time-weather.md)); `day_minutes` — `--day-minutes N`: the length of a day in minutes, 40 as
  in the game by default (`Config.day_speed` → `Clock.time_speed` when the world opens; «Create a server» takes
  it from the «Settings» tab, and while a server has never been created — the host's «Length of a day»; the
  cheats' «Time speed» is a multiplier on it) of the command line (`take_args`; `--config` is read first);
  `world_path()` — the save's folder: a name under `WorldStore.root`, a path or the folder of a seed and
  settings (`WorldStore.world_dir`). The «Create a server» window (С5) writes the same file.
- `src/server/tunnel.gd` — access from the internet (С7, decision 153 6Б): `start(port, path)` runs
  `cloudflared tunnel --no-autoupdate --url http://localhost:<port>` (`OS.execute_with_pipe`, not blocking;
  `find`: the given path, beside the executable, then `which`/`where`), `poll()` reads its output (it writes
  the address to stderr) and looks for `https://<words>.trycloudflare.com` (`url_in` → `wss://…`); `link()` —
  the game page `PAGE` with `?server=`; `failed` — why not (not found, did not start, stopped with no address);
  `stop()` — `OS.kill`. A quick tunnel with no account: the address is new on every start; how to switch it
  on — the README, «Your own server».
- `src/server/console.gd` — the terminal: a thread reads stdin (`OS.read_buffer_from_stdin`: reading blocks;
  an empty buffer is the end of input, and not an empty line — in `read_string_from_stdin` they cannot be told
  apart), `lines()` gives the lines, after `stop` or the end of input the thread ends and `stop()` joins it; a
  server stopped otherwise exits with the thread in reading (the engine writes about it at exit, harmless). It
  does not start with no stdin (`OS.get_stdin_type()`) and in tests (`config.console`).
