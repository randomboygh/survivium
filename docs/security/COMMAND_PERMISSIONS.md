# Commands and rights

Status: ACTIVE (stage 7, 2026-11-06). One table of rights — `Server.COMMANDS` in `src/server/server.gd`; the
server determines the role by the connection's key (`Server.role_of`), every time anew. A Russian copy:
[COMMAND_PERMISSIONS_RU.md](COMMAND_PERMISSIONS_RU.md).

## Roles

| Role | Who | How it is got |
|---|---|---|
| player (`ROLE_PLAYER`) | everyone | by default; gives no commands |
| host (`ROLE_HOST`) | a trusted player | `op <who>` of the owner or the terminal; `access.hosts` |
| owner (`ROLE_OWNER`) | the player who created the server in the game | `Main._on_welcome` → `make_host`; `access.owners` |
| terminal (`ROLE_CONSOLE`) | the server's console and the command field of the «Create a server» window | the server process, not the network |

The lists are stored in `access.json` of the world's folder. A taken-away role (`deop`) works from the next
command, with no restart. The client does not send a role: there is no role field in the protocol.

## Commands

| Command | Arguments | The role needed | What it does |
|---|---|---|---|
| `who` | — | host | who is in the world, where |
| `say` | words | host | a line in the chat to all from «Server» |
| `kick` | a name or number | host | disconnect, the character leaves |
| `give` | who, an item (id, the end of an id, a title), how many 1–999 | host | into the bag; an entry in the security log |
| `tp` | who, `x y z` (whole cells) or to whom | host | move |
| `ban`, `unban`, `bans` | a name or number | host | a block by key and name |
| `whitelist` | `on`, `off`, `add <name>`, `remove <name>` | host | let in only one's own; a name is bound to a key |
| `hosts` | — | host | who the hosts and owners are |
| `security` | a kind or a name | host | the latest entries of the security log |
| `reload` | — | host | reread the mods' data from disk (hot reload) |
| `help`, `?` | — | host | the list |
| `op`, `deop` | who / a name | owner | give or take away the host's role |
| `stop` | — | owner | save and stop the server |
| `test` | `bot+`, `bot-`, `worlds`, `world <folder>`, `new [seed]`, `new test`, `mod on\|off\|next`, `stop`, `hour` | on a server with `--playtest` — any player; on another — the host (`stop` — the owner) | bots, another world of the server (the name of a folder under the saves, not a path), stopping, the term of a test server (`TestCommands`, `PlaytestHost`) |

A command in the chat begins with «/»; from a player without a role — a refusal and an entry `command` in the
log; an unknown one — «unknown command»; without the needed role — «only for the server's owner». Every
command from the chat is written to the server's log with the name and number. The server has no hidden
commands. On a test server (`--playtest`, set only on the command line, `.github/workflows/playtest.yml`)
«/test» and the request `cheats` (the settings of the «Testing» page, `src/server/cheats.gd`: each value is
checked by type and clamped to bounds) are available to any player; on any other — only to the host, a player
without a role gets a refusal to `test`, `cheats` — false (`Requests.may_cheat`).

## How to add a command

1. A branch in the `match` of the function `Server.command` (the arguments are strings: check the number and
   the bounds).
2. A row in `COMMANDS` with a role; without it the command is considered unknown.
3. A row in `help` and in the table above; a check in `tests/unit/security_test.gd` `_test_commands`.
