# Protocol and server

Status: ACTIVE (server stages С2.1–С6, decision 153; the plan `plan/architecture/server.md`). A Russian copy:
[network_RU.md](network_RU.md).

**Purpose.** What the client asks of the rules goes in messages: a request `[kind, number, args]`, a reply
`[number, value]`; what one side tells the other with no reply is an event `[kind, args]`: every frame the
client says where its body is and what is in its hands (`input`), the server says what became of the character
(`you`, `vitals`, `knowledge`, `skills`, `shop`, `say`, `made`, `drops`, `teleport`, `knock`, `push`, `line`,
`flow` — the river's current under the body), of the things on cells (`props`, `prop`, `prop_gone`, `prop_lit`,
`prop_fuel`, `chest`), of the clock (`clock`) and of the animals (`animal`, `animal_gone`, `snap`, `step`). The
bytes are `var_to_bytes` with no objects. The player's character and workshop live on the server
(`src/server/player.gd`), the things, the clock and the animals — in the server's session; on the client are
their copies (`game.character`, `game.workshop`, `game.placed`, `game.clock`, `game.wildlife`), which `Mirror`
feeds and which give the views the same signals as the rules. In single player the same bytes go through a
loop in one's own process (the server inside the game), over the network — through a WebSocket to a server
from the terminal (`--server`, С3.1: login by name and key, the host's console; С3.2: the world comes from the
server as ready chunks — `chunk`, `forget`, `cells`, `drops` with a list, `taken` — the client does not
generate it (decision 153, 1А), joining by `--join ws://…`; С3.2; from the menu — the «Join» screen, С5.1);
other players on screen (`people`, `person_gone` → `src/client/view/others.gd`) and the server's check of
movement (3А; С3.3); the client always plays through the protocol so that nothing works only through the loop
and the price of the protocol is measured on a phone (the `Connection` counters). С6: things are handed over
only where the player stands (a chest, a thing on a cell, a thing on the ground — within
`WorldActions.HAND_REACH` 5 units with the slack `REACH_SLACK` 1.5; a bush — within the tool's reach + 2
cells, a tree trunk — in it + `TREE_SPREAD` 6 cells of the crown; `WorldActions.within_hand`,
`Requests._near`), a request with a number not higher than the last is not done a second time, and the server
does the players' requests one at a time, whole — two who took one stack at once will not double it
(`tests/server_test.gd` `_trades`: simultaneous, a repeated number, a dropped link). Chat is beside: the
request `chat` [line] → the server sends `heard` [number, name, line] to all within `Server.CHAT_RANGE` 30
units of the speaker, and to the speaker too; a line with «/» is a command, only for the server's hosts
(`access.hosts`: those given `op`, and the player who made the server in the game — `Main._on_welcome` →
`make_host`), the reply to it comes in the chat to him alone. The hosts online are told the server's comings and
goings by the event `noted` [line] (`Server._note`, a `Lang.line`: joined for the first time, back, lost the
connection, left, the character left the world, disconnected or banned by a host, too many messages, not let
in with the reason `Server.WHY_NOTES`), never about themselves; the HUD shows them apart (`Hud.server_note`). Teams (Т1, [territory.md](territory.md)): the
requests `team_*`, the events `team`, `invites`, a line to the team (`team_chat`) — to all its members in the
world; in `heard` the fourth field is «said to the team», in `people` the last is «in my team». Land (Т2, Т3):
the requests `land_paint`, `land_rights`, `land_color`, the events `claims`, `squares`, `land`. PvP (Т5): the
request `fight_brave`, the event `fight`. AI debugging (decision 184): the request `ai_debug` [on] — only with
`Requests.may_debug` (single player — `LocalHost.join`; on a server the host, `Server` sets it before every
message by `is_host`, a host who is removed loses even a switched-on debug), the event `minds`
(`Wildlife.mind`) once per 0.25 s. No more often than `Requests.CHAT_LINES` 5 lines per `CHAT_WINDOW` 8 s,
length up to `CHAT_MAX` 160.

