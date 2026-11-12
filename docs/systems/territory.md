# Teams and territory

Status: ACTIVE (steps Т1 — teams, Т2 — the boundary post and plots, Т3 — rights and protection, Т4 —
respawn at the team's campfires and leaving the game, Т5 — PvP, Т6 — the decay of abandoned land; the idea
`plan/design/territory-pvp.md`, decisions 15, 39, 48, 50, 71, 101, 102; the user's choice of 2026-11-02: 1А
2А 3А 4А 5А). A Russian copy: [territory_RU.md](territory_RU.md).

**Purpose.** Players' teams on a server: who is with whom, how they are called and leave; the land that a
player or a team has taken. The rule is decided by the server, the client only asks and shows. In single
player a team is not needed, but the code is the same (the session always holds `teams` and `territory`; the
single player's player is number 0).

**How it is built (Т1)**
- `src/shared/game/teams.gd` — the world's teams: a player has no more than one; one enters a team by an
  invitation of its member (`invite` → `accept`, an invitation waits `INVITE_TIME` 120 s, `decline` — a
  refusal); a player without a team who called another makes a team when the other agrees and becomes the
  senior (`lead`), the name — «Team <name>». Only the senior excludes (`kick`), they also rename (`rename`, up
  to `NAME_MAX` 24 characters); if the senior left, the one who has been in the team longer becomes the
  senior; a team of one falls apart. Players are named by a number on the server (`Player.id`) and the last
  name (`names`, `seen` at login), so the list shows those who are not online too. `together(a, b)`,
  `team_of(id)`, `view(id)` — what a player sees. The signals `changed(ids)` (whose team changed) and
  `invited(to, from, name)`. Stored in the server's `world.json` (`to_dict` / `from_dict`, `ServerStore`,
  `server_main.gd`); the session holds `Session.teams`.
- The protocol (`src/shared/net/protocol.gd`): the requests `team_invite` [number] (a player within
  `Requests.TEAM_REACH` 30 units, as far as the chat is heard), `team_accept` [number], `team_decline`
  [number, 0 — all], `team_leave` [], `team_kick` [number], `team_name` [name], `team_chat` [string]; the
  events `team` [`view`] and `invites` [[[number, name]…], [[to whom, seconds left]…]] (received and sent by
  oneself, `Teams.sent_of`; `PlayerLink` sends at login and when it changes, the sent ones — to the caller
  too), in the `people` record the last field is «in my team», in `heard` the fourth is «said to the team».
  The server gives a line to the team to all its members in the world, wherever they are
  (`Server._on_team_chat`).
