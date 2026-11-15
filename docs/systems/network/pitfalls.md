# Who calls, what stays direct, pitfalls

Part of [Protocol and server](../network.md). Who calls the protocol, what stays direct, the pitfalls.

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