**Files**
- `src/shared/net/protocol.gd` — the protocol version, the kinds of requests with their args (dig, place,
  the action in front, gather, pick up, plant, eat, drop, place/take/put out/destroy a thing, crafting and its
  queue, repair, move/pour/sort/destroy in the bag and chests, revive), `request`, `reply`, `encode`, `decode`.
  Loads only `content/`. Through a socket each message is one binary frame; the first request on it is
  `hello` ([protocol version, the build's version `build_version()` — from `build_info.json`, «dev» without
  it; a name, the key from last time or "", a password, the hash of the mods' files the game plays with —
  `Content.playing()`]), the reply is a welcome `{"ok": true, "id", "key",
  "name", "seed", "settings", "mods", "materials", "spawn", "at"}` or a refusal `{"ok": false, "why": version |
  password | full | name | banned | list | taken | wait}` (`taken` — the name is taken by another in the world
  or it is the server's name, `wait` — many wrong passwords or new players in a row), after which the server
  closes the link; the refusal `mods` (decision 189: the game's mod files are not the server's) also carries
  `mods` (the server's bundles), `content` (the hash of its files) and `size`, and does not close the link: the
  game takes the files it lacks and says `hello` again (the events `mod_list` [] → [size, bytes], `mod_files`
  [[hash…]] → `mod_data` [[hash, offset, the file's size, the piece's size before packing, the piece]…]; `mods`
  [hash, size, bundles] — the server's files changed, to a game in the world). The event `bye` — the client
  leaves on its own, `kick` [why] — the server put it out. Builds of different versions do not play together
  (decision 153, 5А: the code must be the same; the data may differ since decision 189). The world through a socket: `chunk` [key, size, bytes] — a chunk's record `WorldGen.pack` in
  `var_to_bytes` and zstd (the same as in the save), `forget` [key], `cells` [[cell, material]…], `drops`
  [key, list] (through the loop — only [key]: the world is one), `taken` [id, from where]. Other players:
  `people` [[number, name, place, gaze step, hands, the hand at work, walking, swimming, on the ground, work:
  kind, length, count, where to, what is worn, in the team, the line's float, the raft or boat under them]…] —
  those who changed since last time, in the zone of `Session.ZONE` chunks, through a socket 20 times a second;
  `person_gone` [number] — left the zone or the world. The client's `input` carries both «on the ground» and
  the hands' work (kind, length, count — one more with each swing, where turned).
- `src/server/requests.gd` — one player's requests on the server's side: `handle(msg)` → a reply; a request's
  number grows by one, a repeat of the same number is answered as the first time and is not done again, a
  number below the last is refused (`null`); the args are checked by types (`_fit`), a request that does not
  fit is answered `null`; through a socket (`paced`) the hands' work goes at its pace: a request from `PACED`
  (dig, place, act, gather, plant, place a thing or light) adds the seconds of its swing, and one that comes
  when more than `WORK_AHEAD` 2 s of them lie ahead is refused (`{}` or `false`); what looks wrong — the
  signal `flagged` into the server's log; putting out a fire on someone else's land — by the right «build»;
  chests are named by the thing's cell (`Placed.at`), the player's bag — `null`, a bag or chest lying in the
  bag — by the cell's number (a number: `_bag` opens them with `Inventory.open`, after the request `_do`
  puts the things back with `Inventory.close`; the open thing itself is not moved by the request, `move_all`
  skips it). Loads only `src/shared/`.
- `src/server/player.gd` (extends `src/shared/game/character.gd`) — the player's character on the server,
  `who` for the rules: the body and hands are as the client sent them in `input` (`take_input`: the place, the
  feet's cell, the gaze step, hands, the hand at work, the brush, walking, swimming, jumped, jumps in the air,
  pressed against something, the screen — the direction of its width along the ground and the half-sizes in
  world units, `Character.view_right` / `view_half`, on the ground, the hands' work); `_where` gives the
  accepted place. Through a socket the sent place is checked (`check_moves`, decision 153, 3А): the server's
  body `ServerBody` (the same `body.gd`, with the session's world and clock) goes from its place (`_sim`) to
  the sent one in the time since the last `input` — no more than `CLAIM_GAP_MAX` 0.5 s and no more than has
  passed, so frequent messages give no extra path — by the world's rules: walls, slopes, water, the pace from
  load and weather; a place farther than `MOVE_TOLERANCE` 2.5 cells from where the body got to, or inside a wall
  (`Body.blocked`), is not taken, the player stays where the body got to, and after `STRIKES` 10 such in a row
  the client is put there (`moved` → `teleport`); to the accepted place the server's body is pulled no faster
  than `CATCH_UP` 2 cells per second (ice, corners). Also there: the feet are the accepted place's cell, the
  gaze is a step of 8, the test page's jumps in the air are not taken, the screen up to `VIEW_MAX`, an `input`
  with NaN is skipped, the hands — `in_hands`: only what is in the bag
  ([../security/NETWORK_SECURITY.md](../security/NETWORK_SECURITY.md)). Through the loop everything is taken as
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
  `Server.SNAP_EVERY` 0.1); `rejoin()` — the player came back on a new link: the request numbers are from one
  again, the next `flush` is full, as on entry; while a full `flush` lies ahead, `born` is not piled up (the
  animals come with the first player, and each would be named twice). `send_world` (set by `Server`: through a
  socket) — the link keeps the copy of the client's world: `_sent` — the chunks the client has; in every
  `flush` (`_world_events`) — `cells` by edits (`actions.cell_changed`, `actions.cells_set` — all cells of a
  felled tree, `placed.cell_changed`) in the client's chunks, the chunks whose look changed (`looks_changed`:
  berries, mown grass — the chunk is sent anew whole, the record carries `turf`, bushes, trees), then the
  missing chunks of the zone around the body by its screen (`Session.reach_for(who.view_half)`, not less than
  `Session.ZONE`), the nearest first, `CHUNKS_PER_FLUSH` 2 per `flush` and only ready ones (`SHAPED`: the
  cells of a ready chunk are no longer changed by generation — the neighbours' trees have already grown into
  it), and `forget` for chunks farther than this zone + 4; `drops` — by `actions.drops_changed` and `who.laid`,
  through a socket with the list `world.drops[key]`; `taken` — only through a socket (through the loop the
  client listens to the rule itself).
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
  security log (`flag`, `security_log`, [../security/ANTI_CHEAT.md](../security/ANTI_CHEAT.md)); `reload` —
  reread the mods' data from disk (`reload_mods`, hot reload, decision 184: `Mods.rescan(true)` and
  `Session.reread`, to the players the line «The server reread the mods' data»; `mods_reread` reads the list
  of the files again and, when they changed, sends every player's game the event `mods`, decision 189). The rights are one table
  `COMMANDS` with roles (`role_of` by the key: a host by `op`, the owner — who made the server in the game, the
  terminal): `op`, `deop`, `stop` — to the owner and the terminal
  ([../security/COMMAND_PERMISSIONS.md](../security/COMMAND_PERMISSIONS.md)). Who may enter — `access`
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
  open without a character (`Peer.fetching`, up to `FETCH_WAIT` 900 s, `FETCH_IDLE` 30 s asking for nothing, `FETCHING_MAX` 32 such links) and takes only `mod_list`, `mod_files`
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
  on Linux; the builds are the release `pc-latest`, [testing.md](testing.md)); `main.gd` on `--server` first
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
  [time-weather.md](time-weather.md)); `day_minutes` — `--day-minutes N`: the length of a day in minutes, 40 as
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
- `src/client/net/connection.gd` — the client's side: `request(kind, args)` → `Reply` (`done`, `value`,
  `then(cb)` calls at once if the reply is already there), `receive(bytes)`, the counters `sent_bytes`,
  `received_bytes`, `coding_us`, `pending()`. The transport is a `Callable` that returns the reply's bytes at
  once (the loop) or `null` (a socket: the replies come through `receive`).
- `src/client/net/remote_gen.gd` (extends `world_gen.gd`) — the copy of the generator through a socket: the
  layout of the ground by the seed and the server's settings as its own (biomes, the map, where the animals
  live), but it generates nothing: `saved` — itself, a chunk's record from `chunk` (`take_chunk`, `packs`) is
  restored by the generator's work like a saved chunk (`start` only `TERRAIN` and only for those sent; the
  chunk is `SHAPED` at once), `needed` — the chunk and its neighbours by 1 are sent (the mesher reads their
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
  through it (`Main.join_url`) and the `server_test` bots enter by it.
- `src/client/net/mod_fetch.gd` — the game's side of the mods' files (decision 189): `begin(connection, hash,
  bundles)` finds where each file of the server's set is on this device (`plan`: the game's own file when its
  hash is the same, the built-in copy's, one kept from a server before), asks for the list (unless the set is
  kept) and for the files that are nowhere, puts the pieces together, checks each file (its hash,
  `ModFiles.may_be`) and keeps it (`ModCache`); `finished(ok)` with `table` (a path inside `content/` → the file
  that holds it) for `Content.serve`. More than `ASK_ABOVE` 50 MB waits for the player's yes (`state` «ask»,
  `allow`); a server quiet for `STALL` 20 s fails the taking. `src/client/net/mod_cache.gd` — the files kept on
  the device: `user://mod_cache/<hash>.<ext>`, the lists of the last `SETS_KEPT` 8 sets in `sets/`, `used.json`
  (when each was last used), `trim` past `LIMIT` 200 MB (the longest unused first, never a file of the set
  played), `clear` («Settings» → «Game» → «Clear server data»).
