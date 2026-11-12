# Anti-cheat: detection and measures

Status: ACTIVE (stage 7, 2026-11-06). The main principle — the server does not accept a ready result: it
counts the yield, crafting, damage, strengths and the body's place itself. Detection here is not a proof of
cheating but a signal to the host; there are no automatic permanent bans. A Russian copy:
[ANTI_CHEAT_RU.md](ANTI_CHEAT_RU.md).

## What is noticed

| Kind of entry | From where | What it means |
|---|---|---|
| `pace` | `Requests` | a request of the hands' work came when the work ahead is more than `WORK_AHEAD` |
| `malformed` | `Requests`, `Server._take` | a request not of the right form or not a message |
| `flood` | `Server._within_rate` | messages more often than `MSG_RATE` |
| `connections` | `Server.poll` | too many connections without a greeting |
| `login` | `Server._hello` | a refusal by password, ban, list, frequency |
| `command` | `Server._on_chat` | a «/» command without a role |
| `role`, `give`, `kick` | `Server.command`, `kick` | giving and taking away a role, giving things, disconnection |

The refused steps of the body are only counted (`Player.refused_moves`) and are not written to the log: an
honest network delay gives refusals too; the measure for them is the body's return (below).

## Levels of reaction

1. **An entry** (`Server.flag`, level 0–2) — always.
2. **A repeated check** — every request is checked by the rule anew by the server's state.
3. **A refusal of the request** — `null`, `false` or `{}`; nothing changes.
4. **A temporary limit** — the pace of work, skipping messages beyond the frequency, a wait on password
   guessing.
5. **The body's return** — after `STRIKES` refusals in a row the server puts the body where its own body got
   to.
6. **Disconnection** — only on a flood (`FLOOD_KICK` seconds of excess), code 4003.
7. **A ban** — only by the host (`ban`), by their decision.

## The security log

`Server.security_log` — the latest `SECURITY_KEPT` 500 entries: the time, the player's number and name, the
kind, the detail, the level. The terminal and the server window get a line «security: …», no more often than
one per kind and player in `SECURITY_EVERY` 10 s (the rest are counted in «and N more»). The filter is the
command `security <kind or name>`. Keys and passwords are never written.

## Tolerances for honest players

The network loses and shuffles messages, the frames are different for everyone, the bodies on the client and
on the server diverge a little (ice, corners, beasts' pushes). So: the place's tolerance is 2.5 cells, the
pull of the server's body 2 cells a second, 10 refusals before the return, 2 seconds of work «ahead», the
message frequency twice what the game sends at 144 frames. Tighten these numbers only by measurements from a
phone.
