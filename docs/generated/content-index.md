# Реестр сущностей

Создаёт `tools/content_report.gd` из данных всех модов, как их грузит игра; руками не править. После
правки данных: `godot --headless --path . --script res://tools/content_report.gd`; CI проверяет, что
реестр свежий. Правила системы — [BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md).

Категория — у предметов та, что выводит игра (у рецепта — его предмета), у остальных их роль или вид.
Бандл — где запись определена; «→» — кто её заменил (`replaces`), «патчи» — кто поправил.
Эпоха — у предметов и рецептов та, что выводит граф (карта эпох — в [content-graph.md](content-graph.md)).
Связи — сколько записей называет эта и сколько называют её (поля-ссылки с типом связи `rel`).
Проверка — что говорят о записи проверки загрузки и графа: «ок», ошибки или предупреждения. Граф —
[content-graph.md](content-graph.md), что нашли проверки — [content-checks.md](content-checks.md).

## Моды и бандлы

- `core` [core.mod]
- `animals` [animals.mod]: `animals/bear` [animals.bear.bundle], `animals/boar` [animals.boar.bundle], `animals/butterfly` [animals.butterfly.bundle], `animals/cat` [animals.cat.bundle], `animals/crow` [animals.crow.bundle], `animals/deer` [animals.deer.bundle], `animals/duck` [animals.duck.bundle], `animals/fish` [animals.fish.bundle], `animals/fox` [animals.fox.bundle], `animals/frog` [animals.frog.bundle], `animals/game` [animals.game.bundle], `animals/hedgehog` [animals.hedgehog.bundle], `animals/owl` [animals.owl.bundle], `animals/perch` [animals.perch.bundle], `animals/rabbit` [animals.rabbit.bundle], `animals/sparrow` [animals.sparrow.bundle], `animals/squirrel` [animals.squirrel.bundle], `animals/wolf` [animals.wolf.bundle], `animals/wool` [animals.wool.bundle]
- `biomes` [biomes.mod]: `biomes/alpine_meadow` [biomes.alpine_meadow.bundle], `biomes/beach` [biomes.beach.bundle], `biomes/birch_grove` [biomes.birch_grove.bundle], `biomes/desert` [biomes.desert.bundle], `biomes/floodplain` [biomes.floodplain.bundle], `biomes/forest` [biomes.forest.bundle], `biomes/forest_steppe` [biomes.forest_steppe.bundle], `biomes/glacier` [biomes.glacier.bundle], `biomes/ice_waste` [biomes.ice_waste.bundle], `biomes/jungle` [biomes.jungle.bundle], `biomes/mangrove` [biomes.mangrove.bundle], `biomes/maple_wood` [biomes.maple_wood.bundle], `biomes/meadow` [biomes.meadow.bundle], `biomes/peat_bog` [biomes.peat_bog.bundle], `biomes/pine_wood` [biomes.pine_wood.bundle], `biomes/plateau` [biomes.plateau.bundle], `biomes/red_rocks` [biomes.red_rocks.bundle], `biomes/rock` [biomes.rock.bundle], `biomes/salt_flat` [biomes.salt_flat.bundle], `biomes/savanna` [biomes.savanna.bundle], `biomes/sea` [biomes.sea.bundle], `biomes/steppe` [biomes.steppe.bundle], `biomes/stony_tundra` [biomes.stony_tundra.bundle], `biomes/swamp` [biomes.swamp.bundle], `biomes/taiga` [biomes.taiga.bundle], `biomes/tropical_beach` [biomes.tropical_beach.bundle], `biomes/tropical_sea` [biomes.tropical_sea.bundle], `biomes/tundra` [biomes.tundra.bundle]
- `materials` [materials.mod]: `materials/bone_glue` [materials.bone_glue.bundle], `materials/brick` [materials.brick.bundle], `materials/bronze` [materials.bronze.bundle], `materials/charcoal` [materials.charcoal.bundle], `materials/cloth` [materials.cloth.bundle], `materials/copper` [materials.copper.bundle], `materials/cord` [materials.cord.bundle], `materials/cut_stone` [materials.cut_stone.bundle], `materials/glass` [materials.glass.bundle], `materials/gold` [materials.gold.bundle], `materials/iron` [materials.iron.bundle], `materials/leather` [materials.leather.bundle], `materials/log_wall` [materials.log_wall.bundle], `materials/planks` [materials.planks.bundle], `materials/platinum` [materials.platinum.bundle], `materials/silver` [materials.silver.bundle], `materials/steel` [materials.steel.bundle], `materials/tar` [materials.tar.bundle], `materials/tin` [materials.tin.bundle], `materials/wattle` [materials.wattle.bundle]
- `music` [music.mod]
- `plants` [plants.mod]: `plants/acacia` [plants.acacia.bundle], `plants/apple` [plants.apple.bundle], `plants/banana` [plants.banana.bundle], `plants/birch` [plants.birch.bundle], `plants/bird_cherry` [plants.bird_cherry.bundle], `plants/blueberry` [plants.blueberry.bundle], `plants/carrot` [plants.carrot.bundle], `plants/ceiba` [plants.ceiba.bundle], `plants/cherry` [plants.cherry.bundle], `plants/cranberry` [plants.cranberry.bundle], `plants/currant` [plants.currant.bundle], `plants/deadwood` [plants.deadwood.bundle], `plants/ears` [plants.ears.bundle], `plants/fern` [plants.fern.bundle], `plants/fir` [plants.fir.bundle], `plants/flax` [plants.flax.bundle], `plants/grass` [plants.grass.bundle], `plants/larch` [plants.larch.bundle], `plants/linden` [plants.linden.bundle], `plants/mangrove` [plants.mangrove.bundle], `plants/maple` [plants.maple.bundle], `plants/monstera` [plants.monstera.bundle], `plants/moss` [plants.moss.bundle], `plants/mushrooms` [plants.mushrooms.bundle], `plants/nettle` [plants.nettle.bundle], `plants/oak` [plants.oak.bundle], `plants/palm` [plants.palm.bundle], `plants/peas` [plants.peas.bundle], `plants/pine` [plants.pine.bundle], `plants/poplar` [plants.poplar.bundle], `plants/raspberry` [plants.raspberry.bundle], `plants/red_maple` [plants.red_maple.bundle], `plants/reeds` [plants.reeds.bundle], `plants/roasted_acorns` [plants.roasted_acorns.bundle], `plants/rosehip` [plants.rosehip.bundle], `plants/rowan` [plants.rowan.bundle], `plants/shrub` [plants.shrub.bundle], `plants/spruce` [plants.spruce.bundle], `plants/turnip` [plants.turnip.bundle], `plants/willow` [plants.willow.bundle], `plants/wood` [plants.wood.bundle]
- `resources` [resources.mod]: `resources/fiber` [resources.fiber.bundle], `resources/peat` [resources.peat.bundle], `resources/salt` [resources.salt.bundle], `resources/snow` [resources.snow.bundle], `resources/soil` [resources.soil.bundle], `resources/stone` [resources.stone.bundle], `resources/wood` [resources.wood.bundle]
- `sounds` [sounds.mod]: `sounds/nature` [sounds.nature.bundle], `sounds/player` [sounds.player.bundle], `sounds/ui` [sounds.ui.bundle]
- `tools` [tools.mod]: `tools/anvil` [tools.anvil.bundle], `tools/axe` [tools.axe.bundle], `tools/bedding` [tools.bedding.bundle], `tools/big_chest` [tools.big_chest.bundle], `tools/bloomery` [tools.bloomery.bundle], `tools/boats` [tools.boats.bundle], `tools/boundary_post` [tools.boundary_post.bundle], `tools/bow` [tools.bow.bundle], `tools/candle` [tools.candle.bundle], `tools/canvas_backpack` [tools.canvas_backpack.bundle], `tools/chest` [tools.chest.bundle], `tools/composite_bow` [tools.composite_bow.bundle], `tools/door` [tools.door.bundle], `tools/drying_rack` [tools.drying_rack.bundle], `tools/fence` [tools.fence.bundle], `tools/fiber_clothes` [tools.fiber_clothes.bundle], `tools/fireplace` [tools.fireplace.bundle], `tools/fishing_rod` [tools.fishing_rod.bundle], `tools/forge` [tools.forge.bundle], `tools/furniture` [tools.furniture.bundle], `tools/hatch` [tools.hatch.bundle], `tools/hide_clothes` [tools.hide_clothes.bundle], `tools/hoe` [tools.hoe.bundle], `tools/kiln` [tools.kiln.bundle], `tools/knife` [tools.knife.bundle], `tools/ladder` [tools.ladder.bundle], `tools/lantern` [tools.lantern.bundle], `tools/leather_bag` [tools.leather_bag.bundle], `tools/leather_sling` [tools.leather_sling.bundle], `tools/loom` [tools.loom.bundle], `tools/needle` [tools.needle.bundle], `tools/pickaxe` [tools.pickaxe.bundle], `tools/potters_wheel` [tools.potters_wheel.bundle], `tools/scythe` [tools.scythe.bundle], `tools/shovel` [tools.shovel.bundle], `tools/sickle` [tools.sickle.bundle], `tools/signs` [tools.signs.bundle], `tools/sling` [tools.sling.bundle], `tools/spear` [tools.spear.bundle], `tools/stairs` [tools.stairs.bundle], `tools/sword` [tools.sword.bundle], `tools/tar_torch` [tools.tar_torch.bundle], `tools/torch` [tools.torch.bundle], `tools/trap` [tools.trap.bundle], `tools/watering_can` [tools.watering_can.bundle], `tools/waterskin` [tools.waterskin.bundle], `tools/wicker_bag` [tools.wicker_bag.bundle], `tools/window` [tools.window.bundle], `tools/workbench` [tools.workbench.bundle]

## Предметы (`items`, 217)

