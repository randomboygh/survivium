# Server for checking and tests

Part of [Protocol and server](../network.md). A server for checking on GitHub and the tests.

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
its new world (`ServerLink.world_mods` takes `hosted.mods`). In the welcome the server says `playtest` and `host` (is the
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
too); once, `at` puts the body at a point (`Player.teleport`): the «Go» of the «Markers» tab
(`Character.go_to_column`, again when it lands) and «To the place of death». With the switch off (or refused by the
server, which turns it off) the tabs «World», «Player» and «Markers» show their switches and «Go» faded with a line
saying why (`Settings.may_cheat`, `SettingsMenu._cheats_note`); «Give tools» and «Clear territory» work only in a
world of this device. The link is the status `playtest-link` of the launch's commit. Where no process of the game can be started (a server made on a phone, `TestCommands.can_start_bots`), a bot is played by
the server itself: `Server.add_bot` makes an account with no connection (`Account.bot`: it never lingers and goes, it
is not saved, its events are dropped), `src/server/server_bot.gd` (`ServerBot`, stepped by `TestCommands._process`)
walks its body by `Body.step` and makes its requests through its `Requests` (paced) with the tasks and lines of the
game's bot (both extend `src/shared/game/bot_brain.gd`: the pace, `TASKS`, `LINES`, the task's state, `best_weapon`), given what it works with; «/test bot-» takes it out (`Server.remove_bot`). Elsewhere the bots are games with `--join … --bot`
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
