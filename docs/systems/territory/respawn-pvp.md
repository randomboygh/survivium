# Respawn, PvP, abandoned land (Т4–Т6)

Part of [Teams and territory](../territory.md). Respawn at the team's campfires, PvP, the decay of abandoned land.

**How it is built (Т4: respawn at the team's campfires, leaving the game)**
- A campfire placed from the bag remembers who placed it: `by` of the `Placed` record (the player's number, 0
  in single player; the start camp's campfire has none), stored in the save and goes to the client in
  `record`.
- `Character.find_respawns(placed, teams)` collects `respawns`: the last own campfire first («At your
  campfire»), then the last campfire of each team member («At «Anya»'s campfire»»), no more than
  `RESPAWNS_MAX` (4); an extinguished one counts too. `respawn_points()` is these and at the end the start's
  campfire (`home`). A respawned one stands beside the campfire: `Placed.stand_by` — the first cell around
  the thing (`Placed.beside(size)`, east first) with air for two levels above solid ground.
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

**How it is built (buildings outside the land decay, stage 2 item 5, decision 186; the user's picks of
2026-11-19: 1А 2Б 3В 4Б 5А 6А 7Б 8А 9А)**
- `src/shared/game/decay.gd` — `Session.decay`, a step of `Session.step_things` (game days and seconds). The
  world is tended by chunks: an edited chunk within `TEND_REACH` (16) cells of a live player, or holding a
  square of any claim (weakened too), is tended now (`tended`, the day of `Decay.time`, the game days the world
  ran with decay on); a claim gone to no-man's land leaves its chunks to decay from then. In a chunk left
  alone a built cell (not WILD: placed by a player) of a material with `decay` (its YAML field: wattle 2, planks
  and log wall 1, cut stone and brick 0.5; 0 — the ground, trees, ores — never) goes a stage further each
  `Rules.building_decay_days` (10) / `decay` game days: first it cracks (`WorldData.cracks`: chunk → {cell →
  material}; the signal `cracks_changed`), then it falls to a ruin (a later step). A player coming back stops the
  clock (`passed` = 0), the cracks stay. A cell set anew (`WorldData.set_cell`) loses its crack. Every
  `LOOK_EVERY` (2 s) it looks at `CHUNKS_PER_LOOK` (32) edited chunks for one due, and works it through
  `SCAN_COLUMNS` (32) columns a step (the built cells of a column by the masks `air`, `water`, `wild`); a chunk
  with nothing that decays is `bare` until a player is near again. Edited chunks stay in memory however far,
  so far buildings decay too; a stopped server decays nothing.
- The cracks shown (PR 2): `PlayerLink` sends `Protocol.CRACKS` — over a socket [chunk, flat x, y, z…]
  (`WorldData.cracks_of`, `take_cracks`) after the chunk itself and when they change, over the loop only [chunk];
  `Mirror` takes them and draws the chunk again (a chunk sent anew starts whole). `ChunkMesher` gives a cracked
  cell's faces the vertex colour `CRACKED` (green at half) and never merges them into plain rows or rounded edges;
  `world.gdshader` (`crack_mark`) keeps the tile's colours and draws on each face a crack down from its top edge,
  4–8 texels, and a shorter one from its left, by a hash of the cell and face. A cracked cell breaks in
  `CRACKED_SWING` (half) the time (`WorldActions.cell_swing`: digging, the blueprint's removal). Shot `decay-cracks`
  (`places.crack_near`: every other built cell near the walls of every material).
- Ruins (PR 3, decision 5А): a cracked cell owed a stage more falls (to air, its material lost; `actions.cell_changed`
  tells the clients) when nothing built that decays stands on it and it does not stand on solid ground that does
  not decay; a column is worked from the top down and a cell under one falling now falls too with a stage more
  for each (`run`), so a long neglect takes the rows it owes at once. A wall loses a row a stage from the top, a
  roof over air falls, the lowest row stays cracked: the ruin. A cracked cell dug gives its item only
  `CRACKED_YIELD` (half) of the time (`ActionsDig.dig`). The simple things (`Decay.decays_thing`: fences, doors,
  ladders, hatches, furniture; not chests, stations, fires, signs, crosses) of a chunk go `THING_PACE` (as wood)
  and fall apart at `THING_STAGES` (2; `Placed.fall_apart`, `Decay.worn` saved). What fell goes out as
  `Decay.crumbled` → `Protocol.CRUMBLED` [cells, materials (-1 a thing)] to the players whose screen reaches it;
  `Props.crumbled` raises dust and bits of the material, a knock of its `hit` sound and a thud, felt near.
  Shot `decay-ruins` (`places.age_near`: the walls left 2.5 game days a stage).
- Repair (decision 6A): a cracked block tapped in build mode (`BuildMode.start_stroke`, not erasing) is mended
  free with a swing of the tool in the hand: `Controls.mend` → `Protocol.MEND` [cell] (paced, `Requests.PACED`)
  → `Decay.mend` (cracked, within `Tools.PLACE_REACH`, the right «build»; `WorldData.mend`, `cracks_changed`
  false → `Protocol.CRACKS`). A fallen block is built again by the blueprint at its full price.
- Switches: `Rules.building_decay` (the server: `[rules]` of `server.cfg`) and the world's own `Decay.on`,
  set by the row «Building decay» of «New world» (`Settings` `world_decay`, `WorldSetup`), kept in
  `world.json` as `decay` (`to_dict` / `from_dict`: `on`, `time`, `tended`, `cracked`); a world saved before it
  decays, its clock starting at the first load.
- Settings: the server window's tab «Settings» (`HostScreen`, section «Land») has the switch «Building decay»
  and «Building decay step» (`building_decay_days`: 3, 5, 10, 20, 40 game days). The playtest page («Testing», next to
  «Flow of time») sets «Building decay step» to the world's own, 1 or 0.1 game days (`Settings.DECAY_DAYS`, saved with
  the test switches; on a server the cheat `decay_days`, clamped to `Cheats.LEAST_DECAY_DAYS`, 0 gives the
  server's own back).
