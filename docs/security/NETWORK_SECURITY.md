# Defence of the network protocol

Status: ACTIVE (stage 7, 2026-11-06). How the server accepts the client's bytes. The whole protocol —
[../systems/network.md](../systems/network.md); the threat model — [THREAT_MODEL.md](THREAT_MODEL.md). A
Russian copy: [NETWORK_SECURITY_RU.md](NETWORK_SECURITY_RU.md).

## Transport (`src/server/server.gd`)

| What | Value | What happens beyond it |
|---|---|---|
| An incoming frame | `INBOUND` 256 KB (the outgoing `BUFFER` 4 MB for chunks) | the frame is not accepted |
| Connections with no greeting | `PENDING_MAX` 16, from one address `PENDING_PER_ADDRESS` 4 | a new connection is closed at once, an entry in the log |
| Time for the greeting | `HELLO_WAIT` 10 s | closing with code 4000 |
| Messages per second | `MSG_RATE` 300, in a burst up to `MSG_BURST` 600 | the extra ones are not read; at `FLOOD_KICK` 3 s of excess — disconnection, code 4003 |
| A wrong password | `PASSWORD_TRIES` 8 per `PASSWORD_WINDOW` 60 s from an address | new players from the address — a refusal `wait`; a player with a known key gets in |
| New players | `NEW_PLAYERS` 10 per `NEW_WINDOW` 60 s | a refusal `wait` (players' files do not pile up without limit) |

`bytes_to_var` parses a frame without objects (`allow_objects` is off): no engine object is created from the
network. A message that is not an array, a kind that is not a string — an entry `malformed` in the log, the
message is skipped. The comparisons of a message's kind go after the check of the type, so garbage does not
crash a server function. Behind a Cloudflare tunnel all connections come from this same machine: the limits
by address are shared for them, so a player with a key does not suffer from another's password guessing.

## The greeting (`Server._refusal`)

- The versions of the protocol and the build match (`WHY_VERSION`), the key is a string of no more than 64
  characters.
- The name is cleaned by `Protocol.clean_text` (control characters, line breaks, direction marks and
  invisible characters), not empty (`WHY_NAME`), not from `RESERVED_NAMES` and not taken by another key in
  the world (`WHY_TAKEN`).
- The password is compared by hash in constant time (`_same`).
- A ban by key and by name (`WHY_BANNED`); the whitelist — a name bound to the key it came with first
  (`access.listed_keys`, `WHY_LIST`).
- The key is 16 random bytes from `Crypto`; in the player's file on disk — only the first 32 characters of
  its SHA-256.

## Requests (`src/server/requests.gd`)

Each request is `[kind, number, arguments]`. The number grows: a repeat of the same one is answered with the
former answer and is not done again, a smaller one is refused (`null`). The arguments are checked by types
(`_fit`). All the players' requests are done one whole at a time, with no tick between them: two who took
one stack will not double it.

| Request | What the server checks |
|---|---|
| `dig`, `place`, `front`, `gather`, `plant`, `plant_at`, `prop_put`, `light_put` | the reach of the tool or hand, land rights, strengths; **pace** — `paced`, no more than `WORK_AHEAD` 2 s of work ahead |
| `eat`, `throw`, `wear`, `repair` | the cell's number within the bag's bounds |
| `bag_put`, `bag_move`, `bag_all`, `sort`, `bag_destroy` | cells within bounds (and in `Inventory`), the chest within the hand's reach and by the right «chests», an open bag is not put into itself |
| `prop_take`, `prop_open`, `prop_destroy`, `lie_in` | the thing within the hand's reach, land rights |
| `prop_move` | two cells and a turn 0..3; the thing within the hand's reach and `Placed.movable`, its new place within `Tools.PLACE_REACH` and free, land rights at both ends; **pace** — `paced` |
| `gesture` | the name is a string from `Gestures.LIST` or ""; changes nothing in the world |
| `sign_write`, `sign_turn` | the sign within the hand's reach, the right «build»; the text is a string of no more than `Requests.SIGN_MAX` 600, the lines are cleaned by `Protocol.clean_text` and cut to the sign (`Placed.sign_text`); **pace** — like the hands' work (`PACED`) |
| `prop_fire` | within reach; to put out — only by the right «build» on another's land |
| `plan` | the kind of figure, the size by the corners before building (`Plans.too_big`), the corners within `PLAN_REACH` 64 cells of the player |
| `craft`, `craft_cancel`, `craft_pause` | the recipe is known, the station is near, the materials are there; the debit and the issue — whole; a cancel returns what was taken, as it was |
| `craft_free` | only with the rule `free_items` (off by default, on a server — from its settings); the recipe's id is a string from the registry |
| `give_all` | a bool; `true` only with the rule `free_items`, the bag at most `Inventory.MOST_GROWN` slots wider; `false` only narrows one's own bag |
| `chat`, `team_chat` | `clean_text`, up to `CHAT_MAX` 160 characters, `CHAT_LINES` 5 per `CHAT_WINDOW` 8 s |
| `team_*`, `land_*`, `fight_brave` | the rules of `Teams`, `Territory`, `Fights` by the server's player number |
| `revive` | only the dead, only at their own points or where they fell |

## The body (`src/server/player.gd`, `input`)

By the socket (`check_moves`):

- the place — `_take_claim`: the server's body walks to the sent place in the time since the last `input` (no
  more than `CLAIM_GAP_MAX` 0.5 s and no more than has passed: frequent messages give no extra path); the
  place is taken if the body has got closer than `MOVE_TOLERANCE` 2.5 cells and the place is not inside a
  wall; the server's body is pulled to the accepted place no faster than `CATCH_UP` 2 cells a second;
  `STRIKES` 10 refusals in a row — `teleport`;
