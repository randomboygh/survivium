# Protocol and server

Status: ACTIVE (server stages С2.1–С6, decision 153; the plan `plan/architecture/server.md`). A Russian copy:
[network_RU.md](network_RU.md) (it may trail this page: it is caught up weekly).

This page is the overview; the detail is split by topic into `network/`. Read the overview, then only the
page the change reaches (`grep -n '^#' docs/systems/network/<page>.md` first if it is long).

**Purpose.** What the client asks of the rules goes in messages: a request `[kind, number, args]`, a reply
`[number, value]`; what one side tells the other with no reply is an event `[kind, args]`. The bytes are
`var_to_bytes` with no objects. The player's character and workshop live on the server (`src/server/player.gd`),
the things, the clock and the animals in the server's session; the client holds copies that `Mirror` feeds.
In single player the same bytes go through a loop in one's own process (`LocalHost`, the server inside the
game); over the network they go through a WebSocket to a server from the terminal (`--server`, joined by
`--join ws://…` or the menu's «Join»). The client always plays through the protocol. The server trusts nothing
a socket sends: reach, land rights, types and bounds of every argument are checked, requests are done one at a
time, a number not higher than the last is not done twice.

**Where to look**

| Topic | Page | Key files |
|---|---|---|
| The full purpose, the messages, `hello`/welcome, the requests the server does | [network/protocol.md](network/protocol.md) | `src/shared/net/protocol.gd`, `src/server/requests.gd` |
| The server: the character, a player's link, the server node, saving, settings, tunnel, console | [network/server.md](network/server.md) | `src/server/*` |
| The client side: connection, copies of the world, mod files, the server inside the game, the link | [network/client.md](network/client.md) | `src/client/net/*`, `src/client/game/character.gd` |
| Who calls the protocol, what stays direct, pitfalls | [network/pitfalls.md](network/pitfalls.md) | `Reply`, `WorldActions` |
| A server for checking on GitHub, the tests | [network/testing.md](network/testing.md) | `.github/workflows/playtest.yml`, `tests/server_test.gd` |

Security rules: [NETWORK_SECURITY](../security/NETWORK_SECURITY.md), [ANTI_CHEAT](../security/ANTI_CHEAT.md),
[COMMAND_PERMISSIONS](../security/COMMAND_PERMISSIONS.md).
