# Hands and the world: digging, building, chopping, mowing, gathering

Status: ACTIVE. A Russian copy: [interaction_RU.md](interaction_RU.md).

**Purpose.** What the character's hands do to the world: dig cells, place blocks, chop and fell trees, mow
grass, break twigs, gather berries, plant, work with the action button on what is in front, pick up what
lies around. The rules are shared (the server checks them), input and hints are the client's.

**Where to look.** This page is the overview; the files and the detail are split by topic into `interaction/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| Felling, the rules of the hands, rafts and boats. | [interaction/hands.md](interaction/hands.md) |
| The blueprint (plans) and what a tool can do. | [interaction/plans.md](interaction/plans.md) |
| Controls, build mode, farm mode and their panels. | [interaction/build-mode.md](interaction/build-mode.md) |
| The cursor frame, the blueprint's ghost, gathering and props. | [interaction/cursor-gathering.md](interaction/cursor-gathering.md) |

**The `who` contract** (the shared `src/shared/game/character.gd` and its heirs). `inventory`, `position`,
`held_back`, `feet()`, `facing_step()`, `moving()`, `overlaps_cell(cell)`, `held()`, `tool()`, `brush()`,
`act(action)` (pays with stamina, false — no strength), `give(id, n, worn)`, `use_tool()` (wear),
`nag(reason, text)`, `say(text)`, `note(stat, n)` (life statistics), `is_dead()`, `sacks` (where the sacks lie
after death). A swing that did something returns `{"swing", "work", "time", "at"}`, an empty one — `{}` or only
`{"swing"}`.

**Data.** Farming: materials of the roles `bed` / `bed_wet` (the bundle `resources/soil`), items with `crop`
(grain), plants of the kind `crop` (`grows: field`, `grow_days`, `mown`, the frames of the stages; wheat — the
bundle `plants/ears`, turnip, carrot, peas — `plants/turnip`, `plants/carrot`, `plants/peas`, sowing flax —
`plants/flax`; their seeds are found by cutting wild plants: the field `finds`, `Plants.harvest`), saplings of
the kind `sapling` (`tree` — the species it grows into; an acorn and a cone — their `crop`): planted on open
ground on the lattice of trees (odd x, z, `sapling_spot`, `can_root`: not closer than `SAPLING_GAP` to a tree
or sapling), they grow in the warm seasons without watering (a can does not water a bed with a sapling: the
third field of its record is the mark of a little tree, not wetness; `can_water`, `wet`): a sprout and a shoot
(frames `across` cards wide, `foliage._crop` puts them on one root with a shift in the 4th field:
`grass.gdshader`), from the share `young` of the term — a small tree (`grow_young`, `Growth.place_young`; the
trunk is thin, `Growth.YOUNG_GIRTH`, by the sapling's record under it: `Growth.young_at`; a felled one gives
only twigs: `young_tree`, `Felling.fell(…, young)`), a grown one becomes a tree (`grow_tree`: the little tree
is removed by `Felling.clear`, then `Growth.place`) if there is room above it; a hoe (`tools/hoe`, class
`hoe`), a sickle (`tools/sickle`, class `sickle`), a watering can (`tools/watering_can`, class `can`); beds —
`WorldData.fields`. Items with `tool`, `power`, `area`, `reach`, `swing`, `mows`, `durability`, `repair`,
`anim`, `hands`, `trail` (kind `items`); materials with `dig`, `hardness`, `item`, `bonus`, `mow`, `mow_gives` (kind
`materials`); trees and bushes — what they give (`log`, `twig`, `seed`, `fruit`). Building takes blocks from the
bag (free — a switch of «Testing»; digging, mowing and reaping give their own even then).

**Pitfalls.** A network game's client takes a cell from the server (`Protocol.CELLS`) through
`Mirror.take_cell`: a watered or dried bed keeps its crop (`set_cell` erases the `fields` record). A finger
touch in the browser also arrives as `InputEventMouseMotion`: `controls.input` treats mouse movement as a mouse
only when there is no finger and more than 1 s has passed since the touch. The joystick and `TouchButton`
follow their own touch index so that two fingers work.

**Tests.** `tests/unit/boat_test.gd` (launching, also on the sea's flush water, moving on water, two in a boat, the shore, a vessel at the
shore and into the bag, oars, saving, ice, death),
`tests/unit/farming_test.gd` (a bed, sowing, watering, rain, growth, winter, harvest, saving),
`tests/unit/actions_test.gd` (`felling`, `front_choice`, `snow_gathered`, `world_actions`, `stairs_placed`, `placed`,
`start_camp`, `lights`, `drinking`, `furniture`, `openings`),
`tests/unit/plans_test.gd` (the blueprint's shapes, building by cells from the bag, erasing, saving, ghost
things: set, moved, turned, taken off, saved, built after the blocks, `_test_ghost_things`),
`tests/unit/content_test.gd` (`tools`), `tests/progress_test.gd` (the whole way of the game from bare hands to
all recipes through the same calls). After an edit of tools, materials, stations, recipes or hands —
`progress_test` is a must.

**More.** `plan/design/character.md` («Interaction with the world»), `plan/design/ui.md` (controls).