- `src/client/net/local_host.gd` — the server inside the game: the only place where the client loads
  `src/server/`; `LocalHost.new(session, get_tree().root)` puts the server node `src/server/runner.gd` under the
  tree's root and under it `real_weather` (`src/server/real_weather.gd` on the session's clock, switched on by
  `Settings.apply` by the setting «Weather»; without a root — tests — there are no nodes, the test steps the
  session), `stop()` takes it off the tree and frees it (Main calls it in `_exit_tree`); `join()` makes a
  `PlayerLink` in the session and gives a `Connection`; `deliver(bytes)` passes a message through the link and
  returns the events and the reply; `flush(net)` after the tick; `player` and `workshop` — the server objects
  which, before С4/С5, saving and the «Testing» page go to directly. The server node — [session.md](session.md).
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
  `Main.host_server` puts the settings in `Main.host_ask` and restarts the scene; the new scene in `_ready`
  before everything makes the server (`Main.hosted`) and enters it as a client by `ws://127.0.0.1:port` with
  its bundles (`pending_mods`), the menu opens the server's window; `stop_server` — `stop` (saves the world),
  on `stopped` the node is freed and the scene is one's own world. While the server runs, the closing of the
  socket by it is not counted as a failed login (`Main.server_stopping`).
- `src/client/main.gd` through a socket (`join_url` from the static `Main.join` — set by the «Join» screen
  (`join_server`, a scene restart) or `--join <url>` with `--name`, `--password` at the first start; a test
  sets `join_url` itself; `leave_server` clears `join`, and the next start is one's own world; on the web
  `?server=` only opens «Join» with the address, `Main.offered`; with `--bot` the game plays itself —
  `src/client/input/bot.gd`, below): `_connect` in `_ready` — the socket, `hello` with the key of this server
  (`src/client/net/server_list.gd`: `user://servers.cfg` — keys by address, recent servers with the title from
  the welcome (`title`), the player's name; `normalize` — an address typed by hand: with no scheme — `ws://` for
  numbers and `localhost`, otherwise `wss://`, `ws://` with no port — `Protocol.PORT`; `problem` — `ws://`
  from a page over https the browser will not allow), `mirror.watch(net)` at once (events before the world is
  built are piled up by `Mirror._pending`, `replay` after); `start_world` → `_join_world`: waits for the
  welcome (`JOIN_WAIT` 15 s; a refusal — words on the loading screen: «The server does not answer», «The
  game's version is different — refresh the page», «Wrong password», «The server is full»), with other
  bundles — `pending_mods` and a scene restart (decision 153, 5А); with other mod files (the refusal `mods`,
  decision 189) — `_take_mods`: the game's own files for the server's bundles if their hash is the server's,
  else `ModFetch` over this link (the loading screen: «Mod data: 1.2 of 3.4 MB»; over 50 MB the player is told
  the size and joins again to agree), then `server_mods` {url, digest, table} and a scene restart: `_use_mods`
  serves the table (`Content.serve`) before `Mods.activate` while the game is on that server, and the game's
  own files again afterwards; a server made in this game is told its own hash; `ModReload.watch_server` takes
  the server's reloads in the world (`mods` → `ModFetch` → `Content.serve` → `reload()`); then `RemoteGen` by
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

**Who calls.** `controls.gd` (dig, place, act, plant, eat), `gathering.gd` (gather, pick up), `props.gd` (place
a thing), `inventory_window.gd` (eat, plant, drop, repair, put on and take off (`WEAR`, `TAKE_OFF`), chests,
sorting, the trash can, take a chest), `craft_panel.gd` (crafting, queue, station), `death_screen.gd` (revive).
On the loop the reply comes at once: the functions that returned `bool` (`controls.dig_at`,
`gathering.gather`, `props.put_from_bag`) take it from `Reply.value`; through a socket they return `false`
before the reply, and what is done by the reply (`_did`, the sound of eating, the trash can's toast) goes
through `then`.

**What stays direct.** Through the loop the world is one object (decision 153, 2А): the chunks made
(`WorldGen.needed`, the stages), the cells' edits (`actions.cell_changed` → chunks, `placed.cell_changed` of
the server's things), the things on the ground (`world.drops`, the event `drops` only names the chunk) and the
wind (`game.storms`) the client reads from the session; through a socket the same comes in the messages
`chunk`, `cells`, `drops` with a list (the copy has no wind yet). Saving and the «Testing» page (`give`,
`heavy`, `hunger`, `start_bag`, `find_home`, season, weather, hour) go to `game.host.player` /
`host.workshop` / `session.clock` / `session.placed` directly: this works only when the server is in the same
process (single player and one's own server from the menu); a client that has joined someone else's server has
no such objects. The body's movement is the client's (decision 153, 3А); through a socket the server checks it
with its own body (`src/server/player.gd`, `check_moves`), through the loop it trusts. Tests and tools write to
the server's objects (`main.host.player`, `main.session.clock`, `main.session.placed`,
`main.session.wildlife`), and read the copies through the interface.

**Pitfalls.** A variable under `Reply` is not typed (`var r = game.net.request(…)`: the type of a nested class
is not inferred). A request given to the host past `Connection` (as in a test) shifts the counter: the next
requests of the connection with a lower number are refused. `bytes_to_var` on garbage writes an engine error:
`decode` gives `[]`, but the size check and the header's version will be added by С3. Reference cycles between
RefCounted (player ↔ workshop, body ↔ player, host ↔ connection) are not freed — `run_tests` writes «ObjectDB
instances leaked»: the link back is a signal or an argument (`flush(net)`), not a field. The copy on the client
lags behind the server by a `flush`: a test that writes to `host.player` waits a frame before reading
`game.character`. The chest's signal `Inventory.changed` is connected with the cell (`bind(e.cell)`), not with
the record: the record holds the bag, the bag would hold a `Callable` with the record — a cycle; `is_connected`
and `disconnect` check the same `bind`. Who «looks» at an animal (`near`, every frame against a step of 0.1 s)
is decided by the session (`Wildlife.look_from`): the animals on the player's screen as the client sent it in
`input` (a rectangle turned with the camera, no more than `NEAR` 28 units to each side; until the screen is
sent — a circle `NEAR`). Through a socket: the request numbers are per link, on a new link (the page was
reloaded) they are from one again (`PlayerLink.rejoin`), so a repeat after a break is not weeded out — only
within a link. The server's scene added under the root in a test's `_initialize` is made ready (`_ready`) only
with the next frame: wait for `server.server != null`. `WebSocketPeer` connections in one process (the server
and bots) open in two or three frames; `get_close_code()` is −1 when there is no server or the link broke
with no closing frame. One process listens on one port: `server_test` takes 7791, the game 7777.

**A server for checking.** `.github/workflows/playtest.yml` runs a server on GitHub behind a tunnel (by default
the test world, 3 bots, 2 hours, `[rules] free_items`) with `--playtest --minutes N --bots N --bot-logs
<folder>` (`Config.playtest`). Its term is `src/server/playtest_host.gd` (`PlaytestHost`, a child node of the
server's scene): stops the server when the minutes run out (5 min before, tells everyone), `/test hour`
extends it (no more than 300 min from the start). **The «/test» commands exist on any server**
(`src/server/test_commands.gd`, `TestCommands`, a child node of the scene, `Server.test_command`): on a server
for checking — from any player, on any other — from the host (`Server.COMMANDS` «test» — `ROLE_PLAYER`, the
role is checked by `Server.command` and `TestCommands` itself; `stop` outside a server for checking — only for
the owner). `bot+`/`bot-` — bots (no more than 5): processes of this same game with `--headless -- --join
ws://localhost:<port> --bot` (and the server's `--password`; from the project's folder `--path` too), on Linux
under `nice` with the log `bot<N>.log`, only on a computer; `Config.bots` start with the start of any server;
when it stops they are killed. `worlds` — the saved worlds (`WorldStore.list_worlds`, by the folder's name),
`world <folder>` — go over to one of them (only a name under `WorldStore.root`, not a path), `new [seed]` — a
new world, `new test` — the test one; `mod on`, `mod off`, `mod next` — the test mod (below). The move is `server_main.renew(seed, folder)`: `Server.stop` saves the
world (if the server saves), disconnects everyone with the code `Protocol.CLOSE_RENEW` (4010), the new world
opens on the same port (the tunnel and link are the same), with its own saving (`_open_saves`), and who is a
host, who is blocked and the list of its own pass over from the server (`access`); `renewed` — and
`TestCommands` starts the bots again. The game, on getting 4010, enters again itself (`Main.rejoin_until`: up
to 60 s, every 2 s, «The server is moving to another world…»); a server made in this game — with the bundles of
its new world (`Main._ready` takes `hosted.mods`). In the welcome the server says `playtest` and `host` (is the
one who entered a host). In the game «Testing» → the tab «Server» is divided into two sections
(`SettingsMenu._server_rows`): «Test server (GitHub)» — start and connect, and on it itself — extend by an
hour and stop; «This server» (on a server) — add and remove a bot, the test or a new world on the server, for a
server made here — a move into this device's worlds, for someone else's — their list into the chat, stop the
server, «Cheats on the server»; for a player with no role on an ordinary server — only a line that the host
manages this. In single player on a computer — «Make the world a server and call a bot»
(`Settings.host_with_bot`: the world is saved and started as a server, as in «Create a server», with `bots` =
1), in the browser — a line that one's own server and bots are in the PC version (`Settings.test_server` sends
«/test …», the reply is in the chat). **The test mod** (`src/server/test_mod.gd`, `TestMod`, decision 189) is how
the sending of mods' files is checked from a phone, where a server's mods are the build's own: «/test mod on»
makes the server write a few files of its own (`user://test_mod`: a new item `core:test_mod` with its icon and
name, five animals painted another colour and named with a number, the jump's two sounds; about 60 files, 190 KB)
and play with them put over its mods' (`Server.mods_over`), so that no build has its files and every game that
joins takes them; everyone in the world is given the item. «/test mod next» writes the next step (another colour,
pitch and number: a reload the games in the world take), «/test mod off» takes the files away (and the item from
the bags). Only a server that is its own process (not one made in a game: that one reads what the game reads); a
build without raw pictures (a phone's) paints no animals. On the page it is the section «Test mod»: the switch
«With the test mod» (`Settings.test_mod`: the mod's icon `ModFiles.TEST_MARK` is among the server's files the
game plays with) and «Change the mod and reload». The switch «Cheats on the server» sends the page's settings
(`Protocol.CHEATS`, `Settings.send_cheats` on every `apply` and once the season, weather, moon, hour) — on a
server for checking and from the host of any server `src/server/cheats.gd` takes them like its own game: speed
and pace of work, jumps in the air (`Player.cheat_air`), skills' growth, overload, hunger, thirst, tiredness,
cold — one's own; building, wear, making, free items, animals' attacks, the clock — the whole world's
(`Requests.may_cheat` = `Config.playtest` or a host; on a server for checking AI debugging is for everyone
too). The link is the status `playtest-link` of the launch's commit. The bots are games with `--join … --bot`
(`src/client/input/bot.gd`, `Main.bot`): instead of keys `Bot.move` gives the walking direction and once in a
few seconds takes a task (`TASKS`): walks near the spawn point, writes in the chat, a gesture, drops a thing,
puts a sign with an inscription and a campfire, chops a tree nearby, hunts an animal with `health` nearby (the
animals answer by their own rules); takes things `CRAFT_FREE` by recipe, a dead one revives itself; enters with
no key (each time as a new player: the bots of one machine would otherwise share a key and knock each other
out) and goes with `Engine.max_fps = Bot.FPS`, so as not to take the processor from the server. Once per
`LOAD_EVERY` when there are players the server writes frames per second and the longest frame into the log.
«Testing» → «Start the test server» opens the workflow's page, «Join the test server» finds the address
through GitHub's open API (`src/client/net/playtest.gd`: a running launch → the status of its commit) and
enters under the name from `ServerList`.

**Tests.** `tests/unit/mod_files_test.gd` (the mods' files: the list of a set and its hash, the server's side
and the game's over a wire inside the test, the game playing with the files taken, the cache). `tests/server_test.gd`
(`_mods`: the refusal `mods`, the list and files over a socket, `hello` again on the same link, a reload told to
the players; `_reload_reaches`: a game in the world takes a reload; `_game_takes_mods`: the game joins a server
with other files, takes them, restarts its scene and plays with them; and the server's scene in the test's process, bots through `socket.gd`: the entry
and the welcome with the world, the entry events — `you`, `clock`, `props`, `teleport`, each animal once;
refusals — version, password, a full server, a word before `hello`; the body from `input`, digging and the
queue's pause through a socket with events before the reply, the animals' and clock's snapshots go, the chunks
around the body come as the world's records; a broken link — the character waits, a return by the key as the
same one with the same bag, the request numbers anew; then the game itself (`scenes/main.tscn` with
`join_url`) enters the server: the world from the sent chunks, the body where the server put it, the copies of
things, animals and the clock are full, another player's digging and one's own change the copy's cells, what
was dug lies on the ground as a list; `bye` and a short wait; `who`, `say`, `kick` with code 4001, `stop` — the
port is closed, nobody enters; one's own server from the menu `LocalHost.host` and the host's commands give /
tp / ban / unban / whitelist with refusals by key and name; the С7 tunnel with a fake cloudflared — a script
that prints an address: the address, the link in the log, the process killed on `stop`; `url_in`,
`--tunnel`). `tests/unit/net_test.gd` (messages there and back; through the loop: entry with `clock` and
`props`, `input`, digging, crafting and a tick with the events `you`/`shop`/`made` before the reply, `vitals`
only on a change, a chest by a cell and its `chest`, a thing by a cell into the copy and out of it, a campfire
put out, an animal born / running / pushed / left in the copy (`snap` only when it moved), a drop and `drops`,
death and `revive` with `teleport`, `say` once; a clock snapshot of another shape is refused; a request that
does not fit; a repeat and a stale number; leaving — and nothing more about the world); `_test_layers` in
`content_test.gd` (`net/` loads only `content/`, `src/server/` does not load `src/client/`, the client loads
`src/server/` only from `local_host.gd`); `save_test` (death through the server, a dead world, the server node
under the root and goes away with the scene), `progress_test`, `frame_test` play through the loop.
