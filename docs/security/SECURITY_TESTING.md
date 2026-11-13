# Security tests

Status: ACTIVE (stage 7, 2026-11-06). All the checks are local only: the server is brought up in the test's
process on its own port (`server_test` — 7791, 7792), the bots connect to `127.0.0.1`. Real servers and
players' saves are not touched. A Russian copy: [SECURITY_TESTING_RU.md](SECURITY_TESTING_RU.md).

## Where

| Test | How to run | What it checks |
|---|---|---|
| `tests/unit/security_test.gd` | `godot --headless --path . --script res://tests/run_tests.gd -- security` | the rules without a socket: the hands only from the bag, the feet and gaze from the body, frequent «jumps» of the place do not carry the body away, a place inside the ground is not taken, the pace of work, a huge and far blueprint, sorting and «all into the chest» from a cell «from the end», cells outside the bag, a craft's cancel returns the worn and is stored in the save, `clean_text`, the server's names, phrase keys and taken ones, a bot's key, the whitelist by key, password guessing and entering by key, the commands' roles |
| `tests/server_test.gd` `_security` | `timeout 900 godot --headless --path . --script res://tests/server_test.gd` | by the socket: a taken name and the name «server», a flood of messages — disconnection 4003 and an entry in the log, a host by `op` cannot `stop`, a chat line without a line break and hidden characters |
| `tests/server_test.gd` (older) | the same | refusals of the greeting (version, password, a full server, a word before `hello`), a repeat of a request's number, two players take one stack, a cut link in the middle of a transfer, a chest out of reach, a body's jump far away is returned, a body's move at pace is taken, a ban by key and name, the whitelist, commands only for the host |
| `tests/unit/net_test.gd` | `run_tests -- net` | an unsuitable request and `input`, a repeated and an outdated number |

Before a repeated local run of `server_test` delete `user://test_saves/server`, `user://server.cfg` and
`user://test_server.cfg` (the folder `~/.local/share/godot/app_userdata/Survivium/`): otherwise the test's
server reads the port and the world of the last run and the greeting is not answered.

## The spec's scenarios and where they are

| Scenario | The check |
|---|---|
| a nonexistent item | `craft` with an unknown recipe → `null` (`net_test`), a tool not from the bag → the hands (`security_test`) |
| change the quantity | cells «from the end» and outside the bag (`_test_bags`) |
| crafting without materials | `Crafting.take` — the materials are checked (`actions_test`, `net_test`) |
| gathering without a tool | `_test_body`: a tool in the «hand» without the bag — the hands |
| a station without access | `Workshop.why_not` — the station is near (`actions_test`) |
| a repeat of an operation | a repeat of the number (`net_test`, `server_test` `_trades`) |
| parallel operations | two players one stack (`_trades`) |
| a forged chat sender | the name is taken / the server's name (`_test_door`, `_security`) |
| a command by an ordinary player | `_chat`, `_test_commands` |
| incorrect arguments of commands | `give` without an item, `tp` with non-numbers (`_commands`) |
| exceeding the frequency | `_security` (a flood), `_test_requests` (pace) |
| big messages | `INBOUND`; a long key and line (`_test_door`, `_test_text`) |
| incorrect data | a word before `hello`, an `input` of another form (`server_test`, `net_test`) |
| a disconnection during an operation | `_trades`: a cut in the middle of a transfer |
| reconnection | a return by key with the same bag (`server_test`) |

## How to add a check

A rule without the network is a function in `security_test.gd` (a player «by socket» — `_socket_player`). A
scenario through a socket goes in `_security` of `server_test.gd`, the bots `_bot(name, key, password,
port)`. Every found vulnerability gets its own regression check.