- the feet — the cell of the accepted place, the gaze — one of 8 steps, jumps in the air of the test page are
  not taken, the screen's size up to `VIEW_MAX`, non-numeric values (NaN, infinity) — the message is skipped;
- the hands — `in_hands`: only what is in the bag; one thing — in one hand.

By the loop (single player) everything is taken as it is: the player is the server.

## The mods' files (`content_host.gd`, `mod_fetch.gd`, decision 189)

A game whose files differ from the server's is refused with `WHY_MODS` and keeps its link, with no character,
to take the files; both sides distrust what comes.

The server, to a link that takes files:

| What | Value | What happens beyond it |
|---|---|---|
| Time to take the files and greet again, and to ask for nothing | `FETCH_WAIT` 900 s, `FETCH_IDLE` 30 s | closing with code 4000 |
| Links taking files at once | `FETCHING_MAX` 32 | a refusal `wait` |
| Hashes in one `mod_files`, and waiting in all | `ASK_MAX` 256, `QUEUE_MAX` 4096 | the message is not taken (`malformed`) |
| Lists sent to one link | `LISTS_MAX` 8 | no answer |
| Bytes of files sent to one link | `SENT_MAX` 3 sets | the files come back as «cannot give» |
| Speed | `RATE` 2 MB/s, `BURST` 512 KB, nothing added above `BUFFERED_MAX` 512 KB waiting | the rest waits |

A file is found by its hash in the list read from disk, never by a path from the socket: nothing outside the
world's set can be asked for. Only a greeting right in all but the files (the password, the ban, the
whitelist) opens the files; such a link is counted apart from those without a greeting (all of a tunnel's
come from one address), and the message rate (`MSG_RATE`) holds for it too. A file changed on disk after the list was read is not sent (its
hash is checked again): the host is told to `reload`.

The game, of a server (`ModFiles.unpack`, `may_be`, `ModCache.store`):

- the list: packed no more than `LIST_MAX` 4 MB, `FILES_MAX` 20000 files, a file up to `FILE_MAX` 8 MB, the
  set up to `SET_MAX` 256 MB; a path is plain letters, digits, `_`, `-`, `+`, `.` and `/`, no part beginning
  or ending with a dot, at most `PATH_MAX` 160 characters, ending in `.yaml`, `.png` or `.wav` (`valid_path`); the list's hash
  must be the one the refusal named;
- a file: the bytes' hash is the list's, the size is the list's, a piece unpacks to no more than `PIECE_MAX`
  1 MB; a picture has a PNG header and sides up to `PICTURE_MAX` 2048, a sound a RIFF/WAVE header, a YAML is
  read by the game's own parser (`yaml.gd`: dictionaries, arrays, strings and numbers only); it is kept under its hash in `user://mod_cache`, never under the server's path;
- more than `ASK_ABOVE` 50 MB is taken only after the player agrees; a server silent for `STALL` 20 s ends
  the taking; after `MODS_TRIES` 3 refusals in a row the game stops trying;
- what comes is data only: YAML, pictures, sounds, translations. No script, scene or resource is loaded from
  a server (the kinds are a closed list), and the cache passes `LIMIT` 200 MB only until the next trim.

A server's files are used only while the game is on that server: the menu and other worlds read the game's
own (`Content.serve({})`).

## What the client sees

The engine's errors and the internal reasons do not go to the client: a refusal is `null`, `false` or `{}`, a
refusal of the greeting — one of `WHY_*`, a disconnection — a short phrase and a code. The security log is
only on the server ([ANTI_CHEAT.md](ANTI_CHEAT.md)).
