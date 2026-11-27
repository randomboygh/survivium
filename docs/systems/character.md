# The character: bag, strengths, skills, body, death, sprite

Status: ACTIVE. A Russian copy: [character_RU.md](character_RU.md).

**Purpose.** The one who plays: the bag and weight, what is worn, health, satiety, water, vigour and sleep,
warmth, stamina, skills, the price of actions, food, life statistics, death with a sack and respawn; the body
on cells (walking on slopes, jumps, water, ice, snow, wind); the player's sprite from PNG layers.

**Where to look.** This page is the overview; the files and the detail are split by topic into `character/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| The character's rules, the death screen's look, going far. | [character/rules.md](character/rules.md) |
| The bag, health and the other vitals, warmth. | [character/bag-vitals.md](character/bag-vitals.md) |
| The body on the grid, the server's and the client's character, the player and other players on screen. | [character/body.md](character/body.md) |
| The sheet of the player's frames from PNG layers. | [character/figure.md](character/figure.md) |
| The «Character» tab, skills, light in the hand. | [character/skills.md](character/skills.md) |

**Data.** Items (`food`, `spoils`, `rots_to`, `drink`, `empties_to`, `fills_to`, `fills_salty_to`, `holds`, `bedding`, `warmth`, `heal`,
`heal_time`, `weight`, `stack`, `light`, `burns`, `sprite`, `anim`, `hands`, `trail`; for food `heal` and `drink` are on
top of satiety: roast heals and quenches a little, `Character.eat`); the creature `core:human`; clothes on the
figure — `Figure.dressed(gear)`: the bare layers of `player.yaml` `naked` (body, loincloth, hair), between
them the pictures of what is worn `sprites/worn/<look>.png` of the thing's bundle (the field `look`): legs,
feet, the body and the neck under the hair, the head and its ornament on top, the wrists over the fists
(`Figure.LAST`, marked `Figure.AFTER_FISTS` in the look: a bracelet on a hand in front of the body); they are drawn by `tools/make_sprites.gd` (`WORN`: the shape
`PlayerArt.SHAPES` and three colours, then two of a trim: a band, a hem, laces, which a dye will leave as
they are). Dyes (character editor PR 5, the user's plan 1А–5А of 2026-11-21): a thing with `cloth` (its three
colours, light, middle, dark: clothes and jewellery of cloth, linen, wool, fiber, straw, leather, beads; not fur,
bone, metal) can be dyed with an item with `dye` (its three shades; `content/plants/dyes`, boiled in a pot on the
campfire). The dye's id is the 6th field of the bag cell (`Inventory.dye_of`; the field a sign keeps its words
in, so a dyed thing stacks only with its own dye and keeps it in chests, on the ground, in a death sack and in
the save); what is worn keeps the dye of the one worn (`Inventory.gear_dye`, saved as `gear_dyes`; of two
things of one item `worn_slot` finds the one of that dye). A thing is made dyed in the craft window («Краситель»
row: a square of each dye of the bag in its colour, wrapping onto more lines, the one picked ticked, the recipe's
picture in its colours and the dye a chip of «Материалы»; `CRAFT` with a third argument; `Workshop.start` checks the dye is in the bag, is a dye and the thing can be
dyed, and one portion of it goes with the job's materials, a cancel gives it back), or dyed anew at a dye vat
(an item with `washes`, `plants:dye_vat`; the craft tab opened at it lists the bag's things that can be dyed,
`CraftPanel._show_vat`): `REDYE [slot, dye]` → `Workshop.redye` (a vat near, a dye of the bag other than the
thing's, a portion a thing; dye "" washes it back to its own colours with the vat's `washes`, ash) →
`Inventory.set_dye`, which keeps a worn thing worn in its new colour (`gear_dye`). On the figure
`make_sprites.gd` draws the cloth of a dyeable look (its `WORN` colours must be its `cloth`) in key colours
(`Figure.dye_key`: red 254, blue 1, green the slot's number in `Figure.DYE_SLOTS` × 3 + the shade; a look of
three colours has no trim, so all of it takes the dye), and the shader shows `dye_to` at that number
(`Figure.dye_colours`: the dye's shades, else the cloth's own; one array of 21, no texture). A mod's hand-drawn
worn picture of a thing with `cloth` must use those key colours for its cloth (`view_test` checks each such
picture uses only its slot's keys and no other picture uses any). Icons are recoloured on the CPU
(`ItemIcons.dyed`: the icon's pixels of the cloth's three colours to the dye's, made once per thing and dye),
so an icon of a dyeable thing is drawn in its `cloth` colours. The dyes of what others wear come as the 20th
field of `PEOPLE` (index 19). The shapes of the body's clothes are cut out of the frame's shirt and trousers (`PlayerArt._garments`:
shirt, coat, tunic, vest, poncho, apron); the hats that are more than the top of the hair (a brim, a dome, a
wreath, a bandana, a hood) are drawn by way in `tools/art/player_wear_art.gd` and laid over the head as it bobs. What other players wear comes as the 14th field of `PEOPLE`, their
looks as the 19th (index 18). The
figure's layers and works — `content/core/sprites/player.yaml`, the tools' sheets in the hand —
`sprites/held/` of the tool's bundle. The parts `inventory`, `vitals`, `character` (from the server's
character, `game.host.player`), `hands` (from the client) are saved.

**Pitfalls.** Connect the bag's and queue's signals by a method, not by a lambda with `self` (a cycle of
references, the RefCounted is not freed — see the comment in `src/shared/game/character.gd`). `var i := expr`
where `expr` is a Variant (a field of an untyped object) is a parse error: type it explicitly; `typed_array =
expr if c else []` is a runtime error that silently cuts off the function.

**Tests.** `tests/unit/skills_test.gd` (levels, experience for work, crafting, land),
`tests/unit/character_test.gd` (`inventory`, `wear`, `gear` (bags on the back), `torch`, `spoil`, `vitals`,
`warmth`, `thirst`, `sleep`, `changes`, `death`, `fall`, `sack_ends`, `graves`, `bed_respawn`, `poultice`),
`actions_test.gd` (`drinking`), `tests/unit/body_test.gd` (`walking_rules`, `water`, `bog`, `slopes`, `steps`,
`ground`), `tests/save_test.gd`, `tools/sheet.gd` (the sheet of frames to PNG).

**In more detail.** `plan/design/character.md`, `plan/design/ui.md` (the bag, death).