| Id | Название | Категория | Описание | Бандл | Эпоха | Связи из / в | Проверка |
|---|---|---|---|---|---|---|---|
| `core:campfire` | [core.items.campfire] | [stations] |  | `core` | 1. [core.eras.primitive] | 1 / 15 | ок |
| `core:rot` | [core.items.rot] | [materials] |  | `core` | 0. [core.eras.foraging] | 0 / 23 | предупреждения: 1 |
| `materials:brick` | [materials.items.brick] | [blocks] |  | `materials/brick` | 3. [core.eras.bronze] | 1 / 5 | ок |
| `materials:charcoal` | [materials.items.charcoal] | [materials] |  | `materials/charcoal` | 3. [core.eras.bronze] | 0 / 12 | ок |
| `materials:cloth` | [materials.items.cloth] | [materials] | [materials.items.cloth.about] | `materials/cloth` | 2. [core.eras.bone_leather] | 1 / 7 | ок |
| `materials:copper_ore` | [materials.items.copper_ore] | [materials] |  | `materials/copper` | 3. [core.eras.bronze] | 1 / 2 | ок |
| `materials:copper_bar` | [materials.items.copper_bar] | [materials] |  | `materials/copper` | 3. [core.eras.bronze] | 0 / 19 | ок |
| `materials:planks` | [materials.items.planks] | [blocks] |  | `materials/planks` | 1. [core.eras.primitive] | 1 / 66 | ок |
| `plants:blueberry` | [plants.items.blueberry] | [food] |  | `plants/blueberry` | 0. [core.eras.foraging] | 1 / 1 | предупреждения: 1 |
| `plants:blueberry_bush` | [plants.items.blueberry_bush] | [planting] |  | `plants/blueberry` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:cranberry` | [plants.items.cranberry] | [food] |  | `plants/cranberry` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:currant` | [plants.items.currant] | [food] |  | `plants/currant` | 0. [core.eras.foraging] | 1 / 1 | предупреждения: 1 |
| `plants:currant_bush` | [plants.items.currant_bush] | [planting] |  | `plants/currant` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:grass_seeds` | [plants.items.grass_seeds] | [planting] |  | `plants/grass` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:carrot_seeds` | [plants.items.carrot_seeds] | [planting] | [plants.items.carrot_seeds.about] | `plants/carrot` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:carrot` | [plants.items.carrot] | [food] | [plants.items.carrot.about] | `plants/carrot` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:mushroom` | [plants.items.mushroom] | [food] |  | `plants/mushrooms` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:glow_mushroom` | [plants.items.glow_mushroom] | [food] |  | `plants/mushrooms` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:fried_mushrooms` | [plants.items.fried_mushrooms] | [food] |  | `plants/mushrooms` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:peas` | [plants.items.peas] | [food] | [plants.items.peas.about] | `plants/peas` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:raspberry` | [plants.items.raspberry] | [food] |  | `plants/raspberry` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:raspberry_bush` | [plants.items.raspberry_bush] | [planting] |  | `plants/raspberry` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:rosehip` | [plants.items.rosehip] | [food] |  | `plants/rosehip` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:rosehip_bush` | [plants.items.rosehip_bush] | [planting] |  | `plants/rosehip` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:shrub_bush` | [plants.items.shrub_bush] | [planting] |  | `plants/shrub` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:turnip_seeds` | [plants.items.turnip_seeds] | [planting] | [plants.items.turnip_seeds.about] | `plants/turnip` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:turnip` | [plants.items.turnip] | [food] | [plants.items.turnip.about] | `plants/turnip` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `resources:fiber` | [resources.items.fiber] | [materials] |  | `resources/fiber` | 0. [core.eras.foraging] | 0 / 22 | ок |
| `materials:cord` | [materials.items.cord] | [materials] |  | `materials/cord` | 1. [core.eras.primitive] | 1 / 51 | ок |
| `plants:moss` | [plants.items.moss] | [materials] |  | `plants/moss` | 0. [core.eras.foraging] | 0 / 3 | ок |
| `plants:bandage` | [plants.items.bandage] | [healing] |  | `plants/moss` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `plants:poultice` | [plants.items.poultice] | [healing] | [plants.items.poultice.about] | `plants/moss` | 0. [core.eras.foraging] | 0 / 1 | ок |
| `resources:peat` | [resources.items.peat] | [blocks] |  | `resources/peat` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `resources:salt` | [resources.items.salt] | [blocks] |  | `resources/salt` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `resources:snow` | [resources.items.snow] | [blocks] |  | `resources/snow` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `resources:ice` | [resources.items.ice] | [blocks] |  | `resources/snow` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `resources:dirt` | [resources.items.dirt] | [blocks] |  | `resources/soil` | 0. [core.eras.foraging] | 1 / 5 | ок |
| `resources:sand` | [resources.items.sand] | [blocks] |  | `resources/soil` | 0. [core.eras.foraging] | 1 / 3 | ок |
| `resources:clay` | [resources.items.clay] | [blocks] |  | `resources/soil` | 0. [core.eras.foraging] | 1 / 8 | ок |
| `resources:stone` | [resources.items.stone] | [blocks] |  | `resources/stone` | 0. [core.eras.foraging] | 1 / 9 | ок |
| `resources:flint` | [resources.items.flint] | [materials] |  | `resources/stone` | 0. [core.eras.foraging] | 0 / 21 | ок |
| `resources:branch` | [resources.items.branch] | [materials] |  | `resources/wood` | 0. [core.eras.foraging] | 0 / 67 | ок |
| `resources:log` | [resources.items.log] | [blocks] |  | `resources/wood`; патчи: `plants/wood` | 1. [core.eras.primitive] | 1 / 28 | ок |
| `animals:roach` | [animals.items.roach] | [food] | [animals.items.roach.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:pike` | [animals.items.pike] | [food] | [animals.items.pike.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:salmon` | [animals.items.salmon] | [food] | [animals.items.salmon.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:cod` | [animals.items.cod] | [food] | [animals.items.cod.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:parrotfish` | [animals.items.parrotfish] | [food] | [animals.items.parrotfish.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:catfish` | [animals.items.catfish] | [food] | [animals.items.catfish.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:perch` | [animals.items.perch] | [food] | [animals.items.perch.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `animals:roasted_fish` | [animals.items.roasted_fish] | [food] | [animals.items.roasted_fish.about] | `animals/fish` | 1. [core.eras.primitive] | 1 / 7 | ок |
| `materials:log_wall` | [materials.items.log_wall] | [blocks] | [materials.items.log_wall.about] | `materials/log_wall` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `materials:wattle` | [materials.items.wattle] | [blocks] | [materials.items.wattle.about] | `materials/wattle` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:apple` | [plants.items.apple] | [food] |  | `plants/apple` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:banana` | [plants.items.banana] | [food] |  | `plants/banana` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:banana_bush` | [plants.items.banana_bush] | [planting] |  | `plants/banana` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `plants:acorn` | [plants.items.acorn] | [planting] |  | `plants/oak` | 0. [core.eras.foraging] | 1 / 3 | ок |
| `plants:coconut` | [plants.items.coconut] | [food] |  | `plants/palm` | 0. [core.eras.foraging] | 0 / 1 | ок |
| `plants:rowan` | [plants.items.rowan] | [food] |  | `plants/rowan` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `plants:cone` | [plants.items.cone] | [planting] |  | `plants/spruce` | 0. [core.eras.foraging] | 1 / 3 | ок |
| `tools:boundary_post` | [tools.items.boundary_post] | [stations] |  | `tools/boundary_post` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:fence` | [tools.items.fence] | [stations] | [tools.items.fence.about] | `tools/fence` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:wicket` | [tools.items.wicket] | [stations] | [tools.items.wicket.about] | `tools/fence` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:gate` | [tools.items.gate] | [stations] | [tools.items.gate.about] | `tools/fence` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:fiber_hat` | [tools.items.fiber_hat] | [clothes_and_bags] | [tools.items.fiber_hat.about] | `tools/fiber_clothes` | 0. [core.eras.foraging] | 0 / 1 | ок |
| `tools:grass_cape` | [tools.items.grass_cape] | [clothes_and_bags] | [tools.items.grass_cape.about] | `tools/fiber_clothes` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:leg_wraps` | [tools.items.leg_wraps] | [clothes_and_bags] | [tools.items.leg_wraps.about] | `tools/fiber_clothes` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:bast_shoes` | [tools.items.bast_shoes] | [clothes_and_bags] | [tools.items.bast_shoes.about] | `tools/fiber_clothes` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:fishing_rod` | [tools.items.fishing_rod] | [tools] | [tools.items.fishing_rod.about] | `tools/fishing_rod` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:bait` | [tools.items.bait] | [materials] | [tools.items.bait.about] | `tools/fishing_rod` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `tools:ladder` | [tools.items.ladder] | [stations] | [tools.items.ladder.about] | `tools/ladder` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:cord_sling` | [tools.items.cord_sling] | [tools] | [tools.items.cord_sling.about] | `tools/sling` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:sling_stone` | [tools.items.sling_stone] | [materials] | [tools.items.sling_stone.about] | `tools/sling` | 0. [core.eras.foraging] | 0 / 3 | ок |
| `tools:stairs` | [tools.items.stairs] | [stations] | [tools.items.stairs.about] | `tools/stairs` | 0. [core.eras.foraging] | 0 / 0 | ок |
| `tools:torch` | [tools.items.torch] | [light] |  | `tools/torch` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:trap` | [tools.items.trap] | [stations] | [tools.items.trap.about] | `tools/trap` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:live_rabbit` | [tools.items.live_rabbit] | [materials] | [tools.items.live_rabbit.about] | `tools/trap` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:wicker_bag` | [tools.items.wicker_bag] | [clothes_and_bags] | [tools.items.wicker_bag.about] | `tools/wicker_bag` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:workbench` | [tools.items.workbench] | [stations] |  | `tools/workbench` | 1. [core.eras.primitive] | 1 / 66 | ок |
| `materials:cut_stone` | [materials.items.cut_stone] | [blocks] | [materials.items.cut_stone.about] | `materials/cut_stone` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `tools:big_chest` | [tools.items.big_chest] | [stations] |  | `tools/big_chest` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:bloomery` | [tools.items.bloomery] | [stations] |  | `tools/bloomery` | 5. [core.eras.iron] | 1 / 3 | ок |
| `tools:wooden_bow` | [tools.items.wooden_bow] | [tools] | [tools.items.wooden_bow.about] | `tools/bow` | 1. [core.eras.primitive] | 2 / 2 | ок |
| `tools:arrow` | [tools.items.arrow] | [materials] | [tools.items.arrow.about] | `tools/bow` | 1. [core.eras.primitive] | 0 / 4 | ок |
| `tools:chest` | [tools.items.chest] | [stations] |  | `tools/chest` | 1. [core.eras.primitive] | 0 / 2 | ок |
| `tools:door` | [tools.items.door] | [stations] | [tools.items.door.about] | `tools/door` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:door_2x2` | [tools.items.door_2x2] | [stations] | [tools.items.door_2x2.about] | `tools/door` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:door_2x3` | [tools.items.door_2x3] | [stations] | [tools.items.door_2x3.about] | `tools/door` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:door_3x3` | [tools.items.door_3x3] | [stations] | [tools.items.door_3x3.about] | `tools/door` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:drying_rack` | [tools.items.drying_rack] | [stations] | [tools.items.drying_rack.about] | `tools/drying_rack` | 2. [core.eras.bone_leather] | 1 / 3 | ок |
| `animals:small_carcass` | [animals.items.small_carcass] | [materials] | [animals.items.small_carcass.about] | `animals/game` | 0. [core.eras.foraging] | 0 / 9 | ок |
| `animals:carcass` | [animals.items.carcass] | [materials] | [animals.items.carcass.about] | `animals/game` | 0. [core.eras.foraging] | 0 / 5 | ок |
| `animals:raw_meat` | [animals.items.raw_meat] | [food] | [animals.items.raw_meat.about] | `animals/game` | 0. [core.eras.foraging] | 1 / 4 | ок |
| `animals:roasted_meat` | [animals.items.roasted_meat] | [food] | [animals.items.roasted_meat.about] | `animals/game` | 0. [core.eras.foraging] | 1 / 1 | ок |
| `animals:hide` | [animals.items.hide] | [materials] | [animals.items.hide.about] | `animals/game` | 0. [core.eras.foraging] | 0 / 7 | ок |
| `animals:bone` | [animals.items.bone] | [materials] |  | `animals/game` | 0. [core.eras.foraging] | 0 / 6 | ок |
| `animals:fat` | [animals.items.fat] | [materials] |  | `animals/game` | 1. [core.eras.primitive] | 0 / 3 | ок |
| `animals:jerky` | [animals.items.jerky] | [food] | [animals.items.jerky.about] | `animals/game` | 2. [core.eras.bone_leather] | 0 / 1 | ок |
| `materials:leather` | [materials.items.leather] | [materials] | [materials.items.leather.about] | `materials/leather` | 2. [core.eras.bone_leather] | 1 / 10 | ок |
| `tools:grass_mat` | [tools.items.grass_mat] | [stations] | [tools.items.grass_mat.about] | `tools/bedding` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:fur_bedroll` | [tools.items.fur_bedroll] | [stations] | [tools.items.fur_bedroll.about] | `tools/bedding` | 2. [core.eras.bone_leather] | 1 / 1 | ок |
| `tools:tallow_candle` | [tools.items.tallow_candle] | [light] | [tools.items.tallow_candle.about] | `tools/candle` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:canvas_backpack` | [tools.items.canvas_backpack] | [clothes_and_bags] | [tools.items.canvas_backpack.about] | `tools/canvas_backpack` | 2. [core.eras.bone_leather] | 0 / 1 | ок |
| `tools:fireplace` | [tools.items.fireplace] | [stations] | [tools.items.fireplace.about] | `tools/fireplace` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:forge` | [tools.items.forge] | [stations] |  | `tools/forge` | 3. [core.eras.bronze] | 1 / 9 | ок |
| `materials:glass` | [materials.items.glass] | [materials] | [materials.items.glass.about] | `materials/glass` | 3. [core.eras.bronze] | 0 / 7 | ок |
| `materials:iron_ore` | [materials.items.iron_ore] | [materials] | [materials.items.iron_ore.about] | `materials/iron` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:iron_bloom` | [materials.items.iron_bloom] | [materials] | [materials.items.iron_bloom.about] | `materials/iron` | 5. [core.eras.iron] | 1 / 2 | ок |
| `materials:iron_bar` | [materials.items.iron_bar] | [materials] | [materials.items.iron_bar.about] | `materials/iron` | 5. [core.eras.iron] | 1 / 21 | ок |
| `materials:tin_ore` | [materials.items.tin_ore] | [materials] | [materials.items.tin_ore.about] | `materials/tin` | 3. [core.eras.bronze] | 0 / 2 | ок |
| `materials:tin_bar` | [materials.items.tin_bar] | [materials] | [materials.items.tin_bar.about] | `materials/tin` | 3. [core.eras.bronze] | 0 / 2 | ок |
| `tools:anvil` | [tools.items.anvil] | [stations] |  | `tools/anvil` | 5. [core.eras.iron] | 1 / 19 | ок |
| `materials:gold_ore` | [materials.items.gold_ore] | [materials] | [materials.items.gold_ore.about] | `materials/gold` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:gold_bar` | [materials.items.gold_bar] | [materials] | [materials.items.gold_bar.about] | `materials/gold` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:gold_block` | [materials.items.gold_block] | [blocks] | [materials.items.gold_block.about] | `materials/gold` | 5. [core.eras.iron] | 1 / 2 | ок |
| `materials:platinum_ore` | [materials.items.platinum_ore] | [materials] | [materials.items.platinum_ore.about] | `materials/platinum` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:platinum_bar` | [materials.items.platinum_bar] | [materials] | [materials.items.platinum_bar.about] | `materials/platinum` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:platinum_block` | [materials.items.platinum_block] | [blocks] | [materials.items.platinum_block.about] | `materials/platinum` | 5. [core.eras.iron] | 1 / 2 | ок |
| `materials:silver_ore` | [materials.items.silver_ore] | [materials] | [materials.items.silver_ore.about] | `materials/silver` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:silver_bar` | [materials.items.silver_bar] | [materials] | [materials.items.silver_bar.about] | `materials/silver` | 4. [core.eras.alloy] | 0 / 2 | ок |
| `materials:silver_block` | [materials.items.silver_block] | [blocks] | [materials.items.silver_block.about] | `materials/silver` | 5. [core.eras.iron] | 1 / 2 | ок |
| `tools:hatch` | [tools.items.hatch] | [stations] | [tools.items.hatch.about] | `tools/hatch` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:hatch_2x2` | [tools.items.hatch_2x2] | [stations] | [tools.items.hatch_2x2.about] | `tools/hatch` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:fur_hat` | [tools.items.fur_hat] | [clothes_and_bags] | [tools.items.fur_hat.about] | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 1 / 1 | ок |
| `tools:fur_coat` | [tools.items.fur_coat] | [clothes_and_bags] | [tools.items.fur_coat.about] | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 1 / 1 | ок |
| `tools:leather_trousers` | [tools.items.leather_trousers] | [clothes_and_bags] | [tools.items.leather_trousers.about] | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 1 / 1 | ок |
| `tools:fur_boots` | [tools.items.fur_boots] | [clothes_and_bags] | [tools.items.fur_boots.about] | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 1 / 1 | ок |
| `tools:stone_hoe` | [tools.items.stone_hoe] | [tools] | [tools.items.stone_hoe.about] | `tools/hoe` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:copper_hoe` | [tools.items.copper_hoe] | [tools] | [tools.items.copper_hoe.about] | `tools/hoe` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:iron_hoe` | [tools.items.iron_hoe] | [tools] | [tools.items.iron_hoe.about] | `tools/hoe` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:kiln` | [tools.items.kiln] | [stations] |  | `tools/kiln` | 3. [core.eras.bronze] | 1 / 7 | ок |
| `plants:grain` | [plants.items.grain] | [planting] |  | `plants/ears` | 0. [core.eras.foraging] | 1 / 3 | ок |
| `plants:flour` | [plants.items.flour] | [materials] |  | `plants/ears` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `plants:flatbread` | [plants.items.flatbread] | [food] |  | `plants/ears` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:leather_bag` | [tools.items.leather_bag] | [clothes_and_bags] | [tools.items.leather_bag.about] | `tools/leather_bag` | 2. [core.eras.bone_leather] | 0 / 1 | ок |
| `tools:leather_sling` | [tools.items.leather_sling] | [tools] | [tools.items.leather_sling.about] | `tools/leather_sling` | 2. [core.eras.bone_leather] | 2 / 1 | ок |
| `tools:loom` | [tools.items.loom] | [stations] |  | `tools/loom` | 2. [core.eras.bone_leather] | 1 / 5 | ок |
| `animals:rabbit_fluff` | [animals.items.rabbit_fluff] | [materials] | [animals.items.rabbit_fluff.about] | `animals/wool` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `animals:wool_yarn` | [animals.items.wool_yarn] | [materials] | [animals.items.wool_yarn.about] | `animals/wool` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `plants:flax_seeds` | [plants.items.flax_seeds] | [planting] | [plants.items.flax_seeds.about] | `plants/flax` | 0. [core.eras.foraging] | 1 / 2 | ок |
| `plants:flax_stalks` | [plants.items.flax_stalks] | [materials] | [plants.items.flax_stalks.about] | `plants/flax` | 0. [core.eras.foraging] | 0 / 3 | ок |
| `plants:linen_thread` | [plants.items.linen_thread] | [materials] | [plants.items.linen_thread.about] | `plants/flax` | 0. [core.eras.foraging] | 0 / 2 | ок |
| `tools:table` | [tools.items.table] | [stations] | [tools.items.table.about] | `tools/furniture` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:stool` | [tools.items.stool] | [stations] | [tools.items.stool.about] | `tools/furniture` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:wooden_bed` | [tools.items.wooden_bed] | [stations] | [tools.items.wooden_bed.about] | `tools/furniture` | 2. [core.eras.bone_leather] | 0 / 1 | ок |
| `tools:cupboard` | [tools.items.cupboard] | [stations] | [tools.items.cupboard.about] | `tools/furniture` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:wide_cupboard` | [tools.items.wide_cupboard] | [stations] | [tools.items.wide_cupboard.about] | `tools/furniture` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:barrel` | [tools.items.barrel] | [stations] | [tools.items.barrel.about] | `tools/furniture` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:rug` | [tools.items.rug] | [stations] | [tools.items.rug.about] | `tools/furniture` | 2. [core.eras.bone_leather] | 0 / 1 | ок |
| `tools:bone_needle` | [tools.items.bone_needle] | [tools] | [tools.items.bone_needle.about] | `tools/needle` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:potters_wheel` | [tools.items.potters_wheel] | [stations] |  | `tools/potters_wheel` | 1. [core.eras.primitive] | 0 / 3 | ок |
| `tools:raw_pot` | [tools.items.raw_pot] | [materials] | [tools.items.raw_pot.about] | `tools/potters_wheel` | 1. [core.eras.primitive] | 0 / 2 | ок |
| `tools:pot` | [tools.items.pot] | [materials] | [tools.items.pot.about] | `tools/potters_wheel` | 3. [core.eras.bronze] | 0 / 4 | ок |
| `materials:bone_glue` | [materials.items.bone_glue] | [materials] | [materials.items.bone_glue.about] | `materials/bone_glue` | 3. [core.eras.bronze] | 0 / 3 | ок |
| `materials:raw_crucible` | [materials.items.raw_crucible] | [materials] | [materials.items.raw_crucible.about] | `materials/bronze` | 1. [core.eras.primitive] | 0 / 2 | ок |
| `materials:crucible` | [materials.items.crucible] | [materials] | [materials.items.crucible.about] | `materials/bronze` | 3. [core.eras.bronze] | 0 / 3 | ок |
| `materials:bronze_bar` | [materials.items.bronze_bar] | [materials] | [materials.items.bronze_bar.about] | `materials/bronze` | 4. [core.eras.alloy] | 1 / 15 | ок |
| `materials:steel_bar` | [materials.items.steel_bar] | [materials] | [materials.items.steel_bar.about] | `materials/steel` | 6. [core.eras.steel] | 1 / 13 | ок |
| `materials:tar` | [materials.items.tar] | [materials] | [materials.items.tar.about] | `materials/tar` | 3. [core.eras.bronze] | 0 / 4 | ок |
| `plants:roasted_acorns` | [plants.items.roasted_acorns] | [food] | [plants.items.roasted_acorns.about] | `plants/roasted_acorns` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:stone_axe` | [tools.items.stone_axe] | [tools] |  | `tools/axe` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:copper_axe` | [tools.items.copper_axe] | [tools] |  | `tools/axe` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_axe` | [tools.items.bronze_axe] | [tools] |  | `tools/axe` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_axe` | [tools.items.iron_axe] | [tools] |  | `tools/axe` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_axe` | [tools.items.steel_axe] | [tools] |  | `tools/axe` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:raft` | [tools.items.raft] | [materials] | [tools.items.raft.about] | `tools/boats` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:boat` | [tools.items.boat] | [materials] | [tools.items.boat.about] | `tools/boats` | 3. [core.eras.bronze] | 2 / 1 | ок |
| `tools:oars` | [tools.items.oars] | [materials] | [tools.items.oars.about] | `tools/boats` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `tools:composite_bow` | [tools.items.composite_bow] | [tools] | [tools.items.composite_bow.about] | `tools/composite_bow` | 3. [core.eras.bronze] | 2 / 1 | ок |
| `tools:flint_knife` | [tools.items.flint_knife] | [tools] | [tools.items.flint_knife.about] | `tools/knife` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:copper_knife` | [tools.items.copper_knife] | [tools] |  | `tools/knife` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_knife` | [tools.items.bronze_knife] | [tools] |  | `tools/knife` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_knife` | [tools.items.iron_knife] | [tools] |  | `tools/knife` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_knife` | [tools.items.steel_knife] | [tools] |  | `tools/knife` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:lantern` | [tools.items.lantern] | [light] | [tools.items.lantern.about] | `tools/lantern` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:stone_pickaxe` | [tools.items.stone_pickaxe] | [tools] |  | `tools/pickaxe` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:wooden_pickaxe` | [tools.items.wooden_pickaxe] | [tools] |  | `tools/pickaxe` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:copper_pickaxe` | [tools.items.copper_pickaxe] | [tools] |  | `tools/pickaxe` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_pickaxe` | [tools.items.bronze_pickaxe] | [tools] |  | `tools/pickaxe` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_pickaxe` | [tools.items.iron_pickaxe] | [tools] |  | `tools/pickaxe` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_pickaxe` | [tools.items.steel_pickaxe] | [tools] |  | `tools/pickaxe` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:stone_scythe` | [tools.items.stone_scythe] | [tools] |  | `tools/scythe` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:wooden_scythe` | [tools.items.wooden_scythe] | [tools] |  | `tools/scythe` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:copper_scythe` | [tools.items.copper_scythe] | [tools] |  | `tools/scythe` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_scythe` | [tools.items.bronze_scythe] | [tools] |  | `tools/scythe` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_scythe` | [tools.items.iron_scythe] | [tools] |  | `tools/scythe` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_scythe` | [tools.items.steel_scythe] | [tools] |  | `tools/scythe` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:wooden_shovel` | [tools.items.wooden_shovel] | [tools] |  | `tools/shovel` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:copper_shovel` | [tools.items.copper_shovel] | [tools] |  | `tools/shovel` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_shovel` | [tools.items.bronze_shovel] | [tools] |  | `tools/shovel` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_shovel` | [tools.items.iron_shovel] | [tools] |  | `tools/shovel` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_shovel` | [tools.items.steel_shovel] | [tools] |  | `tools/shovel` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:stone_sickle` | [tools.items.stone_sickle] | [tools] | [tools.items.stone_sickle.about] | `tools/sickle` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:copper_sickle` | [tools.items.copper_sickle] | [tools] | [tools.items.copper_sickle.about] | `tools/sickle` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:iron_sickle` | [tools.items.iron_sickle] | [tools] | [tools.items.iron_sickle.about] | `tools/sickle` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:sign` | [tools.items.sign] | [stations] | [tools.items.sign.about] | `tools/signs` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:signpost` | [tools.items.signpost] | [stations] | [tools.items.signpost.about] | `tools/signs` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:notice_board` | [tools.items.notice_board] | [stations] | [tools.items.notice_board.about] | `tools/signs` | 1. [core.eras.primitive] | 0 / 1 | ок |
| `tools:flint_spear` | [tools.items.flint_spear] | [tools] | [tools.items.flint_spear.about] | `tools/spear` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:bronze_spear` | [tools.items.bronze_spear] | [tools] |  | `tools/spear` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_spear` | [tools.items.iron_spear] | [tools] |  | `tools/spear` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:wooden_sword` | [tools.items.wooden_sword] | [tools] |  | `tools/sword` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:stone_sword` | [tools.items.stone_sword] | [tools] |  | `tools/sword` | 1. [core.eras.primitive] | 2 / 1 | ок |
| `tools:copper_sword` | [tools.items.copper_sword] | [tools] |  | `tools/sword` | 3. [core.eras.bronze] | 1 / 1 | ок |
| `tools:bronze_sword` | [tools.items.bronze_sword] | [tools] |  | `tools/sword` | 4. [core.eras.alloy] | 1 / 1 | ок |
| `tools:iron_sword` | [tools.items.iron_sword] | [tools] |  | `tools/sword` | 5. [core.eras.iron] | 1 / 1 | ок |
| `tools:steel_sword` | [tools.items.steel_sword] | [tools] |  | `tools/sword` | 6. [core.eras.steel] | 1 / 1 | ок |
| `tools:tar_torch` | [tools.items.tar_torch] | [light] | [tools.items.tar_torch.about] | `tools/tar_torch` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:watering_can` | [tools.items.watering_can] | [materials] | [tools.items.watering_can.about] | `tools/watering_can` | 1. [core.eras.primitive] | 1 / 2 | ок |
| `tools:watering_can_full` | [tools.items.watering_can_full] | [tools] | [tools.items.watering_can_full.about] | `tools/watering_can` | 1. [core.eras.primitive] | 1 / 1 | ок |
| `tools:waterskin` | [tools.items.waterskin] | [materials] | [tools.items.waterskin.about] | `tools/waterskin` | 2. [core.eras.bone_leather] | 2 / 2 | ок |
| `tools:waterskin_full` | [tools.items.waterskin_full] | [materials] | [tools.items.waterskin_full.about] | `tools/waterskin` | 2. [core.eras.bone_leather] | 2 / 1 | ок |
| `tools:window` | [tools.items.window] | [stations] | [tools.items.window.about] | `tools/window` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:window_1x2` | [tools.items.window_1x2] | [stations] | [tools.items.window_1x2.about] | `tools/window` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:window_2x1` | [tools.items.window_2x1] | [stations] | [tools.items.window_2x1.about] | `tools/window` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:window_2x2` | [tools.items.window_2x2] | [stations] | [tools.items.window_2x2.about] | `tools/window` | 3. [core.eras.bronze] | 0 / 1 | ок |
| `tools:window_3x2` | [tools.items.window_3x2] | [stations] | [tools.items.window_3x2.about] | `tools/window` | 3. [core.eras.bronze] | 0 / 1 | ок |

## Рецепты (`recipes`, 162)

| Id | Название | Категория | Описание | Бандл | Эпоха | Связи из / в | Проверка |
|---|---|---|---|---|---|---|---|
| `plants:fried_mushrooms` | [plants.recipes.fried_mushrooms] | [food] |  | `plants/mushrooms` | 0. [core.eras.foraging] | 3 / 0 | ок |
| `materials:cord` | [materials.recipes.cord] | [materials] |  | `materials/cord` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `plants:bandage` | [plants.recipes.bandage] | [healing] |  | `plants/moss` | 0. [core.eras.foraging] | 3 / 0 | ок |
| `plants:poultice` | [plants.recipes.poultice] | [healing] |  | `plants/moss` | 0. [core.eras.foraging] | 4 / 0 | ок |
| `resources:campfire` | [resources.recipes.campfire] | [stations] |  | `resources/wood` | 0. [core.eras.foraging] | 3 / 0 | ок |
| `animals:roasted_fish_from_roach` | [animals.recipes.roasted_fish_from_roach] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_pike` | [animals.recipes.roasted_fish_from_pike] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_salmon` | [animals.recipes.roasted_fish_from_salmon] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_cod` | [animals.recipes.roasted_fish_from_cod] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_parrotfish` | [animals.recipes.roasted_fish_from_parrotfish] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_catfish` | [animals.recipes.roasted_fish_from_catfish] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:roasted_fish_from_perch` | [animals.recipes.roasted_fish_from_perch] | [food] |  | `animals/fish` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `materials:log_wall` | [materials.recipes.log_wall] | [blocks] |  | `materials/log_wall` | 1. [core.eras.primitive] | 2 / 0 | ок |
| `materials:wattle` | [materials.recipes.wattle] | [blocks] |  | `materials/wattle` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `tools:boundary_post` | [tools.recipes.boundary_post] | [stations] |  | `tools/boundary_post` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:fence` | [tools.recipes.fence] | [stations] |  | `tools/fence` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:wicket` | [tools.recipes.wicket] | [stations] |  | `tools/fence` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:gate` | [tools.recipes.gate] | [stations] |  | `tools/fence` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:fiber_hat` | [tools.recipes.fiber_hat] | [clothes_and_bags] |  | `tools/fiber_clothes` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `tools:grass_cape` | [tools.recipes.grass_cape] | [clothes_and_bags] |  | `tools/fiber_clothes` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:leg_wraps` | [tools.recipes.leg_wraps] | [clothes_and_bags] |  | `tools/fiber_clothes` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:bast_shoes` | [tools.recipes.bast_shoes] | [clothes_and_bags] |  | `tools/fiber_clothes` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:fishing_rod` | [tools.recipes.fishing_rod] | [tools] |  | `tools/fishing_rod` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:bait` | [tools.recipes.bait] | [materials] |  | `tools/fishing_rod` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `tools:ladder` | [tools.recipes.ladder] | [stations] |  | `tools/ladder` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:cord_sling` | [tools.recipes.cord_sling] | [tools] |  | `tools/sling` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:sling_stone` | [tools.recipes.sling_stone] | [materials] |  | `tools/sling` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `tools:torch` | [tools.recipes.torch] | [light] |  | `tools/torch` | 0. [core.eras.foraging] | 3 / 0 | ок |
| `tools:trap` | [tools.recipes.trap] | [stations] |  | `tools/trap` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:wicker_bag` | [tools.recipes.wicker_bag] | [clothes_and_bags] |  | `tools/wicker_bag` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:workbench` | [tools.recipes.workbench] | [stations] |  | `tools/workbench` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `materials:cut_stone` | [materials.recipes.cut_stone] | [blocks] |  | `materials/cut_stone` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:big_chest` | [tools.recipes.big_chest] | [stations] |  | `tools/big_chest` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:bloomery` | [tools.recipes.bloomery] | [stations] |  | `tools/bloomery` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `tools:wooden_bow` | [tools.recipes.wooden_bow] | [tools] |  | `tools/bow` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:arrow` | [tools.recipes.arrow] | [materials] |  | `tools/bow` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:chest` | [tools.recipes.chest] | [stations] |  | `tools/chest` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:door` | [tools.recipes.door] | [stations] |  | `tools/door` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:door_2x2` | [tools.recipes.door_2x2] | [stations] |  | `tools/door` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:door_2x3` | [tools.recipes.door_2x3] | [stations] |  | `tools/door` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:door_3x3` | [tools.recipes.door_3x3] | [stations] |  | `tools/door` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:drying_rack` | [tools.recipes.drying_rack] | [stations] |  | `tools/drying_rack` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `animals:raw_meat_from_small_carcass` | [animals.recipes.raw_meat_from_small_carcass] | [food] |  | `animals/game` | 0. [core.eras.foraging] | 4 / 0 | ок |
| `animals:raw_meat_from_carcass` | [animals.recipes.raw_meat_from_carcass] | [food] |  | `animals/game` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `animals:roasted_meat` | [animals.recipes.roasted_meat] | [food] |  | `animals/game` | 0. [core.eras.foraging] | 4 / 0 | ок |
| `animals:jerky` | [animals.recipes.jerky] | [food] |  | `animals/game` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `materials:leather` | [materials.recipes.leather] | [materials] |  | `materials/leather` | 2. [core.eras.bone_leather] | 4 / 0 | ок |
| `tools:grass_mat` | [tools.recipes.grass_mat] | [stations] |  | `tools/bedding` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:fur_bedroll` | [tools.recipes.fur_bedroll] | [stations] |  | `tools/bedding` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:tallow_candle` | [tools.recipes.tallow_candle] | [light] |  | `tools/candle` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:canvas_backpack` | [tools.recipes.canvas_backpack] | [clothes_and_bags] |  | `tools/canvas_backpack` | 2. [core.eras.bone_leather] | 4 / 0 | ок |
| `tools:fireplace` | [tools.recipes.fireplace] | [stations] |  | `tools/fireplace` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `tools:forge` | [tools.recipes.forge] | [stations] |  | `tools/forge` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `tools:copper_bar` | [tools.recipes.copper_bar] | [materials] |  | `tools/forge` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `materials:glass` | [materials.recipes.glass] | [materials] |  | `materials/glass` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `materials:iron_bloom` | [materials.recipes.iron_bloom] | [materials] |  | `materials/iron` | 5. [core.eras.iron] | 4 / 0 | ок |
| `materials:iron_bar` | [materials.recipes.iron_bar] | [materials] |  | `materials/iron` | 5. [core.eras.iron] | 4 / 0 | ок |
| `materials:tin_bar` | [materials.recipes.tin_bar] | [materials] |  | `materials/tin` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:anvil` | [tools.recipes.anvil] | [stations] |  | `tools/anvil` | 5. [core.eras.iron] | 4 / 0 | ок |
| `materials:gold_bar` | [materials.recipes.gold_bar] | [materials] |  | `materials/gold` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `materials:gold_block` | [materials.recipes.gold_block] | [blocks] |  | `materials/gold` | 5. [core.eras.iron] | 3 / 0 | ок |
| `materials:platinum_bar` | [materials.recipes.platinum_bar] | [materials] |  | `materials/platinum` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `materials:platinum_block` | [materials.recipes.platinum_block] | [blocks] |  | `materials/platinum` | 5. [core.eras.iron] | 3 / 0 | ок |
| `materials:silver_bar` | [materials.recipes.silver_bar] | [materials] |  | `materials/silver` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `materials:silver_block` | [materials.recipes.silver_block] | [blocks] |  | `materials/silver` | 5. [core.eras.iron] | 3 / 0 | ок |
| `tools:hatch` | [tools.recipes.hatch] | [stations] |  | `tools/hatch` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:hatch_2x2` | [tools.recipes.hatch_2x2] | [stations] |  | `tools/hatch` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:fur_hat` | [tools.recipes.fur_hat] | [clothes_and_bags] |  | `tools/hide_clothes` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:fur_coat` | [tools.recipes.fur_coat] | [clothes_and_bags] |  | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 5 / 0 | ок |
| `tools:leather_trousers` | [tools.recipes.leather_trousers] | [clothes_and_bags] |  | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 4 / 0 | ок |
| `tools:fur_boots` | [tools.recipes.fur_boots] | [clothes_and_bags] |  | `tools/hide_clothes` | 2. [core.eras.bone_leather] | 5 / 0 | ок |
| `tools:stone_hoe` | [tools.recipes.stone_hoe] | [tools] |  | `tools/hoe` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:copper_hoe` | [tools.recipes.copper_hoe] | [tools] |  | `tools/hoe` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:iron_hoe` | [tools.recipes.iron_hoe] | [tools] |  | `tools/hoe` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:kiln` | [tools.recipes.kiln] | [stations] |  | `tools/kiln` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:brick` | [tools.recipes.brick] | [blocks] |  | `tools/kiln` | 3. [core.eras.bronze] | 3 / 0 | ок |
| `tools:charcoal` | [tools.recipes.charcoal] | [materials] |  | `tools/kiln` | 3. [core.eras.bronze] | 3 / 0 | ок |
| `plants:flour` | [plants.recipes.flour] | [materials] |  | `plants/ears` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `plants:flatbread` | [plants.recipes.flatbread] | [food] |  | `plants/ears` | 3. [core.eras.bronze] | 3 / 0 | ок |
| `tools:leather_bag` | [tools.recipes.leather_bag] | [clothes_and_bags] |  | `tools/leather_bag` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `tools:leather_sling` | [tools.recipes.leather_sling] | [tools] |  | `tools/leather_sling` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `tools:loom` | [tools.recipes.loom] | [stations] |  | `tools/loom` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:cloth_from_cord` | [tools.recipes.cloth_from_cord] | [materials] |  | `tools/loom` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `animals:wool_yarn` | [animals.recipes.wool_yarn] | [materials] |  | `animals/wool` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `animals:cloth_from_wool_yarn` | [animals.recipes.cloth_from_wool_yarn] | [materials] |  | `animals/wool` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `plants:linen_thread` | [plants.recipes.linen_thread] | [materials] |  | `plants/flax` | 0. [core.eras.foraging] | 2 / 0 | ок |
| `plants:cloth` | [plants.recipes.cloth] | [materials] |  | `plants/flax` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `tools:table` | [tools.recipes.table] | [stations] |  | `tools/furniture` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:stool` | [tools.recipes.stool] | [stations] |  | `tools/furniture` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:wooden_bed` | [tools.recipes.wooden_bed] | [stations] |  | `tools/furniture` | 2. [core.eras.bone_leather] | 4 / 0 | ок |
| `tools:cupboard` | [tools.recipes.cupboard] | [stations] |  | `tools/furniture` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:wide_cupboard` | [tools.recipes.wide_cupboard] | [stations] |  | `tools/furniture` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:barrel` | [tools.recipes.barrel] | [stations] |  | `tools/furniture` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:rug` | [tools.recipes.rug] | [stations] |  | `tools/furniture` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `tools:bone_needle` | [tools.recipes.bone_needle] | [tools] |  | `tools/needle` | 1. [core.eras.primitive] | 2 / 0 | ок |
| `tools:potters_wheel` | [tools.recipes.potters_wheel] | [stations] |  | `tools/potters_wheel` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:raw_pot` | [tools.recipes.raw_pot] | [materials] |  | `tools/potters_wheel` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:pot` | [tools.recipes.pot] | [materials] |  | `tools/potters_wheel` | 3. [core.eras.bronze] | 3 / 0 | ок |
| `materials:bone_glue` | [materials.recipes.bone_glue] | [materials] |  | `materials/bone_glue` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `materials:raw_crucible` | [materials.recipes.raw_crucible] | [materials] |  | `materials/bronze` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `materials:crucible` | [materials.recipes.crucible] | [materials] |  | `materials/bronze` | 3. [core.eras.bronze] | 3 / 0 | ок |
| `materials:bronze_bar` | [materials.recipes.bronze_bar] | [materials] |  | `materials/bronze` | 3. [core.eras.bronze] | 6 / 0 | ок |
| `materials:steel_bar` | [materials.recipes.steel_bar] | [materials] |  | `materials/steel` | 5. [core.eras.iron] | 5 / 0 | ок |
| `materials:tar` | [materials.recipes.tar] | [materials] |  | `materials/tar` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `plants:roasted_acorns` | [plants.recipes.roasted_acorns] | [food] |  | `plants/roasted_acorns` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:stone_axe` | [tools.recipes.stone_axe] | [tools] |  | `tools/axe` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:planks` | [tools.recipes.planks] | [blocks] |  | `tools/axe` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:copper_axe` | [tools.recipes.copper_axe] | [tools] |  | `tools/axe` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_axe` | [tools.recipes.bronze_axe] | [tools] |  | `tools/axe` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_axe` | [tools.recipes.iron_axe] | [tools] |  | `tools/axe` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_axe` | [tools.recipes.steel_axe] | [tools] |  | `tools/axe` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:raft` | [tools.recipes.raft] | [materials] |  | `tools/boats` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:boat` | [tools.recipes.boat] | [materials] |  | `tools/boats` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:oars` | [tools.recipes.oars] | [materials] |  | `tools/boats` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:composite_bow` | [tools.recipes.composite_bow] | [tools] |  | `tools/composite_bow` | 3. [core.eras.bronze] | 6 / 0 | ок |
| `tools:arrow_from_bone` | [tools.recipes.arrow_from_bone] | [materials] |  | `tools/composite_bow` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:flint_knife` | [tools.recipes.flint_knife] | [tools] |  | `tools/knife` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:copper_knife` | [tools.recipes.copper_knife] | [tools] |  | `tools/knife` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_knife` | [tools.recipes.bronze_knife] | [tools] |  | `tools/knife` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_knife` | [tools.recipes.iron_knife] | [tools] |  | `tools/knife` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_knife` | [tools.recipes.steel_knife] | [tools] |  | `tools/knife` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:lantern` | [tools.recipes.lantern] | [light] |  | `tools/lantern` | 3. [core.eras.bronze] | 5 / 0 | ок |
| `tools:stone_pickaxe` | [tools.recipes.stone_pickaxe] | [tools] |  | `tools/pickaxe` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:wooden_pickaxe` | [tools.recipes.wooden_pickaxe] | [tools] |  | `tools/pickaxe` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:copper_pickaxe` | [tools.recipes.copper_pickaxe] | [tools] |  | `tools/pickaxe` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_pickaxe` | [tools.recipes.bronze_pickaxe] | [tools] |  | `tools/pickaxe` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_pickaxe` | [tools.recipes.iron_pickaxe] | [tools] |  | `tools/pickaxe` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_pickaxe` | [tools.recipes.steel_pickaxe] | [tools] |  | `tools/pickaxe` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:stone_scythe` | [tools.recipes.stone_scythe] | [tools] |  | `tools/scythe` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:wooden_scythe` | [tools.recipes.wooden_scythe] | [tools] |  | `tools/scythe` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:copper_scythe` | [tools.recipes.copper_scythe] | [tools] |  | `tools/scythe` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_scythe` | [tools.recipes.bronze_scythe] | [tools] |  | `tools/scythe` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_scythe` | [tools.recipes.iron_scythe] | [tools] |  | `tools/scythe` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_scythe` | [tools.recipes.steel_scythe] | [tools] |  | `tools/scythe` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:wooden_shovel` | [tools.recipes.wooden_shovel] | [tools] |  | `tools/shovel` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:copper_shovel` | [tools.recipes.copper_shovel] | [tools] |  | `tools/shovel` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_shovel` | [tools.recipes.bronze_shovel] | [tools] |  | `tools/shovel` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_shovel` | [tools.recipes.iron_shovel] | [tools] |  | `tools/shovel` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_shovel` | [tools.recipes.steel_shovel] | [tools] |  | `tools/shovel` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:stone_sickle` | [tools.recipes.stone_sickle] | [tools] |  | `tools/sickle` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:copper_sickle` | [tools.recipes.copper_sickle] | [tools] |  | `tools/sickle` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:iron_sickle` | [tools.recipes.iron_sickle] | [tools] |  | `tools/sickle` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:sign` | [tools.recipes.sign] | [stations] |  | `tools/signs` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:signpost` | [tools.recipes.signpost] | [stations] |  | `tools/signs` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:notice_board` | [tools.recipes.notice_board] | [stations] |  | `tools/signs` | 1. [core.eras.primitive] | 3 / 0 | ок |
| `tools:flint_spear` | [tools.recipes.flint_spear] | [tools] |  | `tools/spear` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:bronze_spear` | [tools.recipes.bronze_spear] | [tools] |  | `tools/spear` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_spear` | [tools.recipes.iron_spear] | [tools] |  | `tools/spear` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:wooden_sword` | [tools.recipes.wooden_sword] | [tools] |  | `tools/sword` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:stone_sword` | [tools.recipes.stone_sword] | [tools] |  | `tools/sword` | 1. [core.eras.primitive] | 5 / 0 | ок |
| `tools:copper_sword` | [tools.recipes.copper_sword] | [tools] |  | `tools/sword` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:bronze_sword` | [tools.recipes.bronze_sword] | [tools] |  | `tools/sword` | 4. [core.eras.alloy] | 4 / 0 | ок |
| `tools:iron_sword` | [tools.recipes.iron_sword] | [tools] |  | `tools/sword` | 5. [core.eras.iron] | 4 / 0 | ок |
| `tools:steel_sword` | [tools.recipes.steel_sword] | [tools] |  | `tools/sword` | 6. [core.eras.steel] | 4 / 0 | ок |
| `tools:tar_torch` | [tools.recipes.tar_torch] | [light] |  | `tools/tar_torch` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:watering_can` | [tools.recipes.watering_can] | [materials] |  | `tools/watering_can` | 1. [core.eras.primitive] | 4 / 0 | ок |
| `tools:waterskin` | [tools.recipes.waterskin] | [materials] |  | `tools/waterskin` | 2. [core.eras.bone_leather] | 3 / 0 | ок |
| `tools:window` | [tools.recipes.window] | [stations] |  | `tools/window` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:window_1x2` | [tools.recipes.window_1x2] | [stations] |  | `tools/window` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:window_2x1` | [tools.recipes.window_2x1] | [stations] |  | `tools/window` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:window_2x2` | [tools.recipes.window_2x2] | [stations] |  | `tools/window` | 3. [core.eras.bronze] | 4 / 0 | ок |
| `tools:window_3x2` | [tools.recipes.window_3x2] | [stations] |  | `tools/window` | 3. [core.eras.bronze] | 4 / 0 | ок |

## Материалы ячеек (`materials`, 30)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:air` | [core.materials.air] |  |  | `core` | 0 / 0 | ок |
| `core:grass` | [core.materials.grass] |  |  | `core` | 4 / 1 | ок |
| `core:dirt` | [core.materials.dirt] |  |  | `core` | 2 / 2 | ок |
| `core:stone` | [core.materials.stone] |  |  | `core` | 1 / 1 | ок |
| `core:water` | [core.materials.water] |  |  | `core` | 0 / 0 | ок |
| `materials:brick` | [materials.materials.brick] |  |  | `materials/brick` | 1 / 1 | ок |
| `materials:copper_ore` | [materials.materials.copper_ore] | ore |  | `materials/copper` | 1 / 0 | ок |
| `materials:planks` | [materials.materials.planks] |  |  | `materials/planks` | 1 / 1 | ок |
| `resources:peat` | [resources.materials.peat] | peat |  | `resources/peat` | 1 / 1 | ок |
| `resources:salt` | [resources.materials.salt] | salt |  | `resources/salt` | 1 / 1 | ок |
| `resources:snow` | [resources.materials.snow] | snow |  | `resources/snow` | 1 / 1 | ок |
| `resources:ice` | [resources.materials.ice] | ice |  | `resources/snow` | 1 / 1 | ок |
| `resources:sand` | [resources.materials.sand] | beach |  | `resources/soil` | 2 / 1 | ок |
| `resources:clay` | [resources.materials.clay] | bank |  | `resources/soil` | 1 / 1 | ок |
| `resources:bed` | [resources.materials.bed] | bed |  | `resources/soil` | 1 / 0 | ок |
| `resources:bed_wet` | [resources.materials.bed_wet] | bed_wet |  | `resources/soil` | 1 / 0 | ок |
| `resources:scree` | [resources.materials.scree] | scree |  | `resources/stone` | 2 / 0 | ок |
| `materials:log_wall` | [materials.materials.log_wall] |  |  | `materials/log_wall` | 1 / 1 | ок |
| `materials:wattle` | [materials.materials.wattle] |  |  | `materials/wattle` | 1 / 1 | ок |
| `plants:log` | [plants.materials.log] | trunk |  | `plants/wood` | 1 / 1 | ок |
| `plants:leaves` | [plants.materials.leaves] | crown |  | `plants/wood` | 0 / 0 | ок |
| `materials:cut_stone` | [materials.materials.cut_stone] |  |  | `materials/cut_stone` | 1 / 1 | ок |
| `materials:iron_ore` | [materials.materials.iron_ore] | ore |  | `materials/iron` | 1 / 0 | ок |
| `materials:tin_ore` | [materials.materials.tin_ore] | ore |  | `materials/tin` | 1 / 0 | ок |
| `materials:gold_ore` | [materials.materials.gold_ore] | ore |  | `materials/gold` | 1 / 0 | ок |
| `materials:gold_block` | [materials.materials.gold_block] |  |  | `materials/gold` | 1 / 1 | ок |
| `materials:platinum_ore` | [materials.materials.platinum_ore] | ore |  | `materials/platinum` | 1 / 0 | ок |
| `materials:platinum_block` | [materials.materials.platinum_block] |  |  | `materials/platinum` | 1 / 1 | ок |
| `materials:silver_ore` | [materials.materials.silver_ore] | ore |  | `materials/silver` | 1 / 0 | ок |
| `materials:silver_block` | [materials.materials.silver_block] |  |  | `materials/silver` | 1 / 1 | ок |

## Деревья (`trees`, 20)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:acacia` | [plants.trees.acacia] | broad |  | `plants/acacia` | 2 / 1 | ок |
| `plants:apple` | [plants.trees.apple] | broad |  | `plants/apple` | 3 / 1 | ок |
| `plants:birch` | [plants.trees.birch] | broad |  | `plants/birch` | 2 / 4 | ок |
| `plants:bird_cherry` | [plants.trees.bird_cherry] | broad |  | `plants/bird_cherry` | 2 / 5 | ок |
| `plants:ceiba` | [plants.trees.ceiba] | broad |  | `plants/ceiba` | 2 / 1 | ок |
| `plants:cherry` | [plants.trees.cherry] | broad |  | `plants/cherry` | 2 / 1 | ок |
| `plants:deadwood` | [plants.trees.deadwood] | broad |  | `plants/deadwood` | 2 / 6 | ок |
| `plants:fir` | [plants.trees.fir] | needles |  | `plants/fir` | 2 / 1 | ок |
| `plants:larch` | [plants.trees.larch] | needles |  | `plants/larch` | 2 / 4 | ок |
| `plants:linden` | [plants.trees.linden] | broad |  | `plants/linden` | 2 / 3 | ок |
| `plants:mangrove` | [plants.trees.mangrove] | broad |  | `plants/mangrove` | 2 / 1 | ок |
| `plants:maple` | [plants.trees.maple] | broad |  | `plants/maple` | 2 / 2 | ок |
| `plants:oak` | [plants.trees.oak] | broad |  | `plants/oak` | 3 / 10 | ок |
| `plants:palm` | [plants.trees.palm] | broad |  | `plants/palm` | 3 / 3 | ок |
| `plants:pine` | [plants.trees.pine] | needles |  | `plants/pine` | 3 / 3 | ок |
| `plants:poplar` | [plants.trees.poplar] | broad |  | `plants/poplar` | 2 / 3 | ок |
| `plants:red_maple` | [plants.trees.red_maple] | broad |  | `plants/red_maple` | 2 / 1 | ок |
| `plants:rowan` | [plants.trees.rowan] | broad |  | `plants/rowan` | 3 / 4 | ок |
| `plants:spruce` | [plants.trees.spruce] | needles |  | `plants/spruce` | 3 / 5 | ок |
| `plants:willow` | [plants.trees.willow] | broad |  | `plants/willow` | 2 / 2 | ок |

## [bushes] (`bushes`, 6)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:blueberry` | [plants.bushes.blueberry] |  |  | `plants/blueberry` | 3 / 8 | ок |
| `plants:currant` | [plants.bushes.currant] |  |  | `plants/currant` | 3 / 4 | ок |
| `plants:raspberry` | [plants.bushes.raspberry] |  |  | `plants/raspberry` | 3 / 4 | ок |
| `plants:rosehip` | [plants.bushes.rosehip] |  |  | `plants/rosehip` | 3 / 5 | ок |
| `plants:shrub` | [plants.bushes.shrub] |  |  | `plants/shrub` | 2 / 21 | ок |
| `plants:banana` | [plants.bushes.banana] |  |  | `plants/banana` | 3 / 2 | ок |

## [plants] (`plants`, 21)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:cranberry` | [plants.plants.cranberry] | custom |  | `plants/cranberry` | 1 / 0 | ок |
| `plants:fern` | [plants.plants.fern] | custom |  | `plants/fern` | 1 / 0 | ок |
| `plants:tuft` | [plants.plants.tuft] | tuft |  | `plants/grass` | 1 / 2 | ок |
| `plants:tall_grass` | [plants.plants.tall_grass] | tall_grass |  | `plants/grass`; патчи: `plants/turnip` | 2 / 1 | ок |
| `plants:flowers` | [plants.plants.flowers] | flowers |  | `plants/grass`; патчи: `plants/peas` | 2 / 2 | ок |
| `plants:herbs` | [plants.plants.herbs] | herbs |  | `plants/grass`; патчи: `plants/carrot` | 2 / 0 | ок |
| `plants:carrot` | [plants.plants.carrot] | crop |  | `plants/carrot` | 2 / 1 | ок |
| `plants:monstera` | [plants.plants.monstera] | custom |  | `plants/monstera` | 3 / 0 | ок |
| `plants:mushrooms` | [plants.plants.mushrooms] | mushrooms |  | `plants/mushrooms` | 1 / 2 | ок |
| `plants:glow_mushrooms` | [plants.plants.glow_mushrooms] | glow_mushrooms |  | `plants/mushrooms` | 1 / 0 | ок |
| `plants:nettle` | [plants.plants.nettle] | custom |  | `plants/nettle` | 1 / 0 | ок |
| `plants:peas` | [plants.plants.peas] | crop |  | `plants/peas` | 1 / 1 | ок |
| `plants:reeds` | [plants.plants.reeds] | reeds |  | `plants/reeds` | 1 / 0 | ок |
| `plants:turnip` | [plants.plants.turnip] | crop |  | `plants/turnip` | 2 / 1 | ок |
| `plants:moss` | [plants.plants.moss] | moss |  | `plants/moss` | 1 / 0 | ок |
| `plants:oak_sapling` | [plants.plants.oak_sapling] | sapling |  | `plants/oak` | 2 / 1 | ок |
| `plants:spruce_sapling` | [plants.plants.spruce_sapling] | sapling |  | `plants/spruce` | 2 / 1 | ок |
| `plants:ears` | [plants.plants.ears] | ears |  | `plants/ears` | 1 / 2 | ок |
| `plants:wheat` | [plants.plants.wheat] | crop |  | `plants/ears` | 1 / 1 | ок |
| `plants:flax` | [plants.plants.flax] | custom |  | `plants/flax` | 5 / 0 | ок |
| `plants:sown_flax` | [plants.plants.sown_flax] | crop |  | `plants/flax` | 2 / 1 | ок |

## Существа (`creatures`, 23)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:human` | [core.creatures.human] |  |  | `core` | 0 / 0 | ок |
| `animals:bear` | [animals.creatures.bear] |  |  | `animals/bear`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:boar` | [animals.creatures.boar] |  |  | `animals/boar`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:butterfly` | [animals.creatures.butterfly] |  |  | `animals/butterfly` | 1 / 0 | ок |
| `animals:cat` | [animals.creatures.cat] |  |  | `animals/cat` | 3 / 0 | ок |
| `animals:crow` | [animals.creatures.crow] |  |  | `animals/crow` | 2 / 0 | ок |
| `animals:deer` | [animals.creatures.deer] |  |  | `animals/deer`; патчи: `biomes/birch_grove`, `biomes/steppe` | 8 / 0 | ок |
| `animals:duck` | [animals.creatures.duck] |  |  | `animals/duck` | 1 / 0 | ок |
| `animals:fox` | [animals.creatures.fox] |  |  | `animals/fox`; патчи: `biomes/birch_grove`, `biomes/steppe` | 6 / 0 | ок |
| `animals:frog` | [animals.creatures.frog] |  |  | `animals/frog` | 0 / 0 | ок |
| `animals:hedgehog` | [animals.creatures.hedgehog] |  |  | `animals/hedgehog`; патчи: `biomes/birch_grove` | 4 / 0 | ок |
| `animals:owl` | [animals.creatures.owl] |  |  | `animals/owl`; патчи: `biomes/birch_grove`, `biomes/pine_wood` | 5 / 0 | ок |
| `animals:perch` | [animals.creatures.perch] |  |  | `animals/perch` | 1 / 0 | ок |
| `animals:rabbit` | [animals.creatures.rabbit] |  |  | `animals/rabbit`; патчи: `biomes/birch_grove`, `biomes/steppe` | 11 / 0 | ок |
| `animals:sparrow` | [animals.creatures.sparrow] |  |  | `animals/sparrow` | 1 / 0 | ок |
| `animals:squirrel` | [animals.creatures.squirrel] |  |  | `animals/squirrel`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:wolf` | [animals.creatures.wolf] |  |  | `animals/wolf`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:roach` | [animals.creatures.roach] |  |  | `animals/fish` | 21 / 0 | ок |
| `animals:pike` | [animals.creatures.pike] |  |  | `animals/fish` | 18 / 0 | ок |
| `animals:salmon` | [animals.creatures.salmon] |  |  | `animals/fish` | 11 / 0 | ок |
| `animals:cod` | [animals.creatures.cod] |  |  | `animals/fish` | 4 / 0 | ок |
| `animals:parrotfish` | [animals.creatures.parrotfish] |  |  | `animals/fish` | 3 / 0 | ок |
| `animals:catfish` | [animals.creatures.catfish] |  |  | `animals/fish` | 15 / 0 | ок |

## [biomes] (`biomes`, 28)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `biomes:alpine_meadow` | [biomes.biomes.alpine_meadow] | alpine |  | `biomes/alpine_meadow` | 3 / 3 | ок |
| `biomes:beach` | [biomes.biomes.beach] | beach |  | `biomes/beach` | 0 / 1 | ок |
| `biomes:birch_grove` | [biomes.biomes.birch_grove] | climate |  | `biomes/birch_grove` | 8 / 8 | ок |
| `biomes:desert` | [biomes.biomes.desert] | climate |  | `biomes/desert` | 1 / 2 | ок |
| `biomes:floodplain` | [biomes.biomes.floodplain] | climate |  | `biomes/floodplain` | 6 / 4 | ок |
| `biomes:forest` | [biomes.biomes.forest] | climate |  | `biomes/forest` | 10 / 13 | ок |
| `biomes:forest_steppe` | [biomes.biomes.forest_steppe] | climate |  | `biomes/forest_steppe` | 6 / 4 | ок |
| `biomes:glacier` | [biomes.biomes.glacier] | glacier |  | `biomes/glacier` | 0 / 2 | ок |
| `biomes:ice_waste` | [biomes.biomes.ice_waste] | climate |  | `biomes/ice_waste` | 0 / 2 | ок |
| `biomes:jungle` | [biomes.biomes.jungle] | climate |  | `biomes/jungle` | 5 / 3 | ок |
| `biomes:mangrove` | [biomes.biomes.mangrove] | swamp |  | `biomes/mangrove` | 3 / 3 | ок |
| `biomes:maple_wood` | [biomes.biomes.maple_wood] | climate |  | `biomes/maple_wood` | 8 / 3 | ок |
| `biomes:meadow` | [biomes.biomes.meadow] | climate |  | `biomes/meadow` | 9 / 10 | ок |
| `biomes:peat_bog` | [biomes.biomes.peat_bog] | climate |  | `biomes/peat_bog` | 5 / 3 | ок |
| `biomes:pine_wood` | [biomes.biomes.pine_wood] | climate |  | `biomes/pine_wood` | 5 / 8 | ок |
| `biomes:plateau` | [biomes.biomes.plateau] | plateau |  | `biomes/plateau` | 1 / 3 | ок |
| `biomes:red_rocks` | [biomes.biomes.red_rocks] | climate |  | `biomes/red_rocks` | 1 / 2 | ок |
| `biomes:rock` | [biomes.biomes.rock] | rock |  | `biomes/rock` | 0 / 3 | ок |
| `biomes:salt_flat` | [biomes.biomes.salt_flat] | climate |  | `biomes/salt_flat` | 0 / 2 | ок |
| `biomes:savanna` | [biomes.biomes.savanna] | climate |  | `biomes/savanna` | 4 / 2 | ок |
| `biomes:sea` | [biomes.biomes.sea] | sea |  | `biomes/sea` | 0 / 1 | ок |
| `biomes:steppe` | [biomes.biomes.steppe] | climate |  | `biomes/steppe` | 2 / 6 | ок |
| `biomes:stony_tundra` | [biomes.biomes.stony_tundra] | climate |  | `biomes/stony_tundra` | 3 / 2 | ок |
| `biomes:swamp` | [biomes.biomes.swamp] | swamp |  | `biomes/swamp` | 5 / 4 | ок |
| `biomes:taiga` | [biomes.biomes.taiga] | climate |  | `biomes/taiga` | 7 / 9 | ок |
| `biomes:tropical_beach` | [biomes.biomes.tropical_beach] | beach |  | `biomes/tropical_beach` | 1 / 0 | ок |
| `biomes:tropical_sea` | [biomes.biomes.tropical_sea] | sea |  | `biomes/tropical_sea` | 0 / 2 | ок |
| `biomes:tundra` | [biomes.biomes.tundra] | climate |  | `biomes/tundra` | 4 / 3 | ок |

## Старт (`starts`, 1)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:default` | [core.starts.default] |  | [core.starts.default.about] | `core`; патчи: `tools/chest` | 2 / 0 | ок |

## Эпохи (`eras`, 7)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:foraging` | [core.eras.foraging] | порядок 0 | [core.eras.foraging.about] | `core` | 0 / 0 | ок |
| `core:primitive` | [core.eras.primitive] | порядок 1 | [core.eras.primitive.about] | `core` | 0 / 13 | ок |
| `core:bone_leather` | [core.eras.bone_leather] | порядок 2 | [core.eras.bone_leather.about] | `core` | 0 / 11 | ок |
| `core:bronze` | [core.eras.bronze] | порядок 3 | [core.eras.bronze.about] | `core` | 0 / 4 | ок |
| `core:alloy` | [core.eras.alloy] | порядок 4 | [core.eras.alloy.about] | `core` | 0 / 1 | ок |
| `core:iron` | [core.eras.iron] | порядок 5 | [core.eras.iron.about] | `core` | 0 / 4 | ок |
| `core:steel` | [core.eras.steel] | порядок 6 | [core.eras.steel.about] | `core` | 0 / 1 | ок |

## Звуки (`sounds`, 56)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `animals:bear` | [animals.sounds.bear] |  |  | `animals/bear` | 0 / 0 | ок |
| `animals:boar` | [animals.sounds.boar] |  |  | `animals/boar` | 0 / 0 | ок |
| `animals:cat` | [animals.sounds.cat] |  |  | `animals/cat` | 0 / 0 | ок |
| `animals:crow` | [animals.sounds.crow] |  |  | `animals/crow` | 0 / 0 | ок |
| `animals:deer` | [animals.sounds.deer] |  |  | `animals/deer` | 0 / 0 | ок |
| `animals:duck` | [animals.sounds.duck] |  |  | `animals/duck` | 0 / 0 | ок |
| `animals:fox` | [animals.sounds.fox] |  |  | `animals/fox` | 0 / 0 | ок |
| `animals:frog` | [animals.sounds.frog] |  |  | `animals/frog` | 0 / 0 | ок |
| `animals:hedgehog` | [animals.sounds.hedgehog] |  |  | `animals/hedgehog` | 0 / 0 | ок |
| `animals:owl` | [animals.sounds.owl] |  |  | `animals/owl` | 0 / 0 | ок |
| `animals:rabbit` | [animals.sounds.rabbit] |  |  | `animals/rabbit` | 0 / 0 | ок |
| `animals:sparrow` | [animals.sounds.sparrow] |  |  | `animals/sparrow` | 0 / 0 | ок |
| `animals:bird` | [animals.sounds.bird] |  |  | `animals/sparrow` | 0 / 0 | ок |
| `animals:squirrel` | [animals.sounds.squirrel] |  |  | `animals/squirrel` | 0 / 0 | ок |
| `animals:wolf_howl` | [animals.sounds.wolf_howl] |  |  | `animals/wolf` | 0 / 0 | ок |
| `animals:wolf_growl` | [animals.sounds.wolf_growl] |  |  | `animals/wolf` | 0 / 0 | ок |
| `materials:knock` | [materials.sounds.knock] |  |  | `materials/planks` | 0 / 0 | ок |
| `music:note_pluck` | [music.sounds.note_pluck] |  |  | `music` | 0 / 0 | ок |
| `music:note_bell` | [music.sounds.note_bell] |  |  | `music` | 0 / 0 | ок |
| `music:pad` | [music.sounds.pad] |  |  | `music` | 0 / 0 | ок |
| `resources:step_sand` | [resources.sounds.step_sand] |  |  | `resources/soil` | 0 / 0 | ок |
| `plants:chop` | [plants.sounds.chop] |  |  | `plants/wood` | 0 / 0 | ок |
| `plants:rustle` | [plants.sounds.rustle] |  |  | `plants/wood` | 0 / 0 | ок |
| `plants:step_wood` | [plants.sounds.step_wood] |  |  | `plants/wood` | 0 / 0 | ок |
| `sounds:wind` | [sounds.sounds.wind] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:rain` | [sounds.sounds.rain] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:hail` | [sounds.sounds.hail] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:blizzard` | [sounds.sounds.blizzard] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:water` | [sounds.sounds.water] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:fire` | [sounds.sounds.fire] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:crickets` | [sounds.sounds.crickets] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:thunder` | [sounds.sounds.thunder] |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:step_grass` | [sounds.sounds.step_grass] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_dirt` | [sounds.sounds.step_dirt] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_stone` | [sounds.sounds.step_stone] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_snow` | [sounds.sounds.step_snow] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_water` | [sounds.sounds.step_water] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:swim` | [sounds.sounds.swim] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:jump` | [sounds.sounds.jump] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:land` | [sounds.sounds.land] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:land_snow` | [sounds.sounds.land_snow] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:splash` | [sounds.sounds.splash] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:dig` | [sounds.sounds.dig] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:hit_stone` | [sounds.sounds.hit_stone] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:place` | [sounds.sounds.place] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:pickup` | [sounds.sounds.pickup] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:craft` | [sounds.sounds.craft] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:eat` | [sounds.sounds.eat] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:ignite` | [sounds.sounds.ignite] |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:click` | [sounds.sounds.click] |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:tab` | [sounds.sounds.tab] |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:open` | [sounds.sounds.open] |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:close` | [sounds.sounds.close] |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:level_up` | [sounds.sounds.level_up] |  |  | `sounds/ui` | 0 / 0 | ок |
| `tools:mow` | [tools.sounds.mow] |  |  | `tools/scythe` | 0 / 0 | ок |
| `tools:swish` | [tools.sounds.swish] |  |  | `tools/sword` | 0 / 0 | ок |

## skills (`skills`, 10)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:gathering` | [core.skills.gathering] |  | [core.skills.gathering.about] | `core` | 0 / 0 | ок |
| `core:chopping` | [core.skills.chopping] |  | [core.skills.chopping.about] | `core` | 0 / 0 | ок |
| `core:digging` | [core.skills.digging] |  | [core.skills.digging.about] | `core` | 0 / 0 | ок |
| `core:crafting` | [core.skills.crafting] |  | [core.skills.crafting.about] | `core` | 0 / 0 | ок |
| `core:building` | [core.skills.building] |  | [core.skills.building.about] | `core` | 0 / 0 | ок |
| `core:cooking` | [core.skills.cooking] |  | [core.skills.cooking.about] | `core` | 0 / 0 | ок |
| `core:hunting` | [core.skills.hunting] |  | [core.skills.hunting.about] | `core` | 0 / 0 | ок |
| `core:fishing` | [core.skills.fishing] |  | [core.skills.fishing.about] | `core` | 0 / 0 | ок |
| `core:swimming` | [core.skills.swimming] |  | [core.skills.swimming.about] | `core` | 0 / 0 | ок |
| `core:farming` | [core.skills.farming] |  | [core.skills.farming.about] | `core` | 0 / 0 | ок |
