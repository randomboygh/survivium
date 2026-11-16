# Protocol and requests

Part of [Protocol and server](../network.md). The purpose, the protocol and the requests the server does.

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
(`access.hosts`: those given `op`, and the player who made the server in the game — `ServerLink._on_welcome` →
`make_host`), the reply to it comes in the chat to him alone. The hosts online are told the server's comings and
goings by the event `noted` [line] (`Server._note`, a `Lang.line`: joined for the first time, back, lost the
connection, left, the character left the world, disconnected or banned by a host, too many messages, not let
in with the reason `Server.WHY_NOTES`), never about themselves; the HUD shows them apart (`Hud.server_note`). Teams (Т1, [territory.md](../territory.md)): the
requests `team_*`, the events `team`, `invites`, a line to the team (`team_chat`) — to all its members in the
world; in `heard` the fourth field is «said to the team», in `people` the last is «in my team». Land (Т2, Т3):
the requests `land_paint`, `land_rights`, `land_color`, the events `claims`, `squares`, `land`. PvP (Т5): the
request `fight_brave`, the event `fight`. AI debugging (decision 184): the request `ai_debug` [on] — only with
`Requests.may_debug` (single player — `LocalHost.join`; on a server the host, `Server` sets it before every
message by `is_host`, a host who is removed loses even a switched-on debug), the event `minds`
(`Wildlife.mind`) once per 0.25 s. An author's own mod (stage 2 item 3, step 7): the request `mod_put` [mod,
piece, pieces, bytes] — only with `Requests.may_author` (a host, set like `may_debug`), the editor's zip in
pieces of `MOD_PIECE` 128 KB in order, answered `true` per piece and `{files, skipped, error}` for the last
(`Server.put_mod`: the mod in its folder, its bundles in the world's, `mods` to every player); see
`docs/security/NETWORK_SECURITY.md`. No more often than `Requests.CHAT_LINES` 5 lines per `CHAT_WINDOW` 8 s,
length up to `CHAT_MAX` 160.

- `src/shared/net/protocol.gd` — the protocol version, the kinds of requests with their args (dig, place,
  the action in front, gather, pick up, plant, eat, drop, place/take/put out/destroy a thing, crafting and its
  queue, repair, move/pour/sort/destroy in the bag and chests, revive), `request`, `reply`, `encode`, `decode`.
  Loads only `content/`. Through a socket each message is one binary frame; the first request on it is
  `hello` ([protocol version, the build's version `build_version()` — from `build_info.json`, «dev» without
  it; a name, the key from last time or "", a password, the hash of the mods' files the game plays with —
  `Content.playing()`]), the reply is a welcome `{"ok": true, "id", "key",
  "name", "seed", "settings", "mods", "materials", "spawn", "at"}` or a refusal `{"ok": false, "why": version |
  password | full | name | banned | list | taken | wait}` (`taken` — the name is taken by another in the world
  or it is the server's name or a translation key — so a name the game gave when the player set none (`[host]`, `[player_n2]`) goes in words, a player's with four figures from the key, `ServerLink.sent_name`; `wait` — many wrong passwords or new players in a row), after which the server
  closes the link; the refusal `mods` (decision 189: the game's mod files are not the server's) also carries
  `mods` (the server's bundles), `content` (the hash of its files) and `size`, and does not close the link: the
  game takes the files it lacks and says `hello` again (the events `mod_list` [] → [size, bytes], `mod_files`
  [[hash…]] → `mod_data` [[hash, offset, the file's size, the piece's size before packing, the piece]…]; `mods`
  [hash, size, bundles] — the server's files changed, to a game in the world; `rules` [Rules.to_dict] — the
  rules of play the server runs, after the welcome and whenever they change: a game joined over a socket shows
  by them the craft tab's «get» and free building, never by its own «Testing» switches). The event `bye` — the client
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
