# Teams and territory

Status: ACTIVE (steps Т1 — teams, Т2 — the boundary post and plots, Т3 — rights and protection, Т4 —
respawn at the team's campfires and leaving the game, Т5 — PvP, Т6 — the decay of abandoned land; buildings outside the land decay (started); the idea
`plan/design/territory-pvp.md`, decisions 15, 39, 48, 50, 71, 101, 102; the user's choice of 2026-11-02: 1А
2А 3А 4А 5А). A Russian copy: [territory_RU.md](territory_RU.md).

**Purpose.** Players' teams on a server: who is with whom, how they are called and leave; the land that a
player or a team has taken. The rule is decided by the server, the client only asks and shows. In single
player a team is not needed, but the code is the same (the session always holds `teams` and `territory`; the
single player's player is number 0).

**Where to look.** This page is the overview; the files and the detail are split by topic into `territory/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| Teams, the boundary post and plots. | [territory/teams-land.md](territory/teams-land.md) |
| Rights, protection, the post, colour, the tab, the map. | [territory/rights.md](territory/rights.md) |
| Respawn at the team's campfires, PvP, the decay of abandoned land. | [territory/respawn-pvp.md](territory/respawn-pvp.md) |

**Tests**: `tests/unit/decay_test.gd` (the paces of the materials, the ground and the generator's cells
untouched, a player near and a claim tend, cracks stay when one comes back and go when the cell changes,
saving through JSON, both switches, the session's step, `CRACKS` over a socket and the loop, the faster swing,
the mesher's mark; `_test_ruins`: a wall row by row to its cracked lowest row, a roof, a long neglect at once, a
fence falls apart and a chest stays, what fell is told, rubble gives about half); `tests/unit/security_test.gd` `_test_mend` (the mend's checks and pace); `tests/unit/territory_test.gd` (`_test_decay` — decay by steps, the client's copy, saving, the
team's return, the modes `rights` and `radius`; the teams' rules, saving through JSON, the requests of two
players on one server; plots, the budget, connectivity, the post through `put_from_bag` and `land_paint`; the
default and given rights, saving, the land's colour and the request `land_color`, digging, a chest, taking a
thing and walking on another's land; a campfire remembers who placed it, which respawn points whom, `revive`
only to them, `at_home`; `_test_pvp`: a blow, damage, one's own, a newcomer, modes, the right on land, the
tag, saving), `tests/server_test.gd` `_chat` (an invitation, consent and a team line through a socket).
Shots: `tools/shot.gd` `team-person`, `team-invite`, `team-panel`, `land`, `land-paint`, `land-rights`,
`land-colors`, `land-decay`, `ui-test-player-end`, `death-fires`.
