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
| `gesture` | the name is a string from `Gestures.LIST` or ""; changes nothing in the world |
| `sign_write`, `sign_turn` | the sign within the hand's reach, the right «build»; the text is a string of no more than `Requests.SIGN_MAX` 600, the lines are cleaned by `Protocol.clean_text` and cut to the sign (`Placed.sign_text`); **pace** — like the hands' work (`PACED`) |
| `prop_fire` | within reach; to put out — only by the right «build» on another's land |
| `plan` | the kind of figure, the size by the corners before building (`Plans.too_big`), the corners within `PLAN_REACH` 64 cells of the player |
| `craft`, `craft_cancel`, `craft_pause` | the recipe is known, the station is near, the materials are there; the debit and the issue — whole; a cancel returns what was taken, as it was |
| `craft_free` | only with the rule `free_items` (off by default, on a server — from its settings); the recipe's id is a string from the registry |
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

## What the client sees

The engine's errors and the internal reasons do not go to the client: a refusal is `null`, `false` or `{}`, a
refusal of the greeting — one of `WHY_*`, a disconnection — a short phrase and a code. The security log is
only on the server ([ANTI_CHEAT.md](ANTI_CHEAT.md)).
