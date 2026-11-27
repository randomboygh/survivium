# Teams and land (Т1–Т2)

Part of [Teams and territory](../territory.md). Teams, the boundary post and plots.

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
