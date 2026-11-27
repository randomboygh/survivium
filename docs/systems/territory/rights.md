# Rights and protection (Т3 and after)

Part of [Teams and territory](../territory.md). Rights, protection, the post, colour, the tab, the map.

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
  opening a chest (`_bag`) — «chests»; a door opened by a tap (`Placed.swing`) or by walking into it
  (`Placed.walk_open`) — «doors». Walking: `Territory.step_walk` from `Session.step_players` returns the
  player to where they last stood on land where they may walk. Blows at players are asked by `Fights` (Т5,
  below); tame beasts — the code that will introduce them.
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
- The rights are the tab «Land» of the inventory window (`src/client/ui/land_page.gd`,
  `InventoryWindow`), seen only while the player stands on marked land (`Land.changed`). On one's own (no
  title): a row per action with «can» / «cannot» for the team and the others, at the bottom a row of colours;
  «Take the post» — a button in the window's head by the cross (`head_buttons`, as at a chest; `prop_take` of
  the centre, one must stand near). For a member of the owner's team — the same rows with no pressing; on
  another's — the land's name and what may be done there. The rows of the tabs «Land» and «Team» keep off the
  edges, as in the settings (`UiStyle.inset`, `BAR_GAP`).