- The client: `src/client/game/team.gd` (`game.team`: the team and invitations from the server, requests), a
  press on another player (`Others.person_at` by the gaze's ray, `Controls.tap`) opens the card
  `src/client/ui/person_card.gd` («Invite to the team», for the senior — «Exclude from the team»); an arrived
  invitation opens it at the top of the screen with «Accept» / «Decline». On a server — the fourth tab «Team»
  of the inventory window: `src/client/ui/team_page.gd` (`Hud.open_team`, `InventoryWindow`; no title: the
  roster, the senior, invitations, «You invited: …, waiting for an answer», «Leave the team»), in single
  player it is absent. The names of one's own above their heads and their lines in the chat — in the colour
  `UiStyle.TEAM`; in the chat the button «Nearby» / «Team».
- Teammates on the map: the event `mates` [[[number, name, column]…]] — all live members of the player's team
  in the world, however far they are (`PlayerLink.mates_now`; at login and when someone moved to another
  column, over a socket no more often than `Server.MATES_EVERY` 0.5 s; outside a team — []). The client holds
  them in `Team.mates` (`mates_changed`), the minimap and the map (`Minimap.draw_mates`) draw a round dot of
  the colour `UiStyle.TEAM`, in a light ring and a dark outline, beyond the edge — at the edge in their
  direction; on the big map the name is under the dot.

**How it is built (Т2: land)**
- Land is taken only by a thing with the flag `claims` (the boundary post, `content/tools/boundary_post/`,
  `prop: post`); campfires and stations — no. `Placed.put_from_bag` asks `Territory.can_claim` (not on
  another's land, there is a free plot) and after placing — `add_claim`. Such a thing is not a station
  (`Items.is_station`). A thin post casts no shadow from the sun (`Props.THIN_PROPS`): it is thinner than a
  texel of the shadow map, it gave a wide slab.
- `src/shared/game/territory.gd` (`Session.territory`) — claims (`claims`: the centre — the post's cell, who
  placed it, the name) and plots of 2×2 cells (`SQUARE`, `squares`: plot → claim). A claim's plot holds all
  the levels within `territory_levels` (8) of the centre (`claim_at`). A player or their team paints plots by
  hand (`paint`): next to a plot of the claim that is already theirs, no farther than `territory_radius` (24)
  plots from the centre, not on another's, while the budget suffices; one can erase one's plot, except the
  central one, if the rest stay connected with the centre. The budget (`budget`): `territory_start` (64) +
  `territory_per_level` (8) for each level of all the player's skills (decision 39; `skilled` —
  `SkillSet.total`, updated by `step` from `Session.step_things`; the days lived `played` are only counted);
  for a team — the budget of the biggest member and half of each other. The post removed (`Placed.removed`) —
  the claim goes with all its plots. The numbers are in `Rules`. Stored in the server's `world.json` and in
  the single-player save (`to_dict` / `from_dict`). `from_dict` sends `claims_changed` and `squares_changed`
  again: in single player the player enters before the save is read (`Props.place`), and without this their
  post after re-entering looked nobody's. «Clearing the territory» on the page «Testing» → «Player»
  (`Settings.clear_land`, two presses, only in one's own world) — `clear_painted`: of each claim only the
  post's plot stays.
- The protocol: the request `land_paint` [plot, paint?]; the events `claims` [[[number, centre, who, name]…]]
  (the name — of the team, otherwise of the placer), `squares` [[[plot, claim (0 — nobody's)]…], all?] and
  `land` [taken, can] (`PlayerLink` sends at login and on a change).
- The client: `src/client/game/land.gd` (`game.land`: a copy of `Territory`, the count, the marking mode
  `painting`, the signal `entered` on moving into another claim). `src/client/view/land_view.gd` with
  `shaders/land.gdshader` draws the border lines along the plots' edges around the player (one's own land —
  `UiStyle.TEAM`, another's — red; in marking also the grid of one's own plots). Marking is turned on and off
  by a tap on one's own boundary post or its first square (`Land.tap_post`, `toggle_painting`; a post just
  placed turns it on itself), the HUD by the signal `painting_toggled` shows «taken/can» on the minimap; a
  press on the ground in marking (`Controls._start_paint`) paints a plot if it is not one's own, or erases
  one's own, and so — every plot over which a finger is led. On entering other land — a caption «Your
  territory», «Territory «…»: one may walk here» or «No-man's land».

**How it is built (Т3: rights and protection)**
- The owner of a claim decides what their team and the others may do, at once on all their land:
  `Territory.rights` {player: [the team's mask, the others' mask]}, the bits `ACTIONS` (walk, build and break,
  open doors, take from chests, gather the harvest, touch beasts, hit beasts, hit players; the words —
  `TITLES`). By default the team may do everything (`TEAM_DEFAULT`), the others only walk
  (`OTHERS_DEFAULT`). The owner may do everything themselves; outside claims everything may be done.
  `allowed(claim, id, action)`, `may(who, cell, action)` (with a word to the player), `set_rights`. Stored
  with the land (`to_dict`), comes to the client in `claims`.
- Where it is asked: `WorldActions` (`territory`, `_may`, `_allowed`): digging (`dig`), placing blocks
  (`place_at`), planting (`plant_at`) — «build»; chopping a tree (`chop`), gathering from a tree and a shrub
  (`gather`), mowing (`mow`) — «harvest»; a blow and a shot at a beast (`_wound`) — «hit beasts». `Placed`:
  placing and taking a thing, placing a light — «build»; `Requests`: taking a campfire apart — «build»,
  opening a chest (`_bag`) — «chests». Walking: `Territory.step_walk` from `Session.step_players` returns the
  player to where they last stood on land where they may walk. Blows at players are asked by `Fights` (Т5,
  below); doors and tame beasts — the code that will introduce them.
- The request `land_rights` [the team's mask, the others' mask]. The caption on entering another's land lists
  what may be done there (`Land.may_here`).

**How it is built (after Т3: the post, colour, the «Land» tab, the map)**
- There is no button with a flag any more: marking is turned on and off by a press on one's own boundary post
  (`Hud.open_prop` → `Hud.tap_post` → `Land.tap_post`) or on anything in the column of its first 2×2 square
  from the ground to the post's height, if the world does not block it (`Controls._on_post_square`:
  `Land.is_post_square` by the cell and `Land.hits_post_square` by a ray; in `Controls.tap` and
  `_start_paint`). A post just placed turns it on at once, but only if the player has just asked to place it
  themselves (`Land.expect_post` from `Props.put_from_bag` and build mode, 10 s; `Land.take_claims`: a new own
  claim at this time): a post that the server tells about at login or reconnection does not turn marking on.
  The caption — `Hud._on_painting_toggled`. On another's post — a caption with the name. While marking goes
  on, above the minimap «taken/can» is written in the land's colour (`Minimap.set_note`).
- The borders of one's own land in the world are seen only in marking, of another's — only while one stands on
  it (`land_view.gd`, `Land.here`). On the map and the minimap (`Minimap.draw_land`, also called by
  `map_view.gd`) the land is painted in the owner's colour: one's own always, another's — where the map is
  explored (`has_chunk`).
- The land's colour: the owner chooses one of `Territory.COLORS` (8) — `colors` {player: number}, `color_of`,
  `set_color`, the request `land_color` [number]; stored with the land, comes to the client as the sixth field
  of `claims`. The colours themselves are `UiStyle.LAND_COLORS`; the «can» buttons are painted by them too
  (`UiStyle.tint`).
- The rights are the third tab «Land» of the inventory window (`src/client/ui/land_page.gd`,
  `InventoryWindow`), seen only while the player stands on marked land (`Land.changed`). On one's own (no
  title): a row per action with «can» / «cannot» for the team and the others, at the bottom a row of colours;
  «Take the post» — a button in the window's head by the cross (`head_buttons`, as at a chest; `prop_take` of
  the centre, one must stand near). For a member of the owner's team — the same rows with no pressing; on
  another's — the land's name and what may be done there. The rows of the tabs «Land» and «Team» keep off the
  edges, as in the settings (`UiStyle.inset`, `BAR_GAP`).

**How it is built (Т4: respawn at the team's campfires, leaving the game)**
- A campfire placed from the bag remembers who placed it: `by` of the `Placed` record (the player's number, 0
  in single player; the start camp's campfire has none), stored in the save and goes to the client in
  `record`.
- `Character.find_respawns(placed, teams)` collects `respawns`: the last own campfire first («At your
  campfire»), then the last campfire of each team member («At «Anya»'s campfire»»), no more than
  `RESPAWNS_MAX` (4); an extinguished one counts too. `respawn_points()` is these and at the end the start's
  campfire (`home`). A respawned one stands beside the campfire: `Placed.stand_by` — the first cell around
  2×2 (`BESIDE`, east first) with air for two levels above solid ground.
- The server looks for them only for a dead player: `PlayerLink.flush` before the event `you` (the field
  `respawns`), and to a dead one it sends it again when a campfire with `by` appeared or vanished and when the
  team changed. The client (`src/client/game/character.gd` `take`) takes the list, the death screen gives a
  button per point.
- The request `revive` no longer puts anywhere: `Requests._revive_at` returns to the respawn point nearest to
  the named one, found anew, or to the place of death, if it was asked for (the switch of the check page «and
  where they fell»).
- Leaving the game (`Server.linger_of`): on one's own land or the land of one's team (`Territory.at_home`) the
  character leaves the world at once, outside it stands `LINGER` 30 s — both on a cut link and after `bye`. The
  button «Disconnect» in the multiplayer menu is captioned «leaves at once» or «will stand 30 s».

**How it is built (Т5: PvP)**
- `src/shared/game/fights.gd` (`Session.fights`): a player hits a player. A blow — by the action button
  (`WorldActions.strike`): with a sword and a knife at `STRIKE_REACH` 1.4 units, with a fist — only one standing
  point-blank; a working tool (an axe, a pickaxe, a shovel, a scythe) does not hit players, so that work next
  to them does not wound. A shot (`WorldActions.shoot`: a spear, a sling, a bow) hits the nearest on the line
  — a player or a beast. The damage is `Rules.pvp_damage` (4; skills do not strengthen a blow at a player,
  `docs/balance/GAME_BALANCE_DESIGN.md`) per each unit of the weapon's strength (`Vitals.wound`, the cause
  `player:<name>` — on the death screen «You were killed · player «…»»), a blow knocks back (`Body.knock`), to
  the one hit — the line «… hit you».
- Whether one may hit (`why_not`): the server's mode `Rules.pvp` — `off` (nowhere), `land` (by default:
  outside claims everywhere, in a claim — if the owner gave the right «Hit players», `Territory.allowed`),
  `all` (everywhere); one's own by team — never (the blow just goes past, to a beast or work); a newcomer —
  no, while they have protection (`protection_left`: the first `Rules.newcomer_minutes` 120 minutes of play in
  the world, until they themselves hit, placed a boundary post or took it off themselves — the request
  `fight_brave`, the button «Take off protection» on the «Team» tab). One who hit loses their protection.
- The fight tag: both who fought are marked for `Rules.fight_tag` 45 s (`tags`); a marked one cannot enter
  land where the owner has not given the others the right to hit players (`closed`): `step` (from
  `Session.step_players`) returns them to where they stood outside such land.
- Saved in the server's `world.json` (`fights`: how much each played and who took off protection), the tags —
  not. The mode is `[rules] pvp` in `server.cfg` (`Config.rules`, `Config.pvp`), `--pvp off|land|all` from a
  terminal, the row «PvP» in the «Create a server» window. The event `fight` [mode, minutes of protection,
  seconds of the tag] → `game.team` (`take_fight`); the «Team» tab writes the server's mode and protection.

**How it is built (Т6: abandoned land)**
- `Territory.time` — the seconds the world has worked (the server's ticks: `Session.step_things` passes `step`
  and seconds), stored with the land. A claim has `seen` — when someone of the owner's team last stood on it
  (`step`: a live player, `with`), `stage` — the passed steps of decay, `weak` — how much the guard weakened.
  Nobody for `territory_abandon_hours` (72 h) — the first step, then one each `territory_decay_hours` (24 h)
  (`_decay`). How decay comes — `Rules.territory_decay`: `rights` (the others may do more: `DECAY_MASKS` by
  `weak` — step 1: walk, open doors and chests; step 2: also build and break, gather the harvest, touch and
  hit beasts; hitting players — still as the owner decided), `radius` (the claim lets go of far plots: those
  within 2/3, then 1/2 of its span stay, and the ones cut off from the centre), `both` (by default: both). At
  the step `DECAY_STAGES` (3) the claim goes with all its plots — no-man's land; the post stays, anyone can
  take it (a press on it: «A boundary post without land…»). If someone of the team stood on the claim — the
  guard returns at once (the caption «The territory is under guard again»), the lost plots are painted anew.
- The numbers are in `Rules`; on a server they are set by the section `[rules]` in `server.cfg`
  (`Config.rules`). To the client `weak` comes as the seventh field of `claims`; `allowed` on the copy takes it
  into account, so the caption at entering («Territory «…» is abandoned: one may …») and the «Land» tab («The
  land is abandoned…») show what has become allowed.

**Tests**: `tests/unit/territory_test.gd` (`_test_decay` — decay by steps, the client's copy, saving, the
team's return, the modes `rights` and `radius`; the teams' rules, saving through JSON, the requests of two
players on one server; plots, the budget, connectivity, the post through `put_from_bag` and `land_paint`; the
default and given rights, saving, the land's colour and the request `land_color`, digging, a chest, taking a
thing and walking on another's land; a campfire remembers who placed it, which respawn points whom, `revive`
only to them, `at_home`; `_test_pvp`: a blow, damage, one's own, a newcomer, modes, the right on land, the
tag, saving), `tests/server_test.gd` `_chat` (an invitation, consent and a team line through a socket).
Shots: `tools/shot.gd` `team-person`, `team-invite`, `team-panel`, `land`, `land-paint`, `land-rights`,
`land-colors`, `land-decay`, `ui-test-player-end`, `death-fires`.
