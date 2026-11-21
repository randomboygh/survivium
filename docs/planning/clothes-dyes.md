# Clothes, jewellery and dyes (character editor PR 5): handoff

The user's decisions are in the library `plan/mvp.md`, stage 3, «Решения по персонажу» (the dyes plan with the
user's picks 1А 2А 3А 4А 5А, 2026-11-21). Screenshots: library `survivium-builds/character/clothes/`.

## Done

- #821: hats (straw/brim, wreath, bandana, hood, leather dome hat) and body clothes (fiber tunic, linen shirt,
  leather vest, poncho, apron). Hats are drawn by way in `tools/art/player_wear_art.gd`; body shapes are cut out
  of the frame's shirt/trousers in `PlayerArt._garments`.
- #831: kilt, linen trousers, sandals, moccasins, high boots (`PlayerArt._legwear`).
- Jewellery commit (the PR after #831): `Inventory.WEAR_SLOTS` + neck, wrists, ornament (looks only, no warmth);
  `Figure.UNDER` neck, `OVER` ornament, `LAST` wrists drawn over the fists (`Figure.AFTER_FISTS` prefix in the
  look); `PlayerArt._neckwear` (beads, fangs, amulet), `_wristwear` (bracelet a pixel up the arm, ring on the
  hand); `tools/jewellery` bundle; seashell (sand find), tooth (big carcass), feather (a find in grass cells, `materials/finds`).

Every shape has tones 1-3 (the cloth: what a dye will recolour) and 4-5 (the trim: keeps the material's colour);
`PlayerArt.painted` maps them; `make_sprites.gd` `WORN` gives five colours per look.

## Dyes core (PR 3, this commit)

Done as in docs/systems/character.md (Dyes): `cloth`/`dye` item fields, the dye id in the bag cell's 6th field
(shared with a sign's words), `Inventory.gear_dye`, the «Краситель» craft row, `CRAFT` with a dye, `PEOPLE`
field 19, key colours in `shaders/looks.gdshaderinc` (`Figure.dye_key`, `dye_to[21]`), `ItemIcons.dyed`, and
`content/plants/dyes` (black, yellow, pink, violet, brown). Shades the user approved (2026-11-21, preview
`survivium-builds/character/dyes/dyes-preview-1.png`), light/middle/dark, for the seven still to add in PR 4:
white `f0ece4 d0c8bc a09888`, grey `a8a8a4 84847f 5c5c58`, green `7aa050 587a38 3c5426`, ochre
`d8a048 b07c30 7c5420`, red `c84838 a03028 702020`, blue `5878b8 405c98 2c406c`, purple `a04888 7c3068 54204a`.
Green needs a nettle source (nettle gives fiber only). Re-dyeing a worn thing in the vat must update
`gear_dye` (worn_slot matches by item and dye).

## Dye sources (PR 4a, this commit)

The seven other dyes in `content/plants/dyes` (white chalk, grey ash, green nettle leaves, ochre, red madder root,
blue woad leaves, purple murex), boiled like the first five. Chalk, ochre, murex: `materials/finds` items with
`found_in` (biomes; `ActionsDig.found_here`). Ash: a fire's `ashes` (patched on the campfire and the fireplace),
dropped by `WorldActions.leave_ashes` on `Placed.burnt_down`. Nettle gives `nettle_leaves`; new bundles
`plants/madder` (a plant's `root`, given when the cell under it is dug) and `plants/woad`. Pictures:
`tools/make_dye_art.py`. Left: the dye vat (PR 4b).

## Left: dyes (PR 3 core, PR 4 sources and vat)

- **Data**: a content kind of dyes (id, title, three shades) or items with `dye: <colour>`; `dyeable: true` on
  clothes/jewellery of cloth, linen, wool, fiber, straw, leather, beads, bracelets (not fur, bone, metal).
  12 colours, no mixing: white chalk, grey ash, black charcoal, yellow evening primrose, green nettle, pink
  cranberry/raspberry, violet blueberry, brown acorns, ochre, red madder, blue woad, purple murex snail.
- **Making a dye**: 3 raw + water in a clay pot on the campfire → 2 portions (like `boiled_water`, `keeps: pot`).
- **Storage**: the 6th field of a bag cell `[id, n, wear, things, quality, dye]`, only when dyed; stacks of other
  dyes do not merge; chests, drops (`drop_data`), death heaps keep it.
- **Network**: own bag goes as is; others get a new `PEOPLE` field slot → dye. Server checks dye in bag, item
  dyeable, colour known; a test in `security_test.gd`.
- **Sprite**: the looks shader already uses 11 of 12 swaps (`shaders/looks.gdshaderinc`). Plan: `make_sprites`
  draws a dyeable look's tones 1-3 in key colours encoding slot + shade; the shader maps a key in O(1) to
  `dye_to[slot*3+shade]` (7 slots × 3), filled by `Figure.paint` with the item's own colours when undyed. No new
  textures (web limit 13). `view_test` checks the key colours appear nowhere else. A mod's hand-drawn worn
  picture needs the keys too (document in docs/systems/character.md).
- **Icons**: recolour 12×12 on the CPU (exact match of the item's three colours), cached per (icon, dye).
- **UX**: in the craft window a recipe of a dyeable thing gets a «Краситель» row (none or a dye in the bag), the
  request carries it. A dye vat (new station: planks + cord, filled with water) has «Перекрасить» (a thing from the
  bag + a dye) and «Отмыть» with ash (back to the material's colour).
- **New things for PR 4**: madder (meadow/forest steppe, root dug with a shovel), woad (floodplain/meadow, leaves),
  chalk (find in stone on plateau/cliffs/coast), ochre (find in clay, red rocks, savanna, desert), ash (from a
  burnt-out campfire/fireplace), murex snail (rare on tropical beach/shallows, 1 portion each).

## How to check

`tools/make_sprites.gd -- --all` (~1.5 min), `--import`, `tools/make_icons.gd -- <names>`; a figure sheet dump
like `Figure.new(Figure.dressed(gear, {}), {})` with `keep_image` and `step()` until done; shot `bag-person` with
`--phone` for the inventory tab. Content changes: content_report, balance_report, `content_test` counts the tools
bundles and lists the later additive ones.
