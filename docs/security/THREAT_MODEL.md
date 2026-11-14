# The threat model

Status: ACTIVE (stage 7, 2026-11-06). What the server protects, from whom, and where the trust boundaries
run. The findings and fixes — [../audit/SECURITY_AUDIT.md](../audit/SECURITY_AUDIT.md),
[../audit/SECURITY_REMEDIATION_REPORT.md](../audit/SECURITY_REMEDIATION_REPORT.md). A Russian copy:
[THREAT_MODEL_RU.md](THREAT_MODEL_RU.md).

## What we protect

| Asset | Where it lives | Why it matters |
|---|---|---|
| The bag, what is worn, chests, things on the ground | the server: `Character.inventory`, `Placed`, `WorldData.drops` | a dupe and theft break the economy and others' work |
| The world: cells, shrubs, trees, the blueprint | the server's session (`WorldData`, `Plans`) | spoiling others' buildings, hanging the server |
| The body: place, health, strengths | `src/server/player.gd`, `Vitals` | teleport, speed, invulnerability |
| Crafting, skills, knowledge | `Workshop`, `CraftQueue`, `SkillSet` | things from nothing, levelling without playing |
| Land, teams, PvP | `Territory`, `Teams`, `Fights` | bypassing the rights on others' land |
| The host's rights | `Server.access` (`access.json` in the world's folder) | privilege escalation, bans, giving out things |
| The player's key | on the client `user://servers.cfg`; on the server a hash names the player's file, but `access.json` keeps the keys themselves (hosts, owners, bans, the whitelist), so that file is as secret as the keys | the key is the only «identity» |
| The server's availability | the server process | one player must not hang or clog it |

## Who attacks

- **A player with a modified client**: sends any bytes by the protocol, any arguments and any frequency;
  knows the protocol (the code is open).
- **A stranger without a key**: connects to the port or the tunnel, guesses the password, floods with
  connections.
- **An impostor**: takes a friend's name or «Server» to deceive in the chat or to be passed off for the
  host's command.
- **A host by `op`**: trusted, but not the server's owner.

Outside the model: whoever sits at the server's machine (they have the world's files and the terminal), and
single player (the server is in the same process, the player is the host — by the loop the body and hands
are taken as they are).

## Trust boundaries

```
client (browser, PC) ──WebSocket──▶ Server.poll ──▶ PlayerLink.handle_msg ──▶ Requests / Player.take_input ──▶ the rules of src/shared/game/
     not trusted                    size, frequency,   the message's type        types of args, reach,             decide themselves by the
                                    the greeting        (input / request)         pace, land rights                 server's state
```

1. **Socket → server.** Before the greeting only `hello` is read; the size of an incoming frame, the number
   of waiting connections and the frequency of messages are limited (`Server.INBOUND`, `PENDING_MAX`,
   `MSG_RATE`).
2. **Greeting → account.** The identity is the server's random key (16 bytes), not the name. The name is
   only a signature: cleaned, unique in the world, the server's names are taken. The whitelist binds a name
   to a key.
3. **Request → rule.** The arguments are checked by types (`Requests._fit`), the bag's cells by bounds,
   things and chests by the hand's reach, cells by land rights. The result is counted by the rule, the
   client sends only an intention.
4. **`input` → body.** The client moves its own body (decision 153, 3А), the server runs its own body
   (`body.gd`) for the elapsed time and takes the client's place only if the body has almost got there. The
   feet, the gaze, the hands are derived by the server, not the client's words.
5. **Chat → commands.** The role is determined by the server by the connection's key (`Server.role_of`), not
   by the client.

## Entry points

All the client's messages are in `src/shared/net/protocol.gd`: `hello`, `input`, `bye` and the requests (dig,
place, act, gather, pick up, plant, eat, throw out, things on cells, doors, blueprint, crafting and the
queue, repair, the bag and chests, clothes, sleep, revive, chat, commands, land, PvP). Each goes through
`Requests._rule`; the table of checks — [NETWORK_SECURITY.md](NETWORK_SECURITY.md).

## Attack scenarios (in general)

| Class | Example | Where it is closed |
|---|---|---|
| Faking a result | «a pickaxe in the hand», «I stand there», «the feet are here» | `Player.in_hands`, `_take_claim`, feet from the body |
| Speed and teleport | frequent small jumps, flight by test jumps | time instead of the number of messages, `CATCH_UP`, jumps in the air only by the loop |
| Instant work | a hundred dig requests at once | `Requests.paced`, `WORK_AHEAD` |
| A dupe and spoiling things | cells «from the end», a repeated request, two players at once, a cut link | bounds in `Inventory`, the request's number, one request whole, the save's snapshot |
| A cancel with profit | cancelling a craft returned new things instead of worn ones | `CraftQueue` stores what was taken |
| Denial of service | a huge blueprint, a flood of messages and connections | `Plans.too_big`, the server's limits |
| Bypassing access | a name from the whitelist, guessing the password | `listed_keys`, `PASSWORD_TRIES` |
| Impersonation | the name «Server», a friend's name, a line break in a name | `RESERVED_NAMES`, uniqueness, `Protocol.clean_text` |
| Privilege escalation | a host by `op` stops the server or hands out `op` | `Server.COMMANDS` with roles |
