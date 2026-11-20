# Граф контента

Создаёт `tools/content_report.gd` из данных всех модов по графу `src/shared/content/content_graph.gd`;
руками не править, CI проверяет, что граф свежий. Правила — раздел 11
[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md), что нашли проверки — [content-checks.md](content-checks.md),
все записи — [content-index.md](content-index.md).

Граф идёт от старта по правилам рук (`Tools`, тем же, что в игре): мир даёт биомы, клетки, растения, деревья
и кусты; действие над ними инструментом, что уже есть, даёт вещи; рецепты делают из них новые на
поставленных станках; поставленное, посаженное и посеянное даёт своё, пока не перестаёт прибавляться новое.
Глубина — сколько шагов изготовления отделяет вещь от старта: что мир и старт дают голыми руками — 0,
добытое инструментом — глубина самого раннего инструмента, который это может, изделие — на 1 больше
самого глубокого из материалов, станка и инструмента своего рецепта.

## Старт

Новый мир начинается по записи `core:default` «[core.starts.default]».

- Сумка: [empty_n2].
- У точки появления: [core.items.campfire], на 4 клетки к западу и на 4 к югу.
- У точки появления: [tools.items.chest], на 4 клетки к востоку и на 2 к югу.

## Предметы по глубине

| Глубина | Предметы |
|---|---|
| 0 | [core.items.rot], [core.items.grave], [plants.items.blueberry], [plants.items.cactus_fruit], [plants.items.cranberry], [plants.items.currant], [plants.items.grass_seeds], [plants.items.carrot_seeds], [plants.items.carrot], [plants.items.mushroom], [plants.items.glow_mushroom], [plants.items.peas], [plants.items.puffball], [plants.items.raspberry], [plants.items.rosehip], [plants.items.turnip_seeds], [plants.items.turnip], [resources.items.fiber], [plants.items.moss], [resources.items.peat], [resources.items.salt], [resources.items.snow], [resources.items.dirt], [resources.items.sand], [resources.items.clay], [materials.items.amber], [resources.items.stone], [resources.items.flint], [resources.items.branch], [plants.items.apple], [plants.items.banana], [plants.items.acorn], [plants.items.coconut], [plants.items.rowan], [plants.items.cone], [tools.items.stairs], [tools.items.live_rabbit], [animals.items.small_carcass], [animals.items.carcass], [plants.items.grain], [animals.items.rabbit_fluff], [plants.items.flax_seeds], [plants.items.flax_stalks], [plants.items.evening_primrose], [plants.items.sundew] |
| 1 | [core.items.campfire], [plants.items.fried_mushrooms], [materials.items.cord], [plants.items.bandage], [materials.items.wattle], [tools.items.fiber_hat], [tools.items.bait], [tools.items.sling_stone], [tools.items.torch], [animals.items.raw_meat], [animals.items.hide], [animals.items.bone], [plants.items.flour], [animals.items.wool_yarn], [plants.items.linen_thread], [plants.items.flower_wreath] |
| 2 | [materials.items.copper_ore], [resources.items.crystal], [plants.items.poultice], [resources.items.ice], [materials.items.ammonite], [materials.items.geode], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [animals.items.perch], [tools.items.fence], [tools.items.wicket], [tools.items.gate], [tools.items.grass_cape], [tools.items.leg_wraps], [tools.items.bast_shoes], [tools.items.fiber_tunic], [tools.items.fishing_rod], [tools.items.ladder], [tools.items.cord_sling], [tools.items.trap], [tools.items.wicker_bag], [tools.items.workbench], [animals.items.roasted_meat], [tools.items.grass_mat], [tools.items.stone_hoe], [tools.items.ice_pick], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.wooden_sword] |
| 3 | [resources.items.log], [animals.items.roasted_fish], [materials.items.cut_stone], [tools.items.arrow], [tools.items.drying_rack], [animals.items.fat], [tools.items.kiln], [tools.items.bone_needle], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword] |
| 4 | [materials.items.brick], [materials.items.charcoal], [materials.items.planks], [materials.items.log_wall], [tools.items.boundary_post], [animals.items.jerky], [materials.items.leather], [tools.items.fur_bedroll], [tools.items.tallow_candle], [tools.items.fur_hat], [plants.items.flatbread], [animals.items.poncho], [tools.items.raft] |
| 5 | [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [tools.items.big_chest], [tools.items.bloomery], [tools.items.wooden_bow], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.fireplace], [tools.items.forge], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.loom], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.potters_wheel], [tools.items.oars], [tools.items.rain_barrel], [tools.items.rain_catcher], [tools.items.wooden_shovel], [tools.items.sign], [tools.items.signpost], [tools.items.notice_board], [tools.items.watering_can], [tools.items.watering_can_full], [tools.items.waterskin], [tools.items.waterskin_full], [tools.items.waterskin_sea] |
| 6 | [materials.items.cloth], [materials.items.copper_bar], [materials.items.glass], [tools.items.raw_pot], [materials.items.raw_crucible] |
| 7 | [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [materials.items.tin_ore], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.wooden_bed], [tools.items.rug], [tools.items.pot], [materials.items.crucible], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2] |
| 8 | [materials.items.tin_bar], [materials.items.bone_glue], [materials.items.tar], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| 9 | [materials.items.bronze_bar], [tools.items.boat], [tools.items.composite_bow], [tools.items.lantern], [tools.items.tar_torch] |
| 10 | [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword] |
| 11 | [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar] |
| 12 | [materials.items.iron_bar] |
| 13 | [tools.items.anvil], [materials.items.steel_bar] |
| 14 | [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword] |

## Откуда и куда

Откуда — все пути к предмету, первым тот, что даёт ему глубину. Куда — рецепты, которые его тратят,
рецепты на нём как на станке, что им чинят, и для чего он сам.

| Предмет | Глубина | Откуда | Куда |
|---|---|---|---|
| [core.items.campfire] `core:campfire` | 1 | рецепт: [resources.recipes.campfire] | станок рецептов: [plants.recipes.fried_mushrooms], [plants.recipes.poultice], [animals.recipes.roasted_fish_from_roach], [animals.recipes.roasted_fish_from_pike], [animals.recipes.roasted_fish_from_salmon], [animals.recipes.roasted_fish_from_cod], [animals.recipes.roasted_fish_from_parrotfish], [animals.recipes.roasted_fish_from_catfish], [animals.recipes.roasted_fish_from_perch], [animals.recipes.roasted_meat], [materials.recipes.bone_glue], [plants.recipes.primrose_tea], [plants.recipes.roasted_acorns], [plants.recipes.bone_glue_from_sundew], [tools.recipes.waterskin_full_from_waterskin_sea], [tools.recipes.waterskin_full_from_pot]; горит: тушится и разжигается топливом |
| [core.items.rot] `core:rot` | 0 | особый источник; spoil: [plants.items.blueberry], [plants.items.cactus_fruit], [plants.items.cranberry], [plants.items.currant], [plants.items.carrot], [plants.items.mushroom], [plants.items.glow_mushroom], [plants.items.fried_mushrooms], [plants.items.puffball], [plants.items.raspberry], [plants.items.rosehip], [plants.items.turnip], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [animals.items.perch], [animals.items.roasted_fish], [plants.items.apple], [plants.items.banana], [plants.items.rowan], [animals.items.raw_meat], [animals.items.roasted_meat], [plants.items.evening_primrose], [plants.items.primrose_tea] | — |
| [core.items.grave] `core:grave` | 0 | особый источник | станок |
| [materials.items.brick] `materials:brick` | 4 | рецепт: [tools.recipes.brick]; копать: [materials.materials.brick] | в рецепты: [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge]; [block]: [materials.materials.brick] |
| [materials.items.charcoal] `materials:charcoal` | 4 | рецепт: [tools.recipes.charcoal]; побочно: [materials.recipes.tar] | в рецепты: [tools.recipes.copper_bar], [materials.recipes.glass], [materials.recipes.iron_bloom], [materials.recipes.iron_bar], [materials.recipes.tin_bar], [materials.recipes.gold_bar], [materials.recipes.platinum_bar], [materials.recipes.silver_bar], [materials.recipes.bronze_bar], [materials.recipes.steel_bar]; топливо |
| [materials.items.cloth] `materials:cloth` | 6 | рецепт: [tools.recipes.cloth_from_cord], [animals.recipes.cloth_from_wool_yarn], [plants.recipes.cloth] | в рецепты: [tools.recipes.bandana], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.canvas_backpack], [tools.recipes.wooden_bed], [tools.recipes.rug], [tools.recipes.tar_torch] |
| [materials.items.copper_ore] `materials:copper_ore` | 2 | копать: [materials.materials.copper_ore] | в рецепты: [tools.recipes.copper_bar] |
| [materials.items.copper_bar] `materials:copper_bar` | 6 | рецепт: [tools.recipes.copper_bar] | чинит: [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword]; в рецепты: [tools.recipes.copper_hoe], [tools.recipes.ice_auger], [materials.recipes.bronze_bar], [tools.recipes.copper_axe], [tools.recipes.copper_knife], [tools.recipes.lantern], [tools.recipes.copper_pickaxe], [tools.recipes.copper_scythe], [tools.recipes.copper_shovel], [tools.recipes.copper_sickle], [tools.recipes.copper_sword] |
| [materials.items.planks] `materials:planks` | 4 | рецепт: [tools.recipes.planks]; копать: [materials.materials.planks] | чинит: [tools.items.wooden_shovel]; в рецепты: [tools.recipes.big_chest], [tools.recipes.wooden_bow], [tools.recipes.chest], [tools.recipes.door], [tools.recipes.door_2x2], [tools.recipes.door_2x3], [tools.recipes.door_3x3], [tools.recipes.hatch], [tools.recipes.hatch_2x2], [tools.recipes.copper_hoe], [tools.recipes.iron_hoe], [tools.recipes.ice_auger], [tools.recipes.loom], [tools.recipes.table], [tools.recipes.stool], [tools.recipes.wooden_bed], [tools.recipes.cupboard], [tools.recipes.wide_cupboard], [tools.recipes.barrel], [tools.recipes.potters_wheel], [tools.recipes.copper_axe], [tools.recipes.bronze_axe], [tools.recipes.iron_axe], [tools.recipes.steel_axe], [tools.recipes.boat], [tools.recipes.oars], [tools.recipes.copper_knife], [tools.recipes.bronze_knife], [tools.recipes.iron_knife], [tools.recipes.steel_knife], [tools.recipes.copper_pickaxe], [tools.recipes.bronze_pickaxe], [tools.recipes.iron_pickaxe], [tools.recipes.steel_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.copper_scythe], [tools.recipes.bronze_scythe], [tools.recipes.iron_scythe], [tools.recipes.steel_scythe], [tools.recipes.wooden_shovel], [tools.recipes.copper_shovel], [tools.recipes.bronze_shovel], [tools.recipes.iron_shovel], [tools.recipes.steel_shovel], [tools.recipes.sign], [tools.recipes.signpost], [tools.recipes.notice_board], [tools.recipes.bronze_spear], [tools.recipes.iron_spear], [tools.recipes.copper_sword], [tools.recipes.bronze_sword], [tools.recipes.iron_sword], [tools.recipes.steel_sword], [tools.recipes.watering_can], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2]; [block]: [materials.materials.planks] |
| [plants.items.blueberry] `plants:blueberry` | 0 | собирать: [plants.bushes.blueberry] | еда |
| [plants.items.blueberry_bush] `plants:blueberry_bush` | 5 | выкопать: [plants.bushes.blueberry] | сажает: [plants.bushes.blueberry] |
| [plants.items.cactus_fruit] `plants:cactus_fruit` | 0 | [mow_n2]: [plants.plants.cactus] | еда |
| [plants.items.cranberry] `plants:cranberry` | 0 | [mow_n2]: [plants.plants.cranberry] | еда |
| [plants.items.currant] `plants:currant` | 0 | собирать: [plants.bushes.currant] | еда |
| [plants.items.currant_bush] `plants:currant_bush` | 5 | выкопать: [plants.bushes.currant] | сажает: [plants.bushes.currant] |
| [plants.items.grass_seeds] `plants:grass_seeds` | 0 | [mow_n2]: [plants.plants.tuft], [plants.plants.flowers] | засевает: [core.materials.grass] |
| [plants.items.carrot_seeds] `plants:carrot_seeds` | 0 | [mow_n2]: [plants.plants.carrot], [plants.plants.herbs] | растит: [plants.plants.carrot] |
| [plants.items.carrot] `plants:carrot` | 0 | [mow_n2]: [plants.plants.carrot] | feeds_on: [animals.creatures.rabbit]; еда |
| [plants.items.juniper_bush] `plants:juniper_bush` | 5 | выкопать: [plants.bushes.juniper] | сажает: [plants.bushes.juniper] |
| [plants.items.mushroom] `plants:mushroom` | 0 | [mow_n2]: [plants.plants.mushrooms] | в рецепты: [plants.recipes.fried_mushrooms]; еда |
| [plants.items.glow_mushroom] `plants:glow_mushroom` | 0 | [mow_n2]: [plants.plants.glow_mushrooms] | еда |
| [plants.items.fried_mushrooms] `plants:fried_mushrooms` | 1 | рецепт: [plants.recipes.fried_mushrooms] | еда; лечит |
| [plants.items.peas] `plants:peas` | 0 | [mow_n2]: [plants.plants.peas], [plants.plants.flowers] | растит: [plants.plants.peas]; еда |
| [plants.items.puffball] `plants:puffball` | 0 | [mow_n2]: [plants.plants.puffball] | еда |
| [plants.items.raspberry] `plants:raspberry` | 0 | собирать: [plants.bushes.raspberry] | еда |
| [plants.items.raspberry_bush] `plants:raspberry_bush` | 5 | выкопать: [plants.bushes.raspberry] | сажает: [plants.bushes.raspberry] |
| [plants.items.rosehip] `plants:rosehip` | 0 | собирать: [plants.bushes.rosehip] | еда |
| [plants.items.rosehip_bush] `plants:rosehip_bush` | 5 | выкопать: [plants.bushes.rosehip] | сажает: [plants.bushes.rosehip] |
| [plants.items.shrub_bush] `plants:shrub_bush` | 5 | выкопать: [plants.bushes.shrub] | сажает: [plants.bushes.shrub] |
| [plants.items.turnip_seeds] `plants:turnip_seeds` | 0 | [mow_n2]: [plants.plants.turnip], [plants.plants.tall_grass] | растит: [plants.plants.turnip] |
| [plants.items.turnip] `plants:turnip` | 0 | [mow_n2]: [plants.plants.turnip] | feeds_on: [animals.creatures.rabbit]; еда |
| [resources.items.crystal] `resources:crystal` | 2 | копать: [resources.materials.crystal] | [block]: [resources.materials.crystal] |
| [resources.items.fiber] `resources:fiber` | 0 | копать: [core.materials.grass]; [mow_n2]: [core.materials.grass], [plants.plants.cactus], [plants.plants.cattail], [plants.plants.clover], [plants.plants.fern], [plants.plants.tall_grass], [plants.plants.herbs], [plants.plants.sedge], [plants.plants.mimosa], [plants.plants.monstera], [plants.plants.nettle], [plants.plants.reeds] | в рецепты: [materials.recipes.cord], [plants.recipes.bandage], [resources.recipes.campfire], [tools.recipes.fiber_hat], [tools.recipes.grass_cape], [tools.recipes.leg_wraps], [tools.recipes.bast_shoes], [tools.recipes.fiber_tunic], [tools.recipes.cord_sling], [tools.recipes.torch], [tools.recipes.wicker_bag], [tools.recipes.arrow], [tools.recipes.grass_mat], [tools.recipes.tallow_candle], [plants.recipes.flower_wreath], [tools.recipes.arrow_from_bone] |
| [materials.items.cord] `materials:cord` | 1 | рецепт: [materials.recipes.cord] | чинит: [tools.items.fishing_rod], [tools.items.cord_sling], [tools.items.wooden_bow], [tools.items.stone_hoe], [tools.items.winter_rod], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sickle], [tools.items.stone_sword]; в рецепты: [tools.recipes.boundary_post], [tools.recipes.fence], [tools.recipes.wicket], [tools.recipes.gate], [tools.recipes.grass_cape], [tools.recipes.leg_wraps], [tools.recipes.bast_shoes], [tools.recipes.fiber_tunic], [tools.recipes.fishing_rod], [tools.recipes.ladder], [tools.recipes.cord_sling], [tools.recipes.trap], [tools.recipes.wicker_bag], [tools.recipes.workbench], [tools.recipes.big_chest], [tools.recipes.wooden_bow], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.drying_rack], [tools.recipes.grass_mat], [tools.recipes.fur_bedroll], [tools.recipes.canvas_backpack], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.stone_hoe], [tools.recipes.ice_pick], [tools.recipes.winter_rod], [tools.recipes.leather_bag], [tools.recipes.leather_sling], [tools.recipes.loom], [tools.recipes.cloth_from_cord], [tools.recipes.barrel], [tools.recipes.stone_axe], [tools.recipes.raft], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.wooden_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.wooden_scythe], [tools.recipes.stone_sickle], [tools.recipes.flint_spear], [tools.recipes.wooden_sword], [tools.recipes.stone_sword], [tools.recipes.watering_can], [tools.recipes.waterskin] |
| [plants.items.moss] `plants:moss` | 0 | [mow_n2]: [plants.plants.moss] | в рецепты: [plants.recipes.bandage], [plants.recipes.poultice] |
| [plants.items.bandage] `plants:bandage` | 1 | рецепт: [plants.recipes.bandage] | в рецепты: [plants.recipes.poultice]; лечит |
| [plants.items.poultice] `plants:poultice` | 2 | рецепт: [plants.recipes.poultice] | лечит |
| [resources.items.peat] `resources:peat` | 0 | копать: [resources.materials.peat] | [block]: [resources.materials.peat]; топливо |
| [resources.items.salt] `resources:salt` | 0 | копать: [resources.materials.salt]; побочно: [tools.recipes.waterskin_full_from_pot] | [block]: [resources.materials.salt] |
| [resources.items.snow] `resources:snow` | 0 | копать: [resources.materials.snow] | [block]: [resources.materials.snow] |
| [resources.items.ice] `resources:ice` | 2 | копать: [resources.materials.ice] | [block]: [resources.materials.ice] |
| [resources.items.dirt] `resources:dirt` | 0 | копать: [core.materials.grass], [core.materials.dirt], [resources.materials.mycelium], [resources.materials.bed], [resources.materials.bed_wet], [resources.materials.ash] | в рецепты: [tools.recipes.bait]; [block]: [core.materials.dirt] |
| [resources.items.sand] `resources:sand` | 0 | копать: [resources.materials.sand], [resources.materials.black_sand] | в рецепты: [materials.recipes.glass], [materials.recipes.raw_crucible]; [block]: [resources.materials.sand] |
| [resources.items.clay] `resources:clay` | 0 | копать: [resources.materials.clay] | в рецепты: [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.kiln], [tools.recipes.brick], [tools.recipes.raw_pot], [materials.recipes.raw_crucible]; [block]: [resources.materials.clay] |
| [materials.items.ammonite] `materials:ammonite` | 2 | копать: [core.materials.stone] | станок |
| [materials.items.geode] `materials:geode` | 2 | копать: [core.materials.stone] | станок |
| [materials.items.amber] `materials:amber` | 0 | копать: [resources.materials.peat], [resources.materials.sand], [resources.materials.clay] | станок |
| [resources.items.stone] `resources:stone` | 0 | копать: [resources.materials.scree], [core.materials.stone], [resources.materials.deepstone], [resources.materials.basalt] | чинит: [tools.items.ice_pick]; в рецепты: [tools.recipes.sling_stone], [materials.recipes.cut_stone], [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.ice_pick], [tools.recipes.kiln], [tools.recipes.potters_wheel]; [block]: [core.materials.stone] |
| [resources.items.flint] `resources:flint` | 0 | копать: [core.materials.dirt], [resources.materials.sand], [resources.materials.scree] | чинит: [tools.items.stone_hoe], [tools.items.stone_axe], [tools.items.flint_knife], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.stone_sword]; в рецепты: [tools.recipes.fishing_rod], [tools.recipes.arrow], [tools.recipes.stone_hoe], [tools.recipes.winter_rod], [tools.recipes.stone_axe], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.stone_scythe], [tools.recipes.stone_sickle], [tools.recipes.flint_spear], [tools.recipes.stone_sword] |
| [resources.items.branch] `resources:branch` | 0 | собирать: [plants.trees.acacia], [plants.trees.apple], [plants.trees.birch], [plants.trees.bird_cherry], [plants.trees.ceiba], [plants.trees.cherry], [plants.trees.deadwood], [plants.trees.fir], [plants.trees.larch], [plants.trees.linden], [plants.trees.mangrove], [plants.trees.maple], [plants.trees.oak], [plants.trees.palm], [plants.trees.pine], [plants.trees.poplar], [plants.trees.red_maple], [plants.trees.rowan], [plants.trees.spruce], [plants.trees.willow], [plants.bushes.blueberry], [plants.bushes.currant], [plants.bushes.juniper], [plants.bushes.raspberry], [plants.bushes.rosehip], [plants.bushes.shrub], [plants.bushes.banana] | чинит: [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.wooden_sword]; в рецепты: [resources.recipes.campfire], [animals.recipes.roasted_fish_from_roach], [animals.recipes.roasted_fish_from_pike], [animals.recipes.roasted_fish_from_salmon], [animals.recipes.roasted_fish_from_cod], [animals.recipes.roasted_fish_from_parrotfish], [animals.recipes.roasted_fish_from_catfish], [animals.recipes.roasted_fish_from_perch], [materials.recipes.wattle], [tools.recipes.boundary_post], [tools.recipes.fence], [tools.recipes.wicket], [tools.recipes.gate], [tools.recipes.fishing_rod], [tools.recipes.ladder], [tools.recipes.torch], [tools.recipes.trap], [tools.recipes.workbench], [tools.recipes.arrow], [tools.recipes.drying_rack], [animals.recipes.roasted_meat], [tools.recipes.stone_hoe], [tools.recipes.ice_pick], [tools.recipes.winter_rod], [tools.recipes.loom], [tools.recipes.potters_wheel], [materials.recipes.bone_glue], [plants.recipes.bone_glue_from_sundew], [tools.recipes.stone_axe], [tools.recipes.arrow_from_bone], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.wooden_pickaxe], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.wooden_scythe], [tools.recipes.wooden_shovel], [tools.recipes.stone_sickle], [tools.recipes.copper_sickle], [tools.recipes.iron_sickle], [tools.recipes.sign], [tools.recipes.signpost], [tools.recipes.flint_spear], [tools.recipes.wooden_sword], [tools.recipes.stone_sword], [tools.recipes.tar_torch]; топливо |
| [resources.items.log] `resources:log` | 3 | [chop_n2]: [plants.trees.acacia], [plants.trees.apple], [plants.trees.birch], [plants.trees.bird_cherry], [plants.trees.ceiba], [plants.trees.cherry], [plants.trees.deadwood], [plants.trees.fir], [plants.trees.larch], [plants.trees.linden], [plants.trees.mangrove], [plants.trees.maple], [plants.trees.oak], [plants.trees.palm], [plants.trees.pine], [plants.trees.poplar], [plants.trees.red_maple], [plants.trees.rowan], [plants.trees.spruce], [plants.trees.willow]; копать: [plants.materials.log] | в рецепты: [materials.recipes.log_wall], [tools.recipes.boundary_post], [tools.recipes.anvil], [tools.recipes.charcoal], [materials.recipes.tar], [tools.recipes.planks], [tools.recipes.raft]; [block]: [plants.materials.log]; топливо |
| [animals.items.roach] `animals:roach` | 2 | fish: [animals.creatures.roach] | в рецепты: [animals.recipes.roasted_fish_from_roach]; еда |
| [animals.items.pike] `animals:pike` | 2 | fish: [animals.creatures.pike] | в рецепты: [animals.recipes.roasted_fish_from_pike]; еда |
| [animals.items.salmon] `animals:salmon` | 2 | fish: [animals.creatures.salmon] | в рецепты: [animals.recipes.roasted_fish_from_salmon]; еда |
| [animals.items.cod] `animals:cod` | 2 | fish: [animals.creatures.cod] | в рецепты: [animals.recipes.roasted_fish_from_cod]; еда |
| [animals.items.parrotfish] `animals:parrotfish` | 2 | fish: [animals.creatures.parrotfish] | в рецепты: [animals.recipes.roasted_fish_from_parrotfish]; еда |
| [animals.items.catfish] `animals:catfish` | 2 | fish: [animals.creatures.catfish] | в рецепты: [animals.recipes.roasted_fish_from_catfish]; еда |
| [animals.items.perch] `animals:perch` | 2 | fish: [animals.creatures.perch] | в рецепты: [animals.recipes.roasted_fish_from_perch]; еда |
| [animals.items.roasted_fish] `animals:roasted_fish` | 3 | рецепт: [animals.recipes.roasted_fish_from_roach], [animals.recipes.roasted_fish_from_pike], [animals.recipes.roasted_fish_from_salmon], [animals.recipes.roasted_fish_from_cod], [animals.recipes.roasted_fish_from_parrotfish], [animals.recipes.roasted_fish_from_catfish], [animals.recipes.roasted_fish_from_perch] | еда; лечит |
| [materials.items.log_wall] `materials:log_wall` | 4 | рецепт: [materials.recipes.log_wall]; копать: [materials.materials.log_wall] | [block]: [materials.materials.log_wall] |
| [materials.items.wattle] `materials:wattle` | 1 | рецепт: [materials.recipes.wattle]; копать: [materials.materials.wattle] | [block]: [materials.materials.wattle] |
| [plants.items.apple] `plants:apple` | 0 | собирать: [plants.trees.apple] | еда |
| [plants.items.banana] `plants:banana` | 0 | собирать: [plants.bushes.banana] | еда |
| [plants.items.banana_bush] `plants:banana_bush` | 5 | выкопать: [plants.bushes.banana] | сажает: [plants.bushes.banana] |
| [plants.items.acorn] `plants:acorn` | 0 | [mow_n2]: [plants.plants.oak_sapling]; собирать: [plants.trees.oak] | в рецепты: [plants.recipes.roasted_acorns]; растит: [plants.plants.oak_sapling] |
| [plants.items.coconut] `plants:coconut` | 0 | собирать: [plants.trees.palm] | еда |
| [plants.items.rowan] `plants:rowan` | 0 | собирать: [plants.trees.rowan] | еда |
| [plants.items.cone] `plants:cone` | 0 | [mow_n2]: [plants.plants.spruce_sapling]; собирать: [plants.trees.pine], [plants.trees.spruce] | растит: [plants.plants.spruce_sapling]; топливо |
| [tools.items.boundary_post] `tools:boundary_post` | 4 | рецепт: [tools.recipes.boundary_post] | станок |
| [tools.items.fence] `tools:fence` | 2 | рецепт: [tools.recipes.fence] | станок |
| [tools.items.wicket] `tools:wicket` | 2 | рецепт: [tools.recipes.wicket] | станок |
| [tools.items.gate] `tools:gate` | 2 | рецепт: [tools.recipes.gate] | станок |
| [tools.items.fiber_hat] `tools:fiber_hat` | 1 | рецепт: [tools.recipes.fiber_hat] | — |
| [tools.items.grass_cape] `tools:grass_cape` | 2 | рецепт: [tools.recipes.grass_cape] | — |
| [tools.items.leg_wraps] `tools:leg_wraps` | 2 | рецепт: [tools.recipes.leg_wraps] | — |
| [tools.items.bast_shoes] `tools:bast_shoes` | 2 | рецепт: [tools.recipes.bast_shoes] | — |
| [tools.items.fiber_tunic] `tools:fiber_tunic` | 2 | рецепт: [tools.recipes.fiber_tunic] | — |
| [tools.items.fishing_rod] `tools:fishing_rod` | 2 | рецепт: [tools.recipes.fishing_rod] | инструмент: [tool.rod] |
| [tools.items.bait] `tools:bait` | 1 | рецепт: [tools.recipes.bait] | в рецепты: [tools.items.fishing_rod], [tools.items.winter_rod] |
| [tools.items.ladder] `tools:ladder` | 2 | рецепт: [tools.recipes.ladder] | станок |
| [tools.items.cord_sling] `tools:cord_sling` | 2 | рецепт: [tools.recipes.cord_sling] | инструмент: [tool.sling] |
| [tools.items.sling_stone] `tools:sling_stone` | 1 | рецепт: [tools.recipes.sling_stone] | в рецепты: [tools.items.cord_sling], [tools.items.leather_sling] |
| [tools.items.stairs] `tools:stairs` | 0 | особый источник | станок |
| [tools.items.torch] `tools:torch` | 1 | рецепт: [tools.recipes.torch] | свет |
| [tools.items.trap] `tools:trap` | 2 | рецепт: [tools.recipes.trap] | хранит вещи: 2 мест |
| [tools.items.live_rabbit] `tools:live_rabbit` | 0 | trap: [animals.creatures.rabbit] | — |
| [tools.items.wicker_bag] `tools:wicker_bag` | 2 | рецепт: [tools.recipes.wicker_bag] | — |
| [tools.items.workbench] `tools:workbench` | 2 | рецепт: [tools.recipes.workbench] | станок рецептов: [materials.recipes.cut_stone], [tools.recipes.big_chest], [tools.recipes.bloomery], [tools.recipes.wooden_bow], [tools.recipes.arrow], [tools.recipes.chest], [tools.recipes.bandana], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.door], [tools.recipes.door_2x2], [tools.recipes.door_2x3], [tools.recipes.door_3x3], [tools.recipes.drying_rack], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.anvil], [tools.recipes.hatch], [tools.recipes.hatch_2x2], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.copper_hoe], [tools.recipes.ice_auger], [tools.recipes.kiln], [tools.recipes.loom], [animals.recipes.poncho], [tools.recipes.table], [tools.recipes.stool], [tools.recipes.wooden_bed], [tools.recipes.cupboard], [tools.recipes.wide_cupboard], [tools.recipes.barrel], [tools.recipes.potters_wheel], [tools.recipes.stone_axe], [tools.recipes.planks], [tools.recipes.copper_axe], [tools.recipes.bronze_axe], [tools.recipes.boat], [tools.recipes.oars], [tools.recipes.composite_bow], [tools.recipes.arrow_from_bone], [tools.recipes.copper_knife], [tools.recipes.bronze_knife], [tools.recipes.lantern], [tools.recipes.stone_pickaxe], [tools.recipes.copper_pickaxe], [tools.recipes.bronze_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.copper_scythe], [tools.recipes.bronze_scythe], [tools.recipes.wooden_shovel], [tools.recipes.copper_shovel], [tools.recipes.bronze_shovel], [tools.recipes.copper_sickle], [tools.recipes.notice_board], [tools.recipes.bronze_spear], [tools.recipes.stone_sword], [tools.recipes.copper_sword], [tools.recipes.bronze_sword], [tools.recipes.watering_can], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2]; здесь чинят инструменты |
| [materials.items.cut_stone] `materials:cut_stone` | 3 | рецепт: [materials.recipes.cut_stone]; копать: [materials.materials.cut_stone] | [block]: [materials.materials.cut_stone] |
| [tools.items.big_chest] `tools:big_chest` | 5 | рецепт: [tools.recipes.big_chest] | хранит вещи: 40 мест |
| [tools.items.bloomery] `tools:bloomery` | 5 | рецепт: [tools.recipes.bloomery] | станок рецептов: [materials.recipes.iron_bloom], [materials.recipes.steel_bar] |
| [tools.items.wooden_bow] `tools:wooden_bow` | 5 | рецепт: [tools.recipes.wooden_bow] | в рецепты: [tools.recipes.composite_bow]; инструмент: [tool.bow] |
| [tools.items.arrow] `tools:arrow` | 3 | рецепт: [tools.recipes.arrow], [tools.recipes.arrow_from_bone] | в рецепты: [tools.items.wooden_bow], [tools.items.composite_bow] |
| [tools.items.chest] `tools:chest` | 5 | рецепт: [tools.recipes.chest] | хранит вещи: 16 мест |
| [tools.items.bandana] `tools:bandana` | 7 | рецепт: [tools.recipes.bandana] | — |
| [tools.items.hood] `tools:hood` | 7 | рецепт: [tools.recipes.hood] | — |
| [tools.items.linen_shirt] `tools:linen_shirt` | 7 | рецепт: [tools.recipes.linen_shirt] | — |
| [tools.items.door] `tools:door` | 5 | рецепт: [tools.recipes.door] | станок |
| [tools.items.door_2x2] `tools:door_2x2` | 5 | рецепт: [tools.recipes.door_2x2] | станок |
| [tools.items.door_2x3] `tools:door_2x3` | 5 | рецепт: [tools.recipes.door_2x3] | станок |
| [tools.items.door_3x3] `tools:door_3x3` | 5 | рецепт: [tools.recipes.door_3x3] | станок |
| [tools.items.drying_rack] `tools:drying_rack` | 3 | рецепт: [tools.recipes.drying_rack] | станок рецептов: [animals.recipes.jerky], [materials.recipes.leather] |
| [animals.items.small_carcass] `animals:small_carcass` | 0 | hunt: [animals.creatures.cat], [animals.creatures.crow], [animals.creatures.duck], [animals.creatures.fox], [animals.creatures.hedgehog], [animals.creatures.owl], [animals.creatures.rabbit], [animals.creatures.squirrel] | в рецепты: [animals.recipes.raw_meat_from_small_carcass] |
| [animals.items.carcass] `animals:carcass` | 0 | hunt: [animals.creatures.bear], [animals.creatures.boar], [animals.creatures.deer], [animals.creatures.wolf] | в рецепты: [animals.recipes.raw_meat_from_carcass] |
| [animals.items.raw_meat] `animals:raw_meat` | 1 | рецепт: [animals.recipes.raw_meat_from_small_carcass], [animals.recipes.raw_meat_from_carcass] | в рецепты: [animals.recipes.roasted_meat], [animals.recipes.jerky]; еда |
| [animals.items.roasted_meat] `animals:roasted_meat` | 2 | рецепт: [animals.recipes.roasted_meat] | еда; лечит |
| [animals.items.hide] `animals:hide` | 1 | побочно: [animals.recipes.raw_meat_from_small_carcass], [animals.recipes.raw_meat_from_carcass] | в рецепты: [materials.recipes.leather], [tools.recipes.fur_bedroll], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.fur_boots] |
| [animals.items.bone] `animals:bone` | 1 | побочно: [animals.recipes.raw_meat_from_small_carcass], [animals.recipes.raw_meat_from_carcass] | в рецепты: [tools.recipes.bone_needle], [materials.recipes.bone_glue], [tools.recipes.composite_bow], [tools.recipes.arrow_from_bone] |
| [animals.items.fat] `animals:fat` | 3 | побочно: [animals.recipes.raw_meat_from_carcass] | в рецепты: [materials.recipes.leather], [tools.recipes.tallow_candle] |
| [animals.items.jerky] `animals:jerky` | 4 | рецепт: [animals.recipes.jerky] | еда; лечит |
| [materials.items.leather] `materials:leather` | 4 | рецепт: [materials.recipes.leather] | чинит: [tools.items.leather_sling]; в рецепты: [tools.recipes.canvas_backpack], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.leather_bag], [tools.recipes.leather_sling], [tools.recipes.composite_bow], [tools.recipes.rain_catcher], [tools.recipes.waterskin] |
| [tools.items.grass_mat] `tools:grass_mat` | 2 | рецепт: [tools.recipes.grass_mat] | станок |
| [tools.items.fur_bedroll] `tools:fur_bedroll` | 4 | рецепт: [tools.recipes.fur_bedroll] | станок |
| [tools.items.tallow_candle] `tools:tallow_candle` | 4 | рецепт: [tools.recipes.tallow_candle] | свет |
| [tools.items.canvas_backpack] `tools:canvas_backpack` | 7 | рецепт: [tools.recipes.canvas_backpack] | — |
| [tools.items.fireplace] `tools:fireplace` | 5 | рецепт: [tools.recipes.fireplace] | станок; горит: тушится и разжигается топливом; заменяет: [core.items.campfire] |
| [tools.items.forge] `tools:forge` | 5 | рецепт: [tools.recipes.forge] | станок рецептов: [tools.recipes.copper_bar], [materials.recipes.glass], [materials.recipes.iron_bar], [materials.recipes.tin_bar], [materials.recipes.gold_bar], [materials.recipes.platinum_bar], [materials.recipes.silver_bar], [materials.recipes.bronze_bar] |
| [materials.items.glass] `materials:glass` | 6 | рецепт: [materials.recipes.glass] | в рецепты: [tools.recipes.lantern], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2] |
| [materials.items.iron_ore] `materials:iron_ore` | 10 | копать: [materials.materials.iron_ore] | в рецепты: [materials.recipes.iron_bloom] |
| [materials.items.iron_bloom] `materials:iron_bloom` | 11 | рецепт: [materials.recipes.iron_bloom] | в рецепты: [materials.recipes.iron_bar] |
| [materials.items.iron_bar] `materials:iron_bar` | 12 | рецепт: [materials.recipes.iron_bar] | чинит: [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword]; в рецепты: [tools.recipes.anvil], [tools.recipes.iron_hoe], [materials.recipes.steel_bar], [tools.recipes.iron_axe], [tools.recipes.iron_knife], [tools.recipes.iron_pickaxe], [tools.recipes.iron_scythe], [tools.recipes.iron_shovel], [tools.recipes.iron_sickle], [tools.recipes.iron_spear], [tools.recipes.iron_sword] |
| [materials.items.tin_ore] `materials:tin_ore` | 7 | копать: [materials.materials.tin_ore] | в рецепты: [materials.recipes.tin_bar] |
| [materials.items.tin_bar] `materials:tin_bar` | 8 | рецепт: [materials.recipes.tin_bar] | в рецепты: [materials.recipes.bronze_bar] |
| [tools.items.anvil] `tools:anvil` | 13 | рецепт: [tools.recipes.anvil] | станок рецептов: [materials.recipes.gold_block], [materials.recipes.platinum_block], [materials.recipes.silver_block], [tools.recipes.iron_hoe], [tools.recipes.iron_axe], [tools.recipes.steel_axe], [tools.recipes.iron_knife], [tools.recipes.steel_knife], [tools.recipes.iron_pickaxe], [tools.recipes.steel_pickaxe], [tools.recipes.iron_scythe], [tools.recipes.steel_scythe], [tools.recipes.iron_shovel], [tools.recipes.steel_shovel], [tools.recipes.iron_sickle], [tools.recipes.iron_spear], [tools.recipes.iron_sword], [tools.recipes.steel_sword] |
| [materials.items.gold_ore] `materials:gold_ore` | 10 | копать: [materials.materials.gold_ore] | в рецепты: [materials.recipes.gold_bar] |
| [materials.items.gold_bar] `materials:gold_bar` | 11 | рецепт: [materials.recipes.gold_bar] | в рецепты: [materials.recipes.gold_block] |
| [materials.items.gold_block] `materials:gold_block` | 14 | рецепт: [materials.recipes.gold_block]; копать: [materials.materials.gold_block] | [block]: [materials.materials.gold_block] |
| [materials.items.platinum_ore] `materials:platinum_ore` | 10 | копать: [materials.materials.platinum_ore] | в рецепты: [materials.recipes.platinum_bar] |
| [materials.items.platinum_bar] `materials:platinum_bar` | 11 | рецепт: [materials.recipes.platinum_bar] | в рецепты: [materials.recipes.platinum_block] |
| [materials.items.platinum_block] `materials:platinum_block` | 14 | рецепт: [materials.recipes.platinum_block]; копать: [materials.materials.platinum_block] | [block]: [materials.materials.platinum_block] |
| [materials.items.silver_ore] `materials:silver_ore` | 10 | копать: [materials.materials.silver_ore] | в рецепты: [materials.recipes.silver_bar] |
| [materials.items.silver_bar] `materials:silver_bar` | 11 | рецепт: [materials.recipes.silver_bar] | в рецепты: [materials.recipes.silver_block] |
| [materials.items.silver_block] `materials:silver_block` | 14 | рецепт: [materials.recipes.silver_block]; копать: [materials.materials.silver_block] | [block]: [materials.materials.silver_block] |
| [tools.items.hatch] `tools:hatch` | 5 | рецепт: [tools.recipes.hatch] | станок |
| [tools.items.hatch_2x2] `tools:hatch_2x2` | 5 | рецепт: [tools.recipes.hatch_2x2] | станок |
| [tools.items.fur_hat] `tools:fur_hat` | 4 | рецепт: [tools.recipes.fur_hat] | — |
| [tools.items.fur_coat] `tools:fur_coat` | 5 | рецепт: [tools.recipes.fur_coat] | — |
| [tools.items.leather_trousers] `tools:leather_trousers` | 5 | рецепт: [tools.recipes.leather_trousers] | — |
| [tools.items.fur_boots] `tools:fur_boots` | 5 | рецепт: [tools.recipes.fur_boots] | — |
| [tools.items.leather_hat] `tools:leather_hat` | 5 | рецепт: [tools.recipes.leather_hat] | — |
| [tools.items.leather_vest] `tools:leather_vest` | 5 | рецепт: [tools.recipes.leather_vest] | — |
| [tools.items.apron] `tools:apron` | 5 | рецепт: [tools.recipes.apron] | — |
| [tools.items.stone_hoe] `tools:stone_hoe` | 2 | рецепт: [tools.recipes.stone_hoe] | инструмент: [tool.hoe] |
| [tools.items.copper_hoe] `tools:copper_hoe` | 7 | рецепт: [tools.recipes.copper_hoe] | инструмент: [tool.hoe] |
| [tools.items.iron_hoe] `tools:iron_hoe` | 14 | рецепт: [tools.recipes.iron_hoe] | инструмент: [tool.hoe] |
| [tools.items.ice_pick] `tools:ice_pick` | 2 | рецепт: [tools.recipes.ice_pick] | инструмент: [tool.ice] |
| [tools.items.ice_auger] `tools:ice_auger` | 7 | рецепт: [tools.recipes.ice_auger] | инструмент: [tool.ice] |
| [tools.items.winter_rod] `tools:winter_rod` | 2 | рецепт: [tools.recipes.winter_rod] | инструмент: [tool.rod] |
| [tools.items.kiln] `tools:kiln` | 3 | рецепт: [tools.recipes.kiln] | станок рецептов: [tools.recipes.brick], [tools.recipes.charcoal], [plants.recipes.flatbread], [tools.recipes.pot], [materials.recipes.crucible], [materials.recipes.tar] |
| [plants.items.grain] `plants:grain` | 0 | [mow_n2]: [plants.plants.ears], [plants.plants.wheat] | в рецепты: [plants.recipes.flour]; растит: [plants.plants.wheat] |
| [plants.items.flour] `plants:flour` | 1 | рецепт: [plants.recipes.flour] | в рецепты: [plants.recipes.flatbread] |
| [plants.items.flatbread] `plants:flatbread` | 4 | рецепт: [plants.recipes.flatbread] | еда; лечит |
| [tools.items.leather_bag] `tools:leather_bag` | 5 | рецепт: [tools.recipes.leather_bag] | — |
| [tools.items.leather_sling] `tools:leather_sling` | 5 | рецепт: [tools.recipes.leather_sling] | инструмент: [tool.sling] |
| [tools.items.loom] `tools:loom` | 5 | рецепт: [tools.recipes.loom] | станок рецептов: [tools.recipes.cloth_from_cord], [animals.recipes.cloth_from_wool_yarn], [plants.recipes.cloth], [tools.recipes.rug] |
| [animals.items.rabbit_fluff] `animals:rabbit_fluff` | 0 | shear: [animals.creatures.rabbit] | в рецепты: [animals.recipes.wool_yarn] |
| [animals.items.wool_yarn] `animals:wool_yarn` | 1 | рецепт: [animals.recipes.wool_yarn] | в рецепты: [animals.recipes.cloth_from_wool_yarn], [animals.recipes.poncho] |
| [animals.items.poncho] `animals:poncho` | 4 | рецепт: [animals.recipes.poncho] | — |
| [plants.items.flax_seeds] `plants:flax_seeds` | 0 | [mow_n2]: [plants.plants.sown_flax], [plants.plants.flax] | растит: [plants.plants.sown_flax] |
| [plants.items.flax_stalks] `plants:flax_stalks` | 0 | [mow_n2]: [plants.plants.flax], [plants.plants.sown_flax] | в рецепты: [plants.recipes.linen_thread] |
| [plants.items.linen_thread] `plants:linen_thread` | 1 | рецепт: [plants.recipes.linen_thread] | в рецепты: [plants.recipes.cloth] |
| [tools.items.table] `tools:table` | 5 | рецепт: [tools.recipes.table] | станок |
| [tools.items.stool] `tools:stool` | 5 | рецепт: [tools.recipes.stool] | станок |
| [tools.items.wooden_bed] `tools:wooden_bed` | 7 | рецепт: [tools.recipes.wooden_bed] | станок |
| [tools.items.cupboard] `tools:cupboard` | 5 | рецепт: [tools.recipes.cupboard] | хранит вещи: 24 мест |
| [tools.items.wide_cupboard] `tools:wide_cupboard` | 5 | рецепт: [tools.recipes.wide_cupboard] | хранит вещи: 48 мест |
| [tools.items.barrel] `tools:barrel` | 5 | рецепт: [tools.recipes.barrel] | хранит вещи: 8 мест |
| [tools.items.rug] `tools:rug` | 7 | рецепт: [tools.recipes.rug] | станок |
| [tools.items.bone_needle] `tools:bone_needle` | 3 | рецепт: [tools.recipes.bone_needle] | инструмент: [tool.needle] |
| [tools.items.potters_wheel] `tools:potters_wheel` | 5 | рецепт: [tools.recipes.potters_wheel] | станок рецептов: [tools.recipes.raw_pot], [materials.recipes.raw_crucible] |
| [tools.items.raw_pot] `tools:raw_pot` | 6 | рецепт: [tools.recipes.raw_pot] | в рецепты: [tools.recipes.pot] |
| [tools.items.pot] `tools:pot` | 7 | рецепт: [tools.recipes.pot] | нужен в сумке рецептам: [materials.recipes.bone_glue], [materials.recipes.tar], [plants.recipes.primrose_tea], [plants.recipes.roasted_acorns], [plants.recipes.bone_glue_from_sundew], [tools.recipes.waterskin_full_from_pot] |
| [materials.items.bone_glue] `materials:bone_glue` | 8 | рецепт: [materials.recipes.bone_glue], [plants.recipes.bone_glue_from_sundew] | чинит: [tools.items.composite_bow]; в рецепты: [tools.recipes.composite_bow] |
| [materials.items.raw_crucible] `materials:raw_crucible` | 6 | рецепт: [materials.recipes.raw_crucible] | в рецепты: [materials.recipes.crucible] |
| [materials.items.crucible] `materials:crucible` | 7 | рецепт: [materials.recipes.crucible] | нужен в сумке рецептам: [materials.recipes.bronze_bar], [materials.recipes.steel_bar] |
| [materials.items.bronze_bar] `materials:bronze_bar` | 9 | рецепт: [materials.recipes.bronze_bar] | чинит: [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword]; в рецепты: [tools.recipes.bronze_axe], [tools.recipes.bronze_knife], [tools.recipes.bronze_pickaxe], [tools.recipes.bronze_scythe], [tools.recipes.bronze_shovel], [tools.recipes.bronze_spear], [tools.recipes.bronze_sword] |
| [materials.items.steel_bar] `materials:steel_bar` | 13 | рецепт: [materials.recipes.steel_bar] | чинит: [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword]; в рецепты: [tools.recipes.steel_axe], [tools.recipes.steel_knife], [tools.recipes.steel_pickaxe], [tools.recipes.steel_scythe], [tools.recipes.steel_shovel], [tools.recipes.steel_sword] |
| [materials.items.tar] `materials:tar` | 8 | рецепт: [materials.recipes.tar] | в рецепты: [tools.recipes.boat], [tools.recipes.lantern], [tools.recipes.tar_torch]; топливо |
| [plants.items.evening_primrose] `plants:evening_primrose` | 0 | [mow_n2]: [plants.plants.evening_primrose] | в рецепты: [plants.recipes.primrose_tea], [plants.recipes.flower_wreath] |
| [plants.items.primrose_tea] `plants:primrose_tea` | 8 | рецепт: [plants.recipes.primrose_tea] | — |
| [plants.items.flower_wreath] `plants:flower_wreath` | 1 | рецепт: [plants.recipes.flower_wreath] | — |
| [plants.items.roasted_acorns] `plants:roasted_acorns` | 8 | рецепт: [plants.recipes.roasted_acorns] | еда; лечит |
| [plants.items.sundew] `plants:sundew` | 0 | [mow_n2]: [plants.plants.sundew] | в рецепты: [plants.recipes.bone_glue_from_sundew] |
| [tools.items.stone_axe] `tools:stone_axe` | 3 | рецепт: [tools.recipes.stone_axe] | инструмент: [tool.axe] |
| [tools.items.copper_axe] `tools:copper_axe` | 7 | рецепт: [tools.recipes.copper_axe] | инструмент: [tool.axe] |
| [tools.items.bronze_axe] `tools:bronze_axe` | 10 | рецепт: [tools.recipes.bronze_axe] | инструмент: [tool.axe] |
| [tools.items.iron_axe] `tools:iron_axe` | 14 | рецепт: [tools.recipes.iron_axe] | инструмент: [tool.axe] |
| [tools.items.steel_axe] `tools:steel_axe` | 14 | рецепт: [tools.recipes.steel_axe] | инструмент: [tool.axe] |
| [tools.items.raft] `tools:raft` | 4 | рецепт: [tools.recipes.raft] | — |
| [tools.items.boat] `tools:boat` | 9 | рецепт: [tools.recipes.boat] | — |
| [tools.items.oars] `tools:oars` | 5 | рецепт: [tools.recipes.oars] | нужен в сумке рецептам: [tools.items.boat] |
| [tools.items.composite_bow] `tools:composite_bow` | 9 | рецепт: [tools.recipes.composite_bow] | инструмент: [tool.bow] |
| [tools.items.flint_knife] `tools:flint_knife` | 2 | рецепт: [tools.recipes.flint_knife] | инструмент: [tool.knife] |
| [tools.items.copper_knife] `tools:copper_knife` | 7 | рецепт: [tools.recipes.copper_knife] | инструмент: [tool.knife] |
| [tools.items.bronze_knife] `tools:bronze_knife` | 10 | рецепт: [tools.recipes.bronze_knife] | инструмент: [tool.knife] |
| [tools.items.iron_knife] `tools:iron_knife` | 14 | рецепт: [tools.recipes.iron_knife] | инструмент: [tool.knife] |
| [tools.items.steel_knife] `tools:steel_knife` | 14 | рецепт: [tools.recipes.steel_knife] | инструмент: [tool.knife] |
| [tools.items.lantern] `tools:lantern` | 9 | рецепт: [tools.recipes.lantern] | свет |
| [tools.items.stone_pickaxe] `tools:stone_pickaxe` | 3 | рецепт: [tools.recipes.stone_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.wooden_pickaxe] `tools:wooden_pickaxe` | 2 | рецепт: [tools.recipes.wooden_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.copper_pickaxe] `tools:copper_pickaxe` | 7 | рецепт: [tools.recipes.copper_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.bronze_pickaxe] `tools:bronze_pickaxe` | 10 | рецепт: [tools.recipes.bronze_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.iron_pickaxe] `tools:iron_pickaxe` | 14 | рецепт: [tools.recipes.iron_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.steel_pickaxe] `tools:steel_pickaxe` | 14 | рецепт: [tools.recipes.steel_pickaxe] | инструмент: [tool.pickaxe] |
| [tools.items.rain_barrel] `tools:rain_barrel` | 5 | рецепт: [tools.recipes.rain_barrel] | станок |
| [tools.items.rain_catcher] `tools:rain_catcher` | 5 | рецепт: [tools.recipes.rain_catcher] | станок |
| [tools.items.stone_scythe] `tools:stone_scythe` | 3 | рецепт: [tools.recipes.stone_scythe] | инструмент: [tool.scythe] |
| [tools.items.wooden_scythe] `tools:wooden_scythe` | 2 | рецепт: [tools.recipes.wooden_scythe] | инструмент: [tool.scythe] |
| [tools.items.copper_scythe] `tools:copper_scythe` | 7 | рецепт: [tools.recipes.copper_scythe] | инструмент: [tool.scythe] |
| [tools.items.bronze_scythe] `tools:bronze_scythe` | 10 | рецепт: [tools.recipes.bronze_scythe] | инструмент: [tool.scythe] |
| [tools.items.iron_scythe] `tools:iron_scythe` | 14 | рецепт: [tools.recipes.iron_scythe] | инструмент: [tool.scythe] |
| [tools.items.steel_scythe] `tools:steel_scythe` | 14 | рецепт: [tools.recipes.steel_scythe] | инструмент: [tool.scythe] |
| [tools.items.wooden_shovel] `tools:wooden_shovel` | 5 | рецепт: [tools.recipes.wooden_shovel] | инструмент: [tool.shovel] |
| [tools.items.copper_shovel] `tools:copper_shovel` | 7 | рецепт: [tools.recipes.copper_shovel] | инструмент: [tool.shovel] |
| [tools.items.bronze_shovel] `tools:bronze_shovel` | 10 | рецепт: [tools.recipes.bronze_shovel] | инструмент: [tool.shovel] |
| [tools.items.iron_shovel] `tools:iron_shovel` | 14 | рецепт: [tools.recipes.iron_shovel] | инструмент: [tool.shovel] |
| [tools.items.steel_shovel] `tools:steel_shovel` | 14 | рецепт: [tools.recipes.steel_shovel] | инструмент: [tool.shovel] |
| [tools.items.stone_sickle] `tools:stone_sickle` | 2 | рецепт: [tools.recipes.stone_sickle] | инструмент: [tool.sickle] |
| [tools.items.copper_sickle] `tools:copper_sickle` | 7 | рецепт: [tools.recipes.copper_sickle] | инструмент: [tool.sickle] |
| [tools.items.iron_sickle] `tools:iron_sickle` | 14 | рецепт: [tools.recipes.iron_sickle] | инструмент: [tool.sickle] |
| [tools.items.sign] `tools:sign` | 5 | рецепт: [tools.recipes.sign] | станок |
| [tools.items.signpost] `tools:signpost` | 5 | рецепт: [tools.recipes.signpost] | станок |
| [tools.items.notice_board] `tools:notice_board` | 5 | рецепт: [tools.recipes.notice_board] | станок |
| [tools.items.flint_spear] `tools:flint_spear` | 2 | рецепт: [tools.recipes.flint_spear] | инструмент: [tool.spear] |
| [tools.items.bronze_spear] `tools:bronze_spear` | 10 | рецепт: [tools.recipes.bronze_spear] | инструмент: [tool.spear] |
| [tools.items.iron_spear] `tools:iron_spear` | 14 | рецепт: [tools.recipes.iron_spear] | инструмент: [tool.spear] |
| [tools.items.wooden_sword] `tools:wooden_sword` | 2 | рецепт: [tools.recipes.wooden_sword] | инструмент: [tool.sword] |
| [tools.items.stone_sword] `tools:stone_sword` | 3 | рецепт: [tools.recipes.stone_sword] | инструмент: [tool.sword] |
| [tools.items.copper_sword] `tools:copper_sword` | 7 | рецепт: [tools.recipes.copper_sword] | инструмент: [tool.sword] |
| [tools.items.bronze_sword] `tools:bronze_sword` | 10 | рецепт: [tools.recipes.bronze_sword] | инструмент: [tool.sword] |
| [tools.items.iron_sword] `tools:iron_sword` | 14 | рецепт: [tools.recipes.iron_sword] | инструмент: [tool.sword] |
| [tools.items.steel_sword] `tools:steel_sword` | 14 | рецепт: [tools.recipes.steel_sword] | инструмент: [tool.sword] |
| [tools.items.tar_torch] `tools:tar_torch` | 9 | рецепт: [tools.recipes.tar_torch] | свет |
| [tools.items.watering_can] `tools:watering_can` | 5 | рецепт: [tools.recipes.watering_can]; empty: [tools.items.watering_can_full] | — |
| [tools.items.watering_can_full] `tools:watering_can_full` | 5 | fill: [tools.items.watering_can] | инструмент: [tool.can] |
| [tools.items.waterskin] `tools:waterskin` | 5 | рецепт: [tools.recipes.waterskin]; empty: [tools.items.waterskin_full] | — |
| [tools.items.waterskin_full] `tools:waterskin_full` | 5 | fill: [tools.items.waterskin]; рецепт: [tools.recipes.waterskin_full_from_waterskin_sea], [tools.recipes.waterskin_full_from_pot] | — |
| [tools.items.waterskin_sea] `tools:waterskin_sea` | 5 | fill: [tools.items.waterskin] | в рецепты: [tools.recipes.waterskin_full_from_waterskin_sea], [tools.recipes.waterskin_full_from_pot] |
| [tools.items.window] `tools:window` | 7 | рецепт: [tools.recipes.window] | станок |
| [tools.items.window_1x2] `tools:window_1x2` | 7 | рецепт: [tools.recipes.window_1x2] | станок |
| [tools.items.window_2x1] `tools:window_2x1` | 7 | рецепт: [tools.recipes.window_2x1] | станок |
| [tools.items.window_2x2] `tools:window_2x2` | 7 | рецепт: [tools.recipes.window_2x2] | станок |
| [tools.items.window_3x2] `tools:window_3x2` | 7 | рецепт: [tools.recipes.window_3x2] | станок |

## Общие ресурсы

Предметы, которые тратят два рецепта и больше. На нём держится — всё, что делается из него прямо или
дальше по цепочкам (по путям, которые дают глубину), через станки и инструменты тоже.

| Ресурс | Тратят рецепты | На нём держится |
|---|---|---|
| [materials.items.brick] `materials:brick` | [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge] | [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [materials.items.iron_bloom], [materials.items.steel_bar], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.lantern], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore] |
| [materials.items.charcoal] `materials:charcoal` | [tools.recipes.copper_bar], [materials.recipes.glass], [materials.recipes.iron_bloom], [materials.recipes.iron_bar], [materials.recipes.tin_bar], [materials.recipes.gold_bar], [materials.recipes.platinum_bar], [materials.recipes.silver_bar], [materials.recipes.bronze_bar], [materials.recipes.steel_bar] | [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.lantern], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore] |
| [materials.items.cloth] `materials:cloth` | [tools.recipes.bandana], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.canvas_backpack], [tools.recipes.wooden_bed], [tools.recipes.rug], [tools.recipes.tar_torch] | [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [tools.items.wooden_bed], [tools.items.rug], [tools.items.tar_torch] |
| [materials.items.copper_bar] `materials:copper_bar` | [tools.recipes.copper_hoe], [tools.recipes.ice_auger], [materials.recipes.bronze_bar], [tools.recipes.copper_axe], [tools.recipes.copper_knife], [tools.recipes.lantern], [tools.recipes.copper_pickaxe], [tools.recipes.copper_scythe], [tools.recipes.copper_shovel], [tools.recipes.copper_sickle], [tools.recipes.copper_sword] | [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [materials.items.bronze_bar], [tools.items.lantern], [materials.items.tin_ore], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.tin_bar], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [materials.items.steel_bar], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword] |
| [materials.items.planks] `materials:planks` | [tools.recipes.big_chest], [tools.recipes.wooden_bow], [tools.recipes.chest], [tools.recipes.door], [tools.recipes.door_2x2], [tools.recipes.door_2x3], [tools.recipes.door_3x3], [tools.recipes.hatch], [tools.recipes.hatch_2x2], [tools.recipes.copper_hoe], [tools.recipes.iron_hoe], [tools.recipes.ice_auger], [tools.recipes.loom], [tools.recipes.table], [tools.recipes.stool], [tools.recipes.wooden_bed], [tools.recipes.cupboard], [tools.recipes.wide_cupboard], [tools.recipes.barrel], [tools.recipes.potters_wheel], [tools.recipes.copper_axe], [tools.recipes.bronze_axe], [tools.recipes.iron_axe], [tools.recipes.steel_axe], [tools.recipes.boat], [tools.recipes.oars], [tools.recipes.copper_knife], [tools.recipes.bronze_knife], [tools.recipes.iron_knife], [tools.recipes.steel_knife], [tools.recipes.copper_pickaxe], [tools.recipes.bronze_pickaxe], [tools.recipes.iron_pickaxe], [tools.recipes.steel_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.copper_scythe], [tools.recipes.bronze_scythe], [tools.recipes.iron_scythe], [tools.recipes.steel_scythe], [tools.recipes.wooden_shovel], [tools.recipes.copper_shovel], [tools.recipes.bronze_shovel], [tools.recipes.iron_shovel], [tools.recipes.steel_shovel], [tools.recipes.sign], [tools.recipes.signpost], [tools.recipes.notice_board], [tools.recipes.bronze_spear], [tools.recipes.iron_spear], [tools.recipes.copper_sword], [tools.recipes.bronze_sword], [tools.recipes.iron_sword], [tools.recipes.steel_sword], [tools.recipes.watering_can], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2] | [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.loom], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.potters_wheel], [tools.items.oars], [tools.items.rain_barrel], [tools.items.wooden_shovel], [tools.items.sign], [tools.items.signpost], [tools.items.notice_board], [tools.items.watering_can], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.wooden_bed], [tools.items.boat], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [tools.items.watering_can_full], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.composite_bow], [materials.items.cloth], [tools.items.rug], [tools.items.raw_pot], [materials.items.raw_crucible], [materials.items.tin_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [tools.items.tar_torch], [tools.items.pot], [materials.items.crucible], [materials.items.bronze_bar], [materials.items.iron_bar], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [materials.items.bone_glue], [materials.items.tar], [plants.items.primrose_tea], [plants.items.roasted_acorns], [materials.items.steel_bar], [tools.items.anvil], [tools.items.iron_sickle], [tools.items.lantern] |
| [resources.items.fiber] `resources:fiber` | [materials.recipes.cord], [plants.recipes.bandage], [resources.recipes.campfire], [tools.recipes.fiber_hat], [tools.recipes.grass_cape], [tools.recipes.leg_wraps], [tools.recipes.bast_shoes], [tools.recipes.fiber_tunic], [tools.recipes.cord_sling], [tools.recipes.torch], [tools.recipes.wicker_bag], [tools.recipes.arrow], [tools.recipes.grass_mat], [tools.recipes.tallow_candle], [plants.recipes.flower_wreath], [tools.recipes.arrow_from_bone] | [materials.items.cord], [plants.items.bandage], [tools.items.fiber_hat], [plants.items.flower_wreath], [core.items.campfire], [tools.items.grass_cape], [tools.items.leg_wraps], [tools.items.bast_shoes], [tools.items.fiber_tunic], [tools.items.cord_sling], [tools.items.torch], [tools.items.wicker_bag], [tools.items.grass_mat], [tools.items.arrow], [tools.items.tallow_candle], [tools.items.fence], [tools.items.wicket], [tools.items.gate], [tools.items.fishing_rod], [tools.items.ladder], [tools.items.trap], [tools.items.workbench], [tools.items.stone_hoe], [tools.items.ice_pick], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.wooden_sword], [tools.items.drying_rack], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword], [tools.items.fur_bedroll], [tools.items.fur_hat], [tools.items.boundary_post], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.raft], [tools.items.rain_catcher], [tools.items.waterskin], [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.loom], [tools.items.barrel], [tools.items.rain_barrel], [tools.items.watering_can], [materials.items.cloth], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [plants.items.poultice], [animals.items.perch], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [materials.items.copper_ore], [resources.items.crystal], [resources.items.ice], [materials.items.ammonite], [materials.items.geode], [resources.items.log], [tools.items.waterskin_full], [tools.items.waterskin_sea], [tools.items.watering_can_full], [tools.items.composite_bow], [tools.items.bandana], [tools.items.wooden_bed], [tools.items.rug], [tools.items.tar_torch], [animals.items.roasted_fish], [materials.items.cut_stone], [tools.items.kiln], [animals.items.poncho], [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [materials.items.planks], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.potters_wheel], [tools.items.oars], [tools.items.wooden_shovel], [tools.items.notice_board], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.boat], [tools.items.lantern], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.anvil], [animals.items.fat], [tools.items.bone_needle], [materials.items.copper_bar], [animals.items.jerky], [materials.items.leather], [materials.items.log_wall], [materials.items.charcoal], [materials.items.tar], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.sign], [tools.items.signpost], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [materials.items.bronze_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [materials.items.brick], [plants.items.flatbread], [tools.items.pot], [materials.items.crucible], [tools.items.raw_pot], [materials.items.raw_crucible], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.iron_sickle], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| [materials.items.cord] `materials:cord` | [tools.recipes.boundary_post], [tools.recipes.fence], [tools.recipes.wicket], [tools.recipes.gate], [tools.recipes.grass_cape], [tools.recipes.leg_wraps], [tools.recipes.bast_shoes], [tools.recipes.fiber_tunic], [tools.recipes.fishing_rod], [tools.recipes.ladder], [tools.recipes.cord_sling], [tools.recipes.trap], [tools.recipes.wicker_bag], [tools.recipes.workbench], [tools.recipes.big_chest], [tools.recipes.wooden_bow], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.drying_rack], [tools.recipes.grass_mat], [tools.recipes.fur_bedroll], [tools.recipes.canvas_backpack], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.stone_hoe], [tools.recipes.ice_pick], [tools.recipes.winter_rod], [tools.recipes.leather_bag], [tools.recipes.leather_sling], [tools.recipes.loom], [tools.recipes.cloth_from_cord], [tools.recipes.barrel], [tools.recipes.stone_axe], [tools.recipes.raft], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.wooden_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.wooden_scythe], [tools.recipes.stone_sickle], [tools.recipes.flint_spear], [tools.recipes.wooden_sword], [tools.recipes.stone_sword], [tools.recipes.watering_can], [tools.recipes.waterskin] | [tools.items.fence], [tools.items.wicket], [tools.items.gate], [tools.items.grass_cape], [tools.items.leg_wraps], [tools.items.bast_shoes], [tools.items.fiber_tunic], [tools.items.fishing_rod], [tools.items.ladder], [tools.items.cord_sling], [tools.items.trap], [tools.items.wicker_bag], [tools.items.workbench], [tools.items.grass_mat], [tools.items.stone_hoe], [tools.items.ice_pick], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.wooden_sword], [tools.items.drying_rack], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword], [tools.items.fur_bedroll], [tools.items.fur_hat], [tools.items.boundary_post], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.raft], [tools.items.rain_catcher], [tools.items.waterskin], [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.loom], [tools.items.barrel], [tools.items.rain_barrel], [tools.items.watering_can], [materials.items.cloth], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [animals.items.perch], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [materials.items.copper_ore], [resources.items.crystal], [resources.items.ice], [materials.items.ammonite], [materials.items.geode], [resources.items.log], [tools.items.waterskin_full], [tools.items.waterskin_sea], [tools.items.watering_can_full], [tools.items.composite_bow], [tools.items.bandana], [tools.items.wooden_bed], [tools.items.rug], [tools.items.tar_torch], [animals.items.roasted_fish], [materials.items.cut_stone], [tools.items.arrow], [tools.items.kiln], [animals.items.poncho], [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [materials.items.planks], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.potters_wheel], [tools.items.oars], [tools.items.wooden_shovel], [tools.items.notice_board], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.boat], [tools.items.lantern], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.anvil], [animals.items.fat], [tools.items.bone_needle], [materials.items.copper_bar], [animals.items.jerky], [materials.items.leather], [materials.items.log_wall], [materials.items.charcoal], [materials.items.tar], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.sign], [tools.items.signpost], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [tools.items.tallow_candle], [materials.items.bronze_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [materials.items.brick], [plants.items.flatbread], [tools.items.pot], [materials.items.crucible], [tools.items.raw_pot], [materials.items.raw_crucible], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.iron_sickle], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| [plants.items.moss] `plants:moss` | [plants.recipes.bandage], [plants.recipes.poultice] | [plants.items.bandage], [plants.items.poultice] |
| [resources.items.sand] `resources:sand` | [materials.recipes.glass], [materials.recipes.raw_crucible] | [materials.items.glass], [materials.items.raw_crucible], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.lantern], [materials.items.crucible], [materials.items.bronze_bar], [materials.items.steel_bar], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword] |
| [resources.items.clay] `resources:clay` | [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.kiln], [tools.recipes.brick], [tools.recipes.raw_pot], [materials.recipes.raw_crucible] | [tools.items.kiln], [materials.items.brick], [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [tools.items.raw_pot], [materials.items.raw_crucible], [tools.items.pot], [materials.items.crucible], [plants.items.flatbread], [materials.items.charcoal], [materials.items.tar], [materials.items.iron_bloom], [materials.items.steel_bar], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns], [tools.items.boat], [tools.items.lantern], [tools.items.tar_torch], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.composite_bow] |
| [resources.items.stone] `resources:stone` | [tools.recipes.sling_stone], [materials.recipes.cut_stone], [tools.recipes.bloomery], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.ice_pick], [tools.recipes.kiln], [tools.recipes.potters_wheel] | [tools.items.sling_stone], [tools.items.ice_pick], [materials.items.cut_stone], [tools.items.kiln], [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [tools.items.potters_wheel], [materials.items.brick], [plants.items.flatbread], [materials.items.charcoal], [tools.items.pot], [materials.items.crucible], [materials.items.tar], [materials.items.iron_bloom], [materials.items.steel_bar], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [tools.items.raw_pot], [materials.items.raw_crucible], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns], [tools.items.boat], [tools.items.lantern], [tools.items.tar_torch], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.composite_bow] |
| [resources.items.flint] `resources:flint` | [tools.recipes.fishing_rod], [tools.recipes.arrow], [tools.recipes.stone_hoe], [tools.recipes.winter_rod], [tools.recipes.stone_axe], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.stone_scythe], [tools.recipes.stone_sickle], [tools.recipes.flint_spear], [tools.recipes.stone_sword] | [tools.items.fishing_rod], [tools.items.stone_hoe], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.arrow], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword], [animals.items.perch], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [resources.items.log], [animals.items.roasted_fish], [animals.items.fat], [tools.items.bone_needle], [materials.items.log_wall], [materials.items.planks], [tools.items.boundary_post], [materials.items.charcoal], [tools.items.raft], [materials.items.tar], [tools.items.anvil], [materials.items.leather], [tools.items.tallow_candle], [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.loom], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.potters_wheel], [tools.items.oars], [tools.items.rain_barrel], [tools.items.wooden_shovel], [tools.items.sign], [tools.items.signpost], [tools.items.notice_board], [tools.items.watering_can], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.wooden_bed], [tools.items.boat], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [tools.items.lantern], [tools.items.tar_torch], [tools.items.fur_bedroll], [tools.items.fur_hat], [animals.items.poncho], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.waterskin], [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [tools.items.watering_can_full], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.iron_sickle], [tools.items.rain_catcher], [tools.items.composite_bow], [tools.items.waterskin_full], [tools.items.waterskin_sea], [tools.items.copper_sickle], [materials.items.cloth], [tools.items.rug], [tools.items.raw_pot], [materials.items.raw_crucible], [tools.items.pot], [materials.items.crucible], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| [resources.items.branch] `resources:branch` | [resources.recipes.campfire], [animals.recipes.roasted_fish_from_roach], [animals.recipes.roasted_fish_from_pike], [animals.recipes.roasted_fish_from_salmon], [animals.recipes.roasted_fish_from_cod], [animals.recipes.roasted_fish_from_parrotfish], [animals.recipes.roasted_fish_from_catfish], [animals.recipes.roasted_fish_from_perch], [materials.recipes.wattle], [tools.recipes.boundary_post], [tools.recipes.fence], [tools.recipes.wicket], [tools.recipes.gate], [tools.recipes.fishing_rod], [tools.recipes.ladder], [tools.recipes.torch], [tools.recipes.trap], [tools.recipes.workbench], [tools.recipes.arrow], [tools.recipes.drying_rack], [animals.recipes.roasted_meat], [tools.recipes.stone_hoe], [tools.recipes.ice_pick], [tools.recipes.winter_rod], [tools.recipes.loom], [tools.recipes.potters_wheel], [materials.recipes.bone_glue], [plants.recipes.bone_glue_from_sundew], [tools.recipes.stone_axe], [tools.recipes.arrow_from_bone], [tools.recipes.flint_knife], [tools.recipes.stone_pickaxe], [tools.recipes.wooden_pickaxe], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.wooden_scythe], [tools.recipes.wooden_shovel], [tools.recipes.stone_sickle], [tools.recipes.copper_sickle], [tools.recipes.iron_sickle], [tools.recipes.sign], [tools.recipes.signpost], [tools.recipes.flint_spear], [tools.recipes.wooden_sword], [tools.recipes.stone_sword], [tools.recipes.tar_torch] | [core.items.campfire], [materials.items.wattle], [tools.items.fence], [tools.items.wicket], [tools.items.gate], [tools.items.fishing_rod], [tools.items.ladder], [tools.items.torch], [tools.items.trap], [tools.items.workbench], [animals.items.roasted_meat], [tools.items.stone_hoe], [tools.items.ice_pick], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.wooden_sword], [tools.items.arrow], [tools.items.drying_rack], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword], [animals.items.roasted_fish], [tools.items.boundary_post], [tools.items.rain_catcher], [tools.items.loom], [tools.items.potters_wheel], [tools.items.wooden_shovel], [tools.items.sign], [tools.items.signpost], [tools.items.copper_sickle], [materials.items.bone_glue], [tools.items.tar_torch], [tools.items.iron_sickle], [animals.items.perch], [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [materials.items.copper_ore], [resources.items.crystal], [resources.items.ice], [materials.items.ammonite], [materials.items.geode], [resources.items.log], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [tools.items.composite_bow], [materials.items.cut_stone], [tools.items.kiln], [tools.items.fur_hat], [animals.items.poncho], [tools.items.bloomery], [tools.items.fireplace], [tools.items.forge], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [materials.items.planks], [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.oars], [tools.items.rain_barrel], [tools.items.notice_board], [tools.items.watering_can], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.wooden_bed], [tools.items.boat], [tools.items.lantern], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.anvil], [animals.items.fat], [tools.items.bone_needle], [materials.items.copper_bar], [animals.items.jerky], [materials.items.leather], [materials.items.log_wall], [materials.items.charcoal], [tools.items.raft], [materials.items.tar], [materials.items.cloth], [tools.items.rug], [tools.items.raw_pot], [materials.items.raw_crucible], [tools.items.watering_can_full], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [tools.items.tallow_candle], [materials.items.bronze_bar], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.waterskin], [tools.items.canvas_backpack], [materials.items.glass], [materials.items.tin_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [tools.items.pot], [materials.items.crucible], [materials.items.brick], [plants.items.flatbread], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.fur_bedroll], [tools.items.waterskin_full], [tools.items.waterskin_sea], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| [resources.items.log] `resources:log` | [materials.recipes.log_wall], [tools.recipes.boundary_post], [tools.recipes.anvil], [tools.recipes.charcoal], [materials.recipes.tar], [tools.recipes.planks], [tools.recipes.raft] | [materials.items.log_wall], [tools.items.boundary_post], [materials.items.charcoal], [materials.items.planks], [tools.items.raft], [materials.items.tar], [tools.items.anvil], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_bar], [materials.items.bronze_bar], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.steel_bar], [tools.items.big_chest], [tools.items.wooden_bow], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.loom], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.potters_wheel], [tools.items.oars], [tools.items.rain_barrel], [tools.items.wooden_shovel], [tools.items.sign], [tools.items.signpost], [tools.items.notice_board], [tools.items.watering_can], [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sword], [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.wooden_bed], [tools.items.boat], [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.iron_knife], [tools.items.steel_knife], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_sword], [tools.items.lantern], [tools.items.tar_torch], [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush], [tools.items.watering_can_full], [materials.items.tin_ore], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.iron_sickle], [tools.items.copper_sickle], [tools.items.composite_bow], [materials.items.cloth], [tools.items.rug], [tools.items.raw_pot], [materials.items.raw_crucible], [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [tools.items.pot], [materials.items.crucible], [materials.items.bone_glue], [plants.items.primrose_tea], [plants.items.roasted_acorns] |
| [tools.items.bait] `tools:bait` | [tools.items.fishing_rod], [tools.items.winter_rod] | — |
| [tools.items.sling_stone] `tools:sling_stone` | [tools.items.cord_sling], [tools.items.leather_sling] | — |
| [tools.items.arrow] `tools:arrow` | [tools.items.wooden_bow], [tools.items.composite_bow] | — |
| [animals.items.raw_meat] `animals:raw_meat` | [animals.recipes.roasted_meat], [animals.recipes.jerky] | [animals.items.roasted_meat], [animals.items.jerky] |
| [animals.items.hide] `animals:hide` | [materials.recipes.leather], [tools.recipes.fur_bedroll], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.fur_boots] | [materials.items.leather], [tools.items.fur_bedroll], [tools.items.fur_hat], [tools.items.fur_coat], [tools.items.fur_boots], [tools.items.leather_trousers], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.rain_catcher], [tools.items.waterskin], [tools.items.canvas_backpack], [tools.items.composite_bow], [tools.items.waterskin_full], [tools.items.waterskin_sea] |
| [animals.items.bone] `animals:bone` | [tools.recipes.bone_needle], [materials.recipes.bone_glue], [tools.recipes.composite_bow], [tools.recipes.arrow_from_bone] | [tools.items.bone_needle], [materials.items.bone_glue], [tools.items.composite_bow], [tools.items.fur_bedroll], [tools.items.fur_hat], [animals.items.poncho], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.waterskin], [tools.items.bandana], [tools.items.hood], [tools.items.linen_shirt], [tools.items.canvas_backpack], [tools.items.waterskin_full], [tools.items.waterskin_sea] |
| [animals.items.fat] `animals:fat` | [materials.recipes.leather], [tools.recipes.tallow_candle] | [materials.items.leather], [tools.items.tallow_candle], [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.rain_catcher], [tools.items.waterskin], [tools.items.canvas_backpack], [tools.items.composite_bow], [tools.items.waterskin_full], [tools.items.waterskin_sea] |
| [materials.items.leather] `materials:leather` | [tools.recipes.canvas_backpack], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.leather_bag], [tools.recipes.leather_sling], [tools.recipes.composite_bow], [tools.recipes.rain_catcher], [tools.recipes.waterskin] | [tools.items.fur_coat], [tools.items.leather_trousers], [tools.items.fur_boots], [tools.items.leather_hat], [tools.items.leather_vest], [tools.items.apron], [tools.items.leather_bag], [tools.items.leather_sling], [tools.items.rain_catcher], [tools.items.waterskin], [tools.items.canvas_backpack], [tools.items.composite_bow], [tools.items.waterskin_full], [tools.items.waterskin_sea] |
| [materials.items.glass] `materials:glass` | [tools.recipes.lantern], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2] | [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2], [tools.items.lantern] |
| [materials.items.iron_bar] `materials:iron_bar` | [tools.recipes.anvil], [tools.recipes.iron_hoe], [materials.recipes.steel_bar], [tools.recipes.iron_axe], [tools.recipes.iron_knife], [tools.recipes.iron_pickaxe], [tools.recipes.iron_scythe], [tools.recipes.iron_shovel], [tools.recipes.iron_sickle], [tools.recipes.iron_spear], [tools.recipes.iron_sword] | [tools.items.anvil], [materials.items.steel_bar], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block] |
| [animals.items.wool_yarn] `animals:wool_yarn` | [animals.recipes.cloth_from_wool_yarn], [animals.recipes.poncho] | [animals.items.poncho] |
| [materials.items.bronze_bar] `materials:bronze_bar` | [tools.recipes.bronze_axe], [tools.recipes.bronze_knife], [tools.recipes.bronze_pickaxe], [tools.recipes.bronze_scythe], [tools.recipes.bronze_shovel], [tools.recipes.bronze_spear], [tools.recipes.bronze_sword] | [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword], [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.iron_bloom], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar], [materials.items.iron_bar], [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block], [tools.items.anvil], [materials.items.steel_bar], [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword], [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword] |
| [materials.items.steel_bar] `materials:steel_bar` | [tools.recipes.steel_axe], [tools.recipes.steel_knife], [tools.recipes.steel_pickaxe], [tools.recipes.steel_scythe], [tools.recipes.steel_shovel], [tools.recipes.steel_sword] | [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword] |
| [materials.items.tar] `materials:tar` | [tools.recipes.boat], [tools.recipes.lantern], [tools.recipes.tar_torch] | [tools.items.boat], [tools.items.lantern], [tools.items.tar_torch] |
| [plants.items.evening_primrose] `plants:evening_primrose` | [plants.recipes.primrose_tea], [plants.recipes.flower_wreath] | [plants.items.flower_wreath], [plants.items.primrose_tea] |
| [tools.items.waterskin_sea] `tools:waterskin_sea` | [tools.recipes.waterskin_full_from_waterskin_sea], [tools.recipes.waterskin_full_from_pot] | — |

## Инструменты и добыча

Что даёт мир каждым действием и чем это сделать: руками или предметом-инструментом (по правилам `Tools`,
тем же, что в игре). Одинаковое у нескольких записей — одной строкой.

### Клетки

| Что | Действие | Даёт | Чем |
|---|---|---|---|
| [core.materials.dirt] | копать | [resources.items.dirt], [resources.items.flint] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [core.materials.grass] | копать | [resources.items.dirt], [resources.items.fiber] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [core.materials.grass] | [mow_n2] | [core.materials.dirt], [resources.items.fiber] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe] |
| [core.materials.stone] | копать | [resources.items.stone], [materials.items.ammonite], [materials.items.geode] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.brick] | копать | [materials.items.brick] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.copper_ore] | копать | [materials.items.copper_ore] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.cut_stone] | копать | [materials.items.cut_stone] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.gold_block] | копать | [materials.items.gold_block] | [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.gold_ore] | копать | [materials.items.gold_ore] | [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.iron_ore] | копать | [materials.items.iron_ore] | [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.log_wall] | копать | [materials.items.log_wall] | [tools.items.stone_axe], [tools.items.copper_axe], [tools.items.bronze_axe], [tools.items.iron_axe], [tools.items.steel_axe] |
| [materials.materials.planks] | копать | [materials.items.planks] | [tools.items.stone_axe], [tools.items.copper_axe], [tools.items.bronze_axe], [tools.items.iron_axe], [tools.items.steel_axe] |
| [materials.materials.platinum_block] | копать | [materials.items.platinum_block] | [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.platinum_ore] | копать | [materials.items.platinum_ore] | [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.silver_block] | копать | [materials.items.silver_block] | [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.silver_ore] | копать | [materials.items.silver_ore] | [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.tin_ore] | копать | [materials.items.tin_ore] | [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [materials.materials.wattle] | копать | [materials.items.wattle] | руки, [tools.items.fishing_rod], [tools.items.stone_hoe], [tools.items.copper_hoe], [tools.items.iron_hoe], [tools.items.ice_pick], [tools.items.ice_auger], [tools.items.winter_rod], [tools.items.stone_axe], [tools.items.copper_axe], [tools.items.bronze_axe], [tools.items.iron_axe], [tools.items.steel_axe], [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword], [tools.items.watering_can_full] |
| [plants.materials.log] | копать | [resources.items.log] | [tools.items.stone_axe], [tools.items.copper_axe], [tools.items.bronze_axe], [tools.items.iron_axe], [tools.items.steel_axe] |
| [resources.materials.ash], [resources.materials.bed], [resources.materials.bed_wet], [resources.materials.mycelium] | копать | [resources.items.dirt] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.basalt], [resources.materials.deepstone] | копать | [resources.items.stone] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [resources.materials.black_sand] | копать | [resources.items.sand] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.clay] | копать | [resources.items.clay], [materials.items.amber] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.crystal] | копать | [resources.items.crystal] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [resources.materials.ice] | копать | [resources.items.ice] | [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe] |
| [resources.materials.peat] | копать | [resources.items.peat], [materials.items.amber] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.salt] | копать | [resources.items.salt] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.sand] | копать | [resources.items.sand], [resources.items.flint], [materials.items.amber] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.scree] | копать | [resources.items.stone], [resources.items.flint] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [resources.materials.snow] | копать | [resources.items.snow] | руки, [tools.items.stone_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.bronze_pickaxe], [tools.items.iron_pickaxe], [tools.items.steel_pickaxe], [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |

### Деревья

| Что | Действие | Даёт | Чем |
|---|---|---|---|
| [plants.trees.acacia], [plants.trees.apple], [plants.trees.birch], [plants.trees.bird_cherry], [plants.trees.ceiba], [plants.trees.cherry], [plants.trees.deadwood], [plants.trees.fir], [plants.trees.larch], [plants.trees.linden], [plants.trees.mangrove], [plants.trees.maple], [plants.trees.oak], [plants.trees.palm], [plants.trees.pine], [plants.trees.poplar], [plants.trees.red_maple], [plants.trees.rowan], [plants.trees.spruce], [plants.trees.willow] | [chop_n2] | [resources.items.log] | [tools.items.stone_axe], [tools.items.copper_axe], [tools.items.bronze_axe], [tools.items.iron_axe], [tools.items.steel_axe] |
| [plants.trees.acacia], [plants.trees.birch], [plants.trees.bird_cherry], [plants.trees.ceiba], [plants.trees.cherry], [plants.trees.deadwood], [plants.trees.fir], [plants.trees.larch], [plants.trees.linden], [plants.trees.mangrove], [plants.trees.maple], [plants.trees.poplar], [plants.trees.red_maple], [plants.trees.willow] | собирать | [resources.items.branch] | руки |
| [plants.trees.apple] | собирать | [plants.items.apple], [resources.items.branch] | руки |
| [plants.trees.oak] | собирать | [plants.items.acorn], [resources.items.branch] | руки |
| [plants.trees.palm] | собирать | [plants.items.coconut], [resources.items.branch] | руки |
| [plants.trees.pine], [plants.trees.spruce] | собирать | [plants.items.cone], [resources.items.branch] | руки |
| [plants.trees.rowan] | собирать | [plants.items.rowan], [resources.items.branch] | руки |

### [bushes]

| Что | Действие | Даёт | Чем |
|---|---|---|---|
| [plants.bushes.banana] | выкопать | [plants.items.banana_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.banana] | собирать | [plants.items.banana], [resources.items.branch] | руки |
| [plants.bushes.blueberry] | выкопать | [plants.items.blueberry_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.blueberry] | собирать | [plants.items.blueberry], [resources.items.branch] | руки |
| [plants.bushes.currant] | выкопать | [plants.items.currant_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.currant] | собирать | [plants.items.currant], [resources.items.branch] | руки |
| [plants.bushes.juniper] | выкопать | [plants.items.juniper_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.juniper], [plants.bushes.shrub] | собирать | [resources.items.branch] | руки |
| [plants.bushes.raspberry] | выкопать | [plants.items.raspberry_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.raspberry] | собирать | [plants.items.raspberry], [resources.items.branch] | руки |
| [plants.bushes.rosehip] | выкопать | [plants.items.rosehip_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |
| [plants.bushes.rosehip] | собирать | [plants.items.rosehip], [resources.items.branch] | руки |
| [plants.bushes.shrub] | выкопать | [plants.items.shrub_bush] | [tools.items.wooden_shovel], [tools.items.copper_shovel], [tools.items.bronze_shovel], [tools.items.iron_shovel], [tools.items.steel_shovel] |

### [plants]

| Что | Действие | Даёт | Чем |
|---|---|---|---|
| [plants.plants.cactus] | [mow_n2] | [resources.items.fiber], [plants.items.cactus_fruit] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.carrot] | [mow_n2] | [plants.items.carrot], [plants.items.carrot_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.cattail], [plants.plants.clover], [plants.plants.fern], [plants.plants.mimosa], [plants.plants.monstera], [plants.plants.nettle], [plants.plants.reeds], [plants.plants.sedge] | [mow_n2] | [resources.items.fiber] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.cranberry] | [mow_n2] | [plants.items.cranberry] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.ears], [plants.plants.wheat] | [mow_n2] | [plants.items.grain] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.evening_primrose] | [mow_n2] | [plants.items.evening_primrose] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.flax], [plants.plants.sown_flax] | [mow_n2] | [plants.items.flax_stalks], [plants.items.flax_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.flowers] | [mow_n2] | [plants.items.grass_seeds], [plants.items.peas] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.glow_mushrooms] | [mow_n2] | [plants.items.glow_mushroom] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.herbs] | [mow_n2] | [resources.items.fiber], [plants.items.carrot_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.moss] | [mow_n2] | [plants.items.moss] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.mushrooms] | [mow_n2] | [plants.items.mushroom] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.oak_sapling] | [mow_n2] | [plants.items.acorn] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.peas] | [mow_n2] | [plants.items.peas] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.puffball] | [mow_n2] | [plants.items.puffball] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.spruce_sapling] | [mow_n2] | [plants.items.cone] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.sundew] | [mow_n2] | [plants.items.sundew] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.tall_grass] | [mow_n2] | [resources.items.fiber], [plants.items.turnip_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |
| [plants.plants.tuft] | [mow_n2] | [plants.items.grass_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe] |
| [plants.plants.turnip] | [mow_n2] | [plants.items.turnip], [plants.items.turnip_seeds] | руки, [tools.items.stone_scythe], [tools.items.wooden_scythe], [tools.items.copper_scythe], [tools.items.bronze_scythe], [tools.items.iron_scythe], [tools.items.steel_scythe], [tools.items.stone_sickle], [tools.items.copper_sickle], [tools.items.iron_sickle], [tools.items.wooden_sword], [tools.items.stone_sword], [tools.items.copper_sword], [tools.items.bronze_sword], [tools.items.iron_sword], [tools.items.steel_sword] |

## Станки

| Станок | Класс | Глубина | Рецепты | Ещё |
|---|---|---|---|---|
| Руки, без станка | — | 0 | [materials.recipes.cord], [plants.recipes.bandage], [resources.recipes.campfire], [materials.recipes.log_wall], [materials.recipes.wattle], [tools.recipes.boundary_post], [tools.recipes.fence], [tools.recipes.wicket], [tools.recipes.gate], [tools.recipes.fiber_hat], [tools.recipes.grass_cape], [tools.recipes.leg_wraps], [tools.recipes.bast_shoes], [tools.recipes.fiber_tunic], [tools.recipes.fishing_rod], [tools.recipes.bait], [tools.recipes.ladder], [tools.recipes.cord_sling], [tools.recipes.sling_stone], [tools.recipes.torch], [tools.recipes.trap], [tools.recipes.wicker_bag], [tools.recipes.workbench], [animals.recipes.raw_meat_from_small_carcass], [animals.recipes.raw_meat_from_carcass], [tools.recipes.grass_mat], [tools.recipes.fur_bedroll], [tools.recipes.tallow_candle], [tools.recipes.canvas_backpack], [tools.recipes.stone_hoe], [tools.recipes.ice_pick], [tools.recipes.winter_rod], [plants.recipes.flour], [tools.recipes.leather_bag], [tools.recipes.leather_sling], [animals.recipes.wool_yarn], [plants.recipes.linen_thread], [tools.recipes.bone_needle], [plants.recipes.flower_wreath], [tools.recipes.raft], [tools.recipes.flint_knife], [tools.recipes.wooden_pickaxe], [tools.recipes.wooden_scythe], [tools.recipes.stone_sickle], [tools.recipes.sign], [tools.recipes.signpost], [tools.recipes.flint_spear], [tools.recipes.wooden_sword], [tools.recipes.tar_torch], [tools.recipes.waterskin] | — |
| [core.items.campfire] `core:campfire` | `campfire` | 0 | [plants.recipes.fried_mushrooms], [plants.recipes.poultice], [animals.recipes.roasted_fish_from_roach], [animals.recipes.roasted_fish_from_pike], [animals.recipes.roasted_fish_from_salmon], [animals.recipes.roasted_fish_from_cod], [animals.recipes.roasted_fish_from_parrotfish], [animals.recipes.roasted_fish_from_catfish], [animals.recipes.roasted_fish_from_perch], [animals.recipes.roasted_meat], [materials.recipes.bone_glue], [plants.recipes.primrose_tea], [plants.recipes.roasted_acorns], [plants.recipes.bone_glue_from_sundew], [tools.recipes.waterskin_full_from_waterskin_sea], [tools.recipes.waterskin_full_from_pot] | горит: тушится и разжигается топливом |
| [tools.items.workbench] `tools:workbench` | `workbench` | 2 | [materials.recipes.cut_stone], [tools.recipes.big_chest], [tools.recipes.bloomery], [tools.recipes.wooden_bow], [tools.recipes.arrow], [tools.recipes.chest], [tools.recipes.bandana], [tools.recipes.hood], [tools.recipes.linen_shirt], [tools.recipes.door], [tools.recipes.door_2x2], [tools.recipes.door_2x3], [tools.recipes.door_3x3], [tools.recipes.drying_rack], [tools.recipes.fireplace], [tools.recipes.forge], [tools.recipes.anvil], [tools.recipes.hatch], [tools.recipes.hatch_2x2], [tools.recipes.fur_hat], [tools.recipes.fur_coat], [tools.recipes.leather_trousers], [tools.recipes.fur_boots], [tools.recipes.leather_hat], [tools.recipes.leather_vest], [tools.recipes.apron], [tools.recipes.copper_hoe], [tools.recipes.ice_auger], [tools.recipes.kiln], [tools.recipes.loom], [animals.recipes.poncho], [tools.recipes.table], [tools.recipes.stool], [tools.recipes.wooden_bed], [tools.recipes.cupboard], [tools.recipes.wide_cupboard], [tools.recipes.barrel], [tools.recipes.potters_wheel], [tools.recipes.stone_axe], [tools.recipes.planks], [tools.recipes.copper_axe], [tools.recipes.bronze_axe], [tools.recipes.boat], [tools.recipes.oars], [tools.recipes.composite_bow], [tools.recipes.arrow_from_bone], [tools.recipes.copper_knife], [tools.recipes.bronze_knife], [tools.recipes.lantern], [tools.recipes.stone_pickaxe], [tools.recipes.copper_pickaxe], [tools.recipes.bronze_pickaxe], [tools.recipes.rain_barrel], [tools.recipes.rain_catcher], [tools.recipes.stone_scythe], [tools.recipes.copper_scythe], [tools.recipes.bronze_scythe], [tools.recipes.wooden_shovel], [tools.recipes.copper_shovel], [tools.recipes.bronze_shovel], [tools.recipes.copper_sickle], [tools.recipes.notice_board], [tools.recipes.bronze_spear], [tools.recipes.stone_sword], [tools.recipes.copper_sword], [tools.recipes.bronze_sword], [tools.recipes.watering_can], [tools.recipes.window], [tools.recipes.window_1x2], [tools.recipes.window_2x1], [tools.recipes.window_2x2], [tools.recipes.window_3x2] | здесь чинят инструменты |
| [tools.items.bloomery] `tools:bloomery` | `bloomery` | 5 | [materials.recipes.iron_bloom], [materials.recipes.steel_bar] | — |
| [tools.items.drying_rack] `tools:drying_rack` | `drying_rack` | 3 | [animals.recipes.jerky], [materials.recipes.leather] | — |
| [tools.items.fireplace] `tools:fireplace` | `fireplace` | 5 | — | горит: тушится и разжигается топливом; заменяет: [core.items.campfire] |
| [tools.items.forge] `tools:forge` | `forge` | 5 | [tools.recipes.copper_bar], [materials.recipes.glass], [materials.recipes.iron_bar], [materials.recipes.tin_bar], [materials.recipes.gold_bar], [materials.recipes.platinum_bar], [materials.recipes.silver_bar], [materials.recipes.bronze_bar] | — |
| [tools.items.anvil] `tools:anvil` | `anvil` | 13 | [materials.recipes.gold_block], [materials.recipes.platinum_block], [materials.recipes.silver_block], [tools.recipes.iron_hoe], [tools.recipes.iron_axe], [tools.recipes.steel_axe], [tools.recipes.iron_knife], [tools.recipes.steel_knife], [tools.recipes.iron_pickaxe], [tools.recipes.steel_pickaxe], [tools.recipes.iron_scythe], [tools.recipes.steel_scythe], [tools.recipes.iron_shovel], [tools.recipes.steel_shovel], [tools.recipes.iron_sickle], [tools.recipes.iron_spear], [tools.recipes.iron_sword], [tools.recipes.steel_sword] | — |
| [tools.items.kiln] `tools:kiln` | `kiln` | 3 | [tools.recipes.brick], [tools.recipes.charcoal], [plants.recipes.flatbread], [tools.recipes.pot], [materials.recipes.crucible], [materials.recipes.tar] | — |
| [tools.items.loom] `tools:loom` | `loom` | 5 | [tools.recipes.cloth_from_cord], [animals.recipes.cloth_from_wool_yarn], [plants.recipes.cloth], [tools.recipes.rug] | — |
| [tools.items.potters_wheel] `tools:potters_wheel` | `potters_wheel` | 5 | [tools.recipes.raw_pot], [materials.recipes.raw_crucible] | — |
| [tools.items.rain_barrel] `tools:rain_barrel` | `rain_barrel` | 5 | — | — |
| [tools.items.rain_catcher] `tools:rain_catcher` | `rain_catcher` | 5 | — | — |

## Цепочки

Из чего складывается каждое изделие по путям, которые дают ему глубину: сырьё — что даёт мир и старт,
промежуточное — изделия по дороге, станки и инструменты — те, без которых на этом пути не обойтись.

| Изделие | Глубина | Сырьё | Промежуточное | Станки | Инструменты |
|---|---|---|---|---|---|
| [animals.items.bone] `animals:bone` | 1 | [animals.items.small_carcass] | — | — | — |
| [animals.items.hide] `animals:hide` | 1 | [animals.items.small_carcass] | — | — | — |
| [animals.items.raw_meat] `animals:raw_meat` | 1 | [animals.items.small_carcass] | — | — | — |
| [animals.items.wool_yarn] `animals:wool_yarn` | 1 | [animals.items.rabbit_fluff] | — | — | — |
| [core.items.campfire] `core:campfire` | 1 | [resources.items.branch], [resources.items.fiber] | — | — | — |
| [materials.items.cord] `materials:cord` | 1 | [resources.items.fiber] | — | — | — |
| [materials.items.wattle] `materials:wattle` | 1 | [resources.items.branch] | — | — | — |
| [plants.items.bandage] `plants:bandage` | 1 | [plants.items.moss], [resources.items.fiber] | — | — | — |
| [plants.items.flour] `plants:flour` | 1 | [plants.items.grain] | — | — | — |
| [plants.items.flower_wreath] `plants:flower_wreath` | 1 | [plants.items.evening_primrose], [resources.items.fiber] | — | — | — |
| [plants.items.fried_mushrooms] `plants:fried_mushrooms` | 1 | [plants.items.mushroom] | — | — | — |
| [plants.items.linen_thread] `plants:linen_thread` | 1 | [plants.items.flax_stalks] | — | — | — |
| [tools.items.bait] `tools:bait` | 1 | [resources.items.dirt] | — | — | — |
| [tools.items.fiber_hat] `tools:fiber_hat` | 1 | [resources.items.fiber] | — | — | — |
| [tools.items.sling_stone] `tools:sling_stone` | 1 | [resources.items.stone] | — | — | — |
| [tools.items.torch] `tools:torch` | 1 | [resources.items.branch], [resources.items.fiber] | — | — | — |
| [animals.items.roasted_meat] `animals:roasted_meat` | 2 | [resources.items.branch], [animals.items.small_carcass] | [animals.items.raw_meat] | — | — |
| [plants.items.poultice] `plants:poultice` | 2 | [plants.items.moss], [resources.items.fiber] | [plants.items.bandage] | — | — |
| [tools.items.bast_shoes] `tools:bast_shoes` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.cord_sling] `tools:cord_sling` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.fence] `tools:fence` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.fiber_tunic] `tools:fiber_tunic` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.fishing_rod] `tools:fishing_rod` | 2 | [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.flint_knife] `tools:flint_knife` | 2 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.flint_spear] `tools:flint_spear` | 2 | [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.gate] `tools:gate` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.grass_cape] `tools:grass_cape` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.grass_mat] `tools:grass_mat` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.ice_pick] `tools:ice_pick` | 2 | [resources.items.branch], [resources.items.stone], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.ladder] `tools:ladder` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.leg_wraps] `tools:leg_wraps` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.stone_hoe] `tools:stone_hoe` | 2 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.stone_sickle] `tools:stone_sickle` | 2 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.trap] `tools:trap` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.wicker_bag] `tools:wicker_bag` | 2 | [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.wicket] `tools:wicket` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.winter_rod] `tools:winter_rod` | 2 | [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.wooden_pickaxe] `tools:wooden_pickaxe` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.wooden_scythe] `tools:wooden_scythe` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.wooden_sword] `tools:wooden_sword` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [tools.items.workbench] `tools:workbench` | 2 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | — |
| [animals.items.fat] `animals:fat` | 3 | [animals.items.carcass], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | — | [tools.items.flint_knife] |
| [animals.items.roasted_fish] `animals:roasted_fish` | 3 | [animals.items.roach], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.cord] | — | [tools.items.fishing_rod] |
| [materials.items.cut_stone] `materials:cut_stone` | 3 | [resources.items.stone], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | [tools.items.wooden_pickaxe] |
| [tools.items.arrow] `tools:arrow` | 3 | [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.bone_needle] `tools:bone_needle` | 3 | [animals.items.small_carcass], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [animals.items.bone], [materials.items.cord] | — | [tools.items.flint_knife] |
| [tools.items.drying_rack] `tools:drying_rack` | 3 | [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.kiln] `tools:kiln` | 3 | [resources.items.stone], [resources.items.clay], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.stone_axe] `tools:stone_axe` | 3 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.stone_pickaxe] `tools:stone_pickaxe` | 3 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.stone_scythe] `tools:stone_scythe` | 3 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [tools.items.stone_sword] `tools:stone_sword` | 3 | [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | — |
| [animals.items.jerky] `animals:jerky` | 4 | [animals.items.small_carcass], [resources.items.branch], [resources.items.fiber] | [animals.items.raw_meat], [materials.items.cord] | [tools.items.drying_rack], [tools.items.workbench] | — |
| [animals.items.poncho] `animals:poncho` | 4 | [animals.items.rabbit_fluff], [resources.items.branch], [resources.items.fiber], [animals.items.small_carcass], [resources.items.flint] | [animals.items.wool_yarn], [materials.items.cord], [animals.items.bone] | [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [materials.items.brick] `materials:brick` | 4 | [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.kiln], [tools.items.workbench] | — |
| [materials.items.charcoal] `materials:charcoal` | 4 | [resources.items.log], [resources.items.flint], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.cord] | [tools.items.kiln], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.leather] `materials:leather` | 4 | [animals.items.small_carcass], [animals.items.carcass], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [animals.items.hide], [animals.items.fat], [materials.items.cord] | [tools.items.drying_rack], [tools.items.workbench] | [tools.items.flint_knife] |
| [materials.items.log_wall] `materials:log_wall` | 4 | [resources.items.log], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.planks] `materials:planks` | 4 | [resources.items.log], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [plants.items.flatbread] `plants:flatbread` | 4 | [plants.items.grain], [resources.items.stone], [resources.items.clay], [resources.items.branch], [resources.items.fiber] | [plants.items.flour], [materials.items.cord] | [tools.items.kiln], [tools.items.workbench] | — |
| [tools.items.boundary_post] `tools:boundary_post` | 4 | [resources.items.log], [resources.items.branch], [resources.items.fiber], [resources.items.flint] | [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.fur_bedroll] `tools:fur_bedroll` | 4 | [animals.items.small_carcass], [resources.items.fiber], [resources.items.flint], [resources.items.branch] | [animals.items.hide], [materials.items.cord], [animals.items.bone] | — | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.fur_hat] `tools:fur_hat` | 4 | [animals.items.small_carcass], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [animals.items.hide], [materials.items.cord], [animals.items.bone] | [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.raft] `tools:raft` | 4 | [resources.items.log], [resources.items.fiber], [resources.items.flint], [resources.items.branch] | [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.tallow_candle] `tools:tallow_candle` | 4 | [resources.items.fiber], [animals.items.carcass], [resources.items.flint], [resources.items.branch] | [animals.items.fat], [materials.items.cord] | — | [tools.items.flint_knife] |
| [tools.items.apron] `tools:apron` | 5 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [animals.items.carcass], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.barrel] `tools:barrel` | 5 | [resources.items.log], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.big_chest] `tools:big_chest` | 5 | [resources.items.log], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.bloomery] `tools:bloomery` | 5 | [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.fiber] | [materials.items.brick], [materials.items.cord] | [tools.items.workbench], [tools.items.kiln] | — |
| [tools.items.chest] `tools:chest` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.cupboard] `tools:cupboard` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.door] `tools:door` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.door_2x2] `tools:door_2x2` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.door_2x3] `tools:door_2x3` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.door_3x3] `tools:door_3x3` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.fireplace] `tools:fireplace` | 5 | [resources.items.stone], [resources.items.clay], [resources.items.branch], [resources.items.fiber] | [materials.items.brick], [materials.items.cord] | [tools.items.workbench], [tools.items.kiln] | — |
| [tools.items.forge] `tools:forge` | 5 | [resources.items.stone], [resources.items.clay], [resources.items.branch], [resources.items.fiber] | [materials.items.brick], [materials.items.cord] | [tools.items.workbench], [tools.items.kiln] | — |
| [tools.items.fur_boots] `tools:fur_boots` | 5 | [animals.items.small_carcass], [resources.items.fiber], [resources.items.branch], [animals.items.carcass], [resources.items.flint] | [animals.items.hide], [materials.items.leather], [materials.items.cord], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.fur_coat] `tools:fur_coat` | 5 | [animals.items.small_carcass], [resources.items.fiber], [resources.items.branch], [animals.items.carcass], [resources.items.flint] | [animals.items.hide], [materials.items.leather], [materials.items.cord], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.hatch] `tools:hatch` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.hatch_2x2] `tools:hatch_2x2` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.leather_bag] `tools:leather_bag` | 5 | [resources.items.fiber], [animals.items.small_carcass], [animals.items.carcass], [resources.items.branch], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.drying_rack], [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.leather_hat] `tools:leather_hat` | 5 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [animals.items.carcass], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.leather_sling] `tools:leather_sling` | 5 | [resources.items.fiber], [animals.items.small_carcass], [animals.items.carcass], [resources.items.branch], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.drying_rack], [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.leather_trousers] `tools:leather_trousers` | 5 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [animals.items.carcass], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.leather_vest] `tools:leather_vest` | 5 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [animals.items.carcass], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.loom] `tools:loom` | 5 | [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.notice_board] `tools:notice_board` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.oars] `tools:oars` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.potters_wheel] `tools:potters_wheel` | 5 | [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.rain_barrel] `tools:rain_barrel` | 5 | [resources.items.log], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.rain_catcher] `tools:rain_catcher` | 5 | [resources.items.branch], [resources.items.fiber], [animals.items.small_carcass], [animals.items.carcass], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat] | [tools.items.workbench], [tools.items.drying_rack] | [tools.items.flint_knife] |
| [tools.items.sign] `tools:sign` | 5 | [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.signpost] `tools:signpost` | 5 | [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.stool] `tools:stool` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.table] `tools:table` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.watering_can] `tools:watering_can` | 5 | [resources.items.log], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.waterskin] `tools:waterskin` | 5 | [resources.items.fiber], [animals.items.small_carcass], [animals.items.carcass], [resources.items.branch], [resources.items.flint] | [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone] | [tools.items.drying_rack], [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife] |
| [tools.items.wide_cupboard] `tools:wide_cupboard` | 5 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.wooden_bow] `tools:wooden_bow` | 5 | [resources.items.log], [resources.items.fiber], [resources.items.branch], [resources.items.flint] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.wooden_shovel] `tools:wooden_shovel` | 5 | [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.cloth] `materials:cloth` | 6 | [resources.items.fiber], [resources.items.branch], [resources.items.log], [resources.items.flint] | [materials.items.cord], [materials.items.planks] | [tools.items.loom], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.copper_bar] `materials:copper_bar` | 6 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.fiber], [resources.items.flint] | [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [materials.items.glass] `materials:glass` | 6 | [resources.items.sand], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.charcoal], [materials.items.brick], [materials.items.cord] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.raw_crucible] `materials:raw_crucible` | 6 | [resources.items.clay], [resources.items.sand], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.raw_pot] `tools:raw_pot` | 6 | [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.flint], [resources.items.fiber] | [materials.items.planks], [materials.items.cord] | [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.crucible] `materials:crucible` | 7 | [resources.items.clay], [resources.items.sand], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [materials.items.raw_crucible], [materials.items.planks], [materials.items.cord] | [tools.items.kiln], [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.bandana] `tools:bandana` | 7 | [resources.items.branch], [resources.items.fiber], [animals.items.small_carcass], [resources.items.flint], [resources.items.log] | [materials.items.cloth], [materials.items.cord], [animals.items.bone], [materials.items.planks] | [tools.items.workbench], [tools.items.loom] | [tools.items.bone_needle], [tools.items.flint_knife], [tools.items.stone_axe] |
| [tools.items.canvas_backpack] `tools:canvas_backpack` | 7 | [resources.items.fiber], [animals.items.small_carcass], [animals.items.carcass], [resources.items.branch], [resources.items.flint], [resources.items.log] | [materials.items.cloth], [materials.items.leather], [materials.items.cord], [animals.items.hide], [animals.items.fat], [animals.items.bone], [materials.items.planks] | [tools.items.loom], [tools.items.drying_rack], [tools.items.workbench] | [tools.items.bone_needle], [tools.items.flint_knife], [tools.items.stone_axe] |
| [tools.items.copper_axe] `tools:copper_axe` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_hoe] `tools:copper_hoe` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_knife] `tools:copper_knife` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_pickaxe] `tools:copper_pickaxe` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_scythe] `tools:copper_scythe` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_shovel] `tools:copper_shovel` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_sickle] `tools:copper_sickle` | 7 | [resources.items.branch], [materials.items.copper_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.fiber], [resources.items.flint] | [materials.items.copper_bar], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.copper_sword] `tools:copper_sword` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.hood] `tools:hood` | 7 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [resources.items.flint], [resources.items.log] | [materials.items.cloth], [materials.items.cord], [animals.items.bone], [materials.items.planks] | [tools.items.workbench], [tools.items.loom] | [tools.items.bone_needle], [tools.items.flint_knife], [tools.items.stone_axe] |
| [tools.items.ice_auger] `tools:ice_auger` | 7 | [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.planks], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.linen_shirt] `tools:linen_shirt` | 7 | [resources.items.fiber], [resources.items.branch], [animals.items.small_carcass], [resources.items.flint], [resources.items.log] | [materials.items.cloth], [materials.items.cord], [animals.items.bone], [materials.items.planks] | [tools.items.workbench], [tools.items.loom] | [tools.items.bone_needle], [tools.items.flint_knife], [tools.items.stone_axe] |
| [tools.items.pot] `tools:pot` | 7 | [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [tools.items.raw_pot], [materials.items.planks], [materials.items.cord] | [tools.items.kiln], [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.rug] `tools:rug` | 7 | [resources.items.branch], [resources.items.fiber], [resources.items.log], [resources.items.flint] | [materials.items.cloth], [materials.items.cord], [materials.items.planks] | [tools.items.loom], [tools.items.workbench] | [tools.items.stone_axe] |
| [tools.items.window] `tools:window` | 7 | [resources.items.log], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.glass], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.stone_axe] |
| [tools.items.window_1x2] `tools:window_1x2` | 7 | [resources.items.log], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.glass], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.stone_axe] |
| [tools.items.window_2x1] `tools:window_2x1` | 7 | [resources.items.log], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.glass], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.stone_axe] |
| [tools.items.window_2x2] `tools:window_2x2` | 7 | [resources.items.log], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.glass], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.stone_axe] |
| [tools.items.window_3x2] `tools:window_3x2` | 7 | [resources.items.log], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.glass], [materials.items.charcoal], [materials.items.cord], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln] | [tools.items.stone_axe] |
| [tools.items.wooden_bed] `tools:wooden_bed` | 7 | [resources.items.log], [resources.items.branch], [resources.items.fiber], [resources.items.flint] | [materials.items.planks], [materials.items.cloth], [materials.items.cord] | [tools.items.workbench], [tools.items.loom] | [tools.items.stone_axe] |
| [materials.items.bone_glue] `materials:bone_glue` | 8 | [resources.items.branch], [animals.items.small_carcass], [resources.items.clay], [resources.items.stone], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [animals.items.bone], [tools.items.pot], [tools.items.raw_pot], [materials.items.planks], [materials.items.cord] | [tools.items.kiln], [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.tar] `materials:tar` | 8 | [resources.items.log], [resources.items.flint], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [tools.items.pot], [tools.items.raw_pot], [materials.items.cord], [materials.items.planks] | [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.stone_axe] |
| [materials.items.tin_bar] `materials:tin_bar` | 8 | [materials.items.tin_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [materials.items.copper_ore], [resources.items.flint], [resources.items.branch], [resources.items.fiber] | [materials.items.charcoal], [materials.items.copper_bar], [materials.items.planks], [materials.items.brick], [materials.items.cord] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench] | [tools.items.copper_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe] |
| [plants.items.primrose_tea] `plants:primrose_tea` | 8 | [plants.items.evening_primrose], [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [tools.items.pot], [tools.items.raw_pot], [materials.items.planks], [materials.items.cord] | [tools.items.kiln], [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [plants.items.roasted_acorns] `plants:roasted_acorns` | 8 | [plants.items.acorn], [resources.items.clay], [resources.items.stone], [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint] | [tools.items.pot], [tools.items.raw_pot], [materials.items.planks], [materials.items.cord] | [tools.items.kiln], [tools.items.potters_wheel], [tools.items.workbench] | [tools.items.stone_axe] |
| [materials.items.bronze_bar] `materials:bronze_bar` | 9 | [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.sand], [resources.items.branch], [resources.items.flint], [resources.items.fiber] | [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.planks] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe], [tools.items.stone_axe] |
| [tools.items.boat] `tools:boat` | 9 | [resources.items.log], [resources.items.branch], [resources.items.flint], [resources.items.stone], [resources.items.clay], [resources.items.fiber] | [materials.items.planks], [materials.items.tar], [tools.items.pot], [materials.items.cord], [tools.items.raw_pot] | [tools.items.workbench], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe] |
| [tools.items.composite_bow] `tools:composite_bow` | 9 | [animals.items.small_carcass], [resources.items.branch], [resources.items.log], [resources.items.fiber], [animals.items.carcass], [resources.items.clay], [resources.items.flint], [resources.items.stone] | [animals.items.bone], [materials.items.bone_glue], [materials.items.leather], [materials.items.planks], [materials.items.cord], [tools.items.pot], [animals.items.hide], [animals.items.fat], [tools.items.raw_pot] | [tools.items.workbench], [tools.items.drying_rack], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.wooden_bow], [tools.items.stone_axe], [tools.items.flint_knife] |
| [tools.items.lantern] `tools:lantern` | 9 | [resources.items.sand], [materials.items.copper_ore], [resources.items.log], [resources.items.branch], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber] | [materials.items.glass], [materials.items.copper_bar], [materials.items.tar], [materials.items.charcoal], [tools.items.pot], [materials.items.cord], [tools.items.raw_pot], [materials.items.brick], [materials.items.planks] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.wooden_pickaxe], [tools.items.stone_axe] |
| [tools.items.tar_torch] `tools:tar_torch` | 9 | [resources.items.branch], [resources.items.log], [resources.items.fiber], [resources.items.flint], [resources.items.stone], [resources.items.clay] | [materials.items.cloth], [materials.items.tar], [materials.items.cord], [tools.items.pot], [tools.items.raw_pot], [materials.items.planks] | [tools.items.loom], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.stone_axe] |
| [tools.items.bronze_axe] `tools:bronze_axe` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_knife] `tools:bronze_knife` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_pickaxe] `tools:bronze_pickaxe` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_scythe] `tools:bronze_scythe` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_shovel] `tools:bronze_shovel` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_spear] `tools:bronze_spear` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.bronze_sword] `tools:bronze_sword` | 10 | [resources.items.log], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [resources.items.sand] | [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible], [materials.items.brick] | [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.gold_bar] `materials:gold_bar` | 11 | [materials.items.gold_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.fiber], [resources.items.sand] | [materials.items.charcoal], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.iron_bloom] `materials:iron_bloom` | 11 | [materials.items.iron_ore], [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.fiber], [resources.items.sand] | [materials.items.charcoal], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible] | [tools.items.bloomery], [tools.items.kiln], [tools.items.workbench], [tools.items.forge], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.platinum_bar] `materials:platinum_bar` | 11 | [materials.items.platinum_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.fiber], [resources.items.sand] | [materials.items.charcoal], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.silver_bar] `materials:silver_bar` | 11 | [materials.items.silver_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.fiber], [resources.items.sand] | [materials.items.charcoal], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.cord], [materials.items.raw_crucible] | [tools.items.forge], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.iron_bar] `materials:iron_bar` | 12 | [materials.items.iron_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.bronze_bar], [materials.items.planks], [materials.items.cord], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.forge], [tools.items.bloomery], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.steel_bar] `materials:steel_bar` | 13 | [resources.items.log], [resources.items.clay], [resources.items.stone], [materials.items.iron_ore], [resources.items.sand], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.bloomery], [tools.items.forge], [tools.items.kiln], [tools.items.workbench], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.anvil] `tools:anvil` | 13 | [resources.items.log], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.cord], [materials.items.brick], [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.workbench], [tools.items.forge], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.gold_block] `materials:gold_block` | 14 | [materials.items.gold_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.gold_bar], [materials.items.charcoal], [materials.items.iron_bar], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.iron_bloom], [materials.items.cord], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.kiln], [tools.items.bloomery], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.platinum_block] `materials:platinum_block` | 14 | [materials.items.platinum_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.platinum_bar], [materials.items.charcoal], [materials.items.iron_bar], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.iron_bloom], [materials.items.cord], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.kiln], [tools.items.bloomery], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [materials.items.silver_block] `materials:silver_block` | 14 | [materials.items.silver_ore], [resources.items.log], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.silver_bar], [materials.items.charcoal], [materials.items.iron_bar], [materials.items.bronze_bar], [materials.items.planks], [materials.items.brick], [materials.items.iron_bloom], [materials.items.cord], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.kiln], [tools.items.bloomery], [tools.items.potters_wheel] | [tools.items.bronze_pickaxe], [tools.items.stone_axe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_axe] `tools:iron_axe` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_hoe] `tools:iron_hoe` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_knife] `tools:iron_knife` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_pickaxe] `tools:iron_pickaxe` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_scythe] `tools:iron_scythe` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_shovel] `tools:iron_shovel` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_sickle] `tools:iron_sickle` | 14 | [resources.items.branch], [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.planks], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_spear] `tools:iron_spear` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.iron_sword] `tools:iron_sword` | 14 | [resources.items.log], [materials.items.iron_ore], [resources.items.stone], [resources.items.clay], [resources.items.flint], [resources.items.branch], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore], [resources.items.sand] | [materials.items.iron_bar], [materials.items.planks], [materials.items.iron_bloom], [materials.items.charcoal], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar], [materials.items.crucible], [materials.items.raw_crucible] | [tools.items.anvil], [tools.items.forge], [tools.items.workbench], [tools.items.bloomery], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_axe] `tools:steel_axe` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_knife] `tools:steel_knife` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_pickaxe] `tools:steel_pickaxe` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_scythe] `tools:steel_scythe` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_shovel] `tools:steel_shovel` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |
| [tools.items.steel_sword] `tools:steel_sword` | 14 | [resources.items.log], [resources.items.clay], [resources.items.stone], [resources.items.flint], [resources.items.branch], [materials.items.iron_ore], [resources.items.sand], [resources.items.fiber], [materials.items.copper_ore], [materials.items.tin_ore] | [materials.items.steel_bar], [materials.items.planks], [materials.items.iron_bar], [materials.items.charcoal], [materials.items.crucible], [materials.items.iron_bloom], [materials.items.raw_crucible], [materials.items.brick], [materials.items.cord], [materials.items.bronze_bar], [materials.items.copper_bar], [materials.items.tin_bar] | [tools.items.anvil], [tools.items.bloomery], [tools.items.workbench], [tools.items.forge], [tools.items.kiln], [tools.items.potters_wheel] | [tools.items.stone_axe], [tools.items.bronze_pickaxe], [tools.items.wooden_pickaxe], [tools.items.copper_pickaxe] |

## Карта эпох

Эпоха — ступень прогресса (`core/data/eras.yaml`, раздел 9 [BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md));
в игре она ничего не запрещает. Эпоха вещи — самая ранняя, в которой её можно получить: изделие — самая
поздняя эпоха того, что требует рецепт (материалы, вещь в сумке, станок, инструменты), добытое — эпоха
самого раннего инструмента, который это может, поставленное по старту — первая; но не раньше эпохи,
записанной у предмета (`era`). Жирным — предметы, у которых эпоха записана: они открывают ступень. В
каждой эпохе вещи по видам, от меньшей глубины к большей.

### 0. [core.eras.foraging] `core:foraging`

[core.eras.foraging.about] Цепочки — до 2 шагов от старта.

- [stations]: [core.items.grave], [materials.items.amber], [tools.items.stairs].
- [clothes_and_bags]: [tools.items.fiber_hat], [plants.items.flower_wreath].
- [materials]: [core.items.rot], [resources.items.fiber], [plants.items.moss], [resources.items.flint], [resources.items.branch], [animals.items.small_carcass], [animals.items.carcass], [animals.items.rabbit_fluff], [plants.items.flax_stalks], [plants.items.evening_primrose], [plants.items.sundew], [tools.items.bait], [tools.items.sling_stone], [animals.items.hide], [animals.items.bone], [plants.items.flour], [animals.items.wool_yarn], [plants.items.linen_thread].
- [blocks]: [resources.items.peat], [resources.items.salt], [resources.items.snow], [resources.items.dirt], [resources.items.sand], [resources.items.clay], [resources.items.stone], [materials.items.wattle].
- [food]: [plants.items.blueberry], [plants.items.cactus_fruit], [plants.items.cranberry], [plants.items.currant], [plants.items.carrot], [plants.items.mushroom], [plants.items.glow_mushroom], [plants.items.peas], [plants.items.puffball], [plants.items.raspberry], [plants.items.rosehip], [plants.items.turnip], [plants.items.apple], [plants.items.banana], [plants.items.coconut], [plants.items.rowan], [plants.items.fried_mushrooms], [animals.items.raw_meat], [animals.items.roasted_meat].
- [healing]: [plants.items.bandage], [plants.items.poultice].
- [planting]: [plants.items.grass_seeds], [plants.items.carrot_seeds], [plants.items.turnip_seeds], [plants.items.acorn], [plants.items.cone], [plants.items.grain], [plants.items.flax_seeds].

### 1. [core.eras.primitive] `core:primitive`

[core.eras.primitive.about] Цепочки — до 6 шагов от старта.

- [stations]: **[core.items.campfire]**, [materials.items.ammonite], [materials.items.geode], **[tools.items.fence]**, **[tools.items.wicket]**, **[tools.items.gate]**, **[tools.items.ladder]**, **[tools.items.trap]**, **[tools.items.workbench]**, [tools.items.grass_mat], **[tools.items.boundary_post]**, [tools.items.big_chest], [tools.items.chest], [tools.items.door], [tools.items.door_2x2], [tools.items.door_2x3], [tools.items.door_3x3], [tools.items.hatch], [tools.items.hatch_2x2], [tools.items.table], [tools.items.stool], [tools.items.cupboard], [tools.items.wide_cupboard], [tools.items.barrel], [tools.items.potters_wheel], [tools.items.rain_barrel], [tools.items.sign], [tools.items.signpost], [tools.items.notice_board].
- [tools]: [tools.items.fishing_rod], [tools.items.cord_sling], [tools.items.stone_hoe], [tools.items.ice_pick], [tools.items.winter_rod], [tools.items.flint_knife], [tools.items.wooden_pickaxe], [tools.items.wooden_scythe], [tools.items.stone_sickle], [tools.items.flint_spear], [tools.items.wooden_sword], [tools.items.bone_needle], [tools.items.stone_axe], [tools.items.stone_pickaxe], [tools.items.stone_scythe], [tools.items.stone_sword], [tools.items.wooden_bow], [tools.items.wooden_shovel], [tools.items.watering_can_full].
- [light]: **[tools.items.torch]**, [tools.items.tallow_candle].
- [clothes_and_bags]: [tools.items.grass_cape], [tools.items.leg_wraps], [tools.items.bast_shoes], [tools.items.fiber_tunic], [tools.items.wicker_bag].
- [materials]: **[tools.items.live_rabbit]**, **[materials.items.cord]**, [tools.items.arrow], [animals.items.fat], **[tools.items.raft]**, **[tools.items.oars]**, [tools.items.watering_can], [tools.items.raw_pot], [materials.items.raw_crucible].
- [blocks]: [resources.items.crystal], [resources.items.ice], [resources.items.log], [materials.items.cut_stone], [materials.items.planks], [materials.items.log_wall].
- [food]: [animals.items.roach], [animals.items.pike], [animals.items.salmon], [animals.items.cod], [animals.items.parrotfish], [animals.items.catfish], [animals.items.perch], [animals.items.roasted_fish].
- [planting]: [plants.items.blueberry_bush], [plants.items.currant_bush], [plants.items.juniper_bush], [plants.items.raspberry_bush], [plants.items.rosehip_bush], [plants.items.shrub_bush], [plants.items.banana_bush].

### 2. [core.eras.bone_leather] `core:bone_leather`

[core.eras.bone_leather.about] Цепочки — до 8 шагов от старта.

- [stations]: **[tools.items.drying_rack]**, **[tools.items.fur_bedroll]**, **[tools.items.loom]**, **[tools.items.rain_catcher]**, [tools.items.wooden_bed], [tools.items.rug].
- [tools]: [tools.items.leather_sling].
- [clothes_and_bags]: **[tools.items.fur_hat]**, **[animals.items.poncho]**, **[tools.items.fur_coat]**, **[tools.items.leather_trousers]**, **[tools.items.fur_boots]**, **[tools.items.leather_hat]**, **[tools.items.leather_vest]**, **[tools.items.apron]**, [tools.items.leather_bag], **[tools.items.bandana]**, **[tools.items.hood]**, **[tools.items.linen_shirt]**, [tools.items.canvas_backpack].
- [materials]: **[materials.items.leather]**, **[tools.items.waterskin]**, **[tools.items.waterskin_full]**, **[tools.items.waterskin_sea]**, **[materials.items.cloth]**.
- [food]: [animals.items.jerky].

### 3. [core.eras.bronze] `core:bronze`

[core.eras.bronze.about] Цепочки — до 10 шагов от старта.

- [stations]: **[tools.items.kiln]**, [tools.items.fireplace], **[tools.items.forge]**, [tools.items.window], [tools.items.window_1x2], [tools.items.window_2x1], [tools.items.window_2x2], [tools.items.window_3x2].
- [tools]: [tools.items.copper_hoe], [tools.items.ice_auger], [tools.items.copper_axe], [tools.items.copper_knife], [tools.items.copper_pickaxe], [tools.items.copper_scythe], [tools.items.copper_shovel], [tools.items.copper_sickle], [tools.items.copper_sword], [tools.items.composite_bow].
- [light]: [tools.items.lantern], [tools.items.tar_torch].
- [materials]: **[materials.items.copper_ore]**, [materials.items.charcoal], [materials.items.copper_bar], [materials.items.glass], [materials.items.tin_ore], [tools.items.pot], [materials.items.crucible], [materials.items.tin_bar], [materials.items.bone_glue], [materials.items.tar], [plants.items.primrose_tea], **[tools.items.boat]**.
- [blocks]: [materials.items.brick].
- [food]: [plants.items.flatbread], [plants.items.roasted_acorns].

### 4. [core.eras.alloy] `core:alloy`

[core.eras.alloy.about] Цепочки — до 13 шагов от старта.

- [tools]: [tools.items.bronze_axe], [tools.items.bronze_knife], [tools.items.bronze_pickaxe], [tools.items.bronze_scythe], [tools.items.bronze_shovel], [tools.items.bronze_spear], [tools.items.bronze_sword].
- [materials]: **[materials.items.bronze_bar]**, [materials.items.iron_ore], [materials.items.gold_ore], [materials.items.platinum_ore], [materials.items.silver_ore], [materials.items.gold_bar], [materials.items.platinum_bar], [materials.items.silver_bar].

### 5. [core.eras.iron] `core:iron`

[core.eras.iron.about] Цепочки — до 14 шагов от старта.

- [stations]: **[tools.items.bloomery]**, **[tools.items.anvil]**.
- [tools]: [tools.items.iron_hoe], [tools.items.iron_axe], [tools.items.iron_knife], [tools.items.iron_pickaxe], [tools.items.iron_scythe], [tools.items.iron_shovel], [tools.items.iron_sickle], [tools.items.iron_spear], [tools.items.iron_sword].
- [materials]: **[materials.items.iron_bloom]**, **[materials.items.iron_bar]**.
- [blocks]: [materials.items.gold_block], [materials.items.platinum_block], [materials.items.silver_block].

### 6. [core.eras.steel] `core:steel`

[core.eras.steel.about] Цепочки — до 15 шагов от старта.

- [tools]: [tools.items.steel_axe], [tools.items.steel_knife], [tools.items.steel_pickaxe], [tools.items.steel_scythe], [tools.items.steel_shovel], [tools.items.steel_sword].
- [materials]: **[materials.items.steel_bar]**.

### Ветки

Инструменты, станки и то, что открывает эпоху, по эпохам; стрелка — из чего вещь выходит прямо (через
материалы и прочее, что не показано). Ветки, что идут рядом, не зависят друг от друга.

```mermaid
flowchart LR
  subgraph e1["1. [core.eras.primitive]"]
    b0["[core.items.campfire]"]
    b3["[materials.items.cord]"]
    b4["[tools.items.boundary_post]"]
    b5["[tools.items.fence]"]
    b6["[tools.items.wicket]"]
    b7["[tools.items.gate]"]
    b8["[tools.items.fishing_rod]"]
    b9["[tools.items.ladder]"]
    b10["[tools.items.cord_sling]"]
    b11["[tools.items.torch]"]
    b12["[tools.items.trap]"]
    b13["[tools.items.live_rabbit]"]
    b14["[tools.items.workbench]"]
    b16["[tools.items.wooden_bow]"]
    b35["[tools.items.stone_hoe]"]
    b38["[tools.items.ice_pick]"]
    b40["[tools.items.winter_rod]"]
    b45["[tools.items.bone_needle]"]
    b46["[tools.items.potters_wheel]"]
    b49["[tools.items.stone_axe]"]
    b54["[tools.items.raft]"]
    b56["[tools.items.oars]"]
    b58["[tools.items.flint_knife]"]
    b63["[tools.items.stone_pickaxe]"]
    b64["[tools.items.wooden_pickaxe]"]
    b69["[tools.items.rain_barrel]"]
    b71["[tools.items.stone_scythe]"]
    b72["[tools.items.wooden_scythe]"]
    b77["[tools.items.wooden_shovel]"]
    b82["[tools.items.stone_sickle]"]
    b85["[tools.items.flint_spear]"]
    b88["[tools.items.wooden_sword]"]
    b89["[tools.items.stone_sword]"]
    b94["[tools.items.watering_can_full]"]
  end
  subgraph e2["2. [core.eras.bone_leather]"]
    b1["[materials.items.cloth]"]
    b17["[tools.items.bandana]"]
    b18["[tools.items.hood]"]
    b19["[tools.items.linen_shirt]"]
    b20["[tools.items.drying_rack]"]
    b21["[materials.items.leather]"]
    b22["[tools.items.fur_bedroll]"]
    b28["[tools.items.fur_hat]"]
    b29["[tools.items.fur_coat]"]
    b30["[tools.items.leather_trousers]"]
    b31["[tools.items.fur_boots]"]
    b32["[tools.items.leather_hat]"]
    b33["[tools.items.leather_vest]"]
    b34["[tools.items.apron]"]
    b42["[tools.items.leather_sling]"]
    b43["[tools.items.loom]"]
    b44["[animals.items.poncho]"]
    b70["[tools.items.rain_catcher]"]
    b95["[tools.items.waterskin]"]
    b96["[tools.items.waterskin_full]"]
    b97["[tools.items.waterskin_sea]"]
  end
  subgraph e3["3. [core.eras.bronze]"]
    b2["[materials.items.copper_ore]"]
    b23["[tools.items.fireplace]"]
    b24["[tools.items.forge]"]
    b36["[tools.items.copper_hoe]"]
    b39["[tools.items.ice_auger]"]
    b41["[tools.items.kiln]"]
    b50["[tools.items.copper_axe]"]
    b55["[tools.items.boat]"]
    b57["[tools.items.composite_bow]"]
    b59["[tools.items.copper_knife]"]
    b65["[tools.items.copper_pickaxe]"]
    b73["[tools.items.copper_scythe]"]
    b78["[tools.items.copper_shovel]"]
    b83["[tools.items.copper_sickle]"]
    b90["[tools.items.copper_sword]"]
  end
  subgraph e4["4. [core.eras.alloy]"]
    b47["[materials.items.bronze_bar]"]
    b51["[tools.items.bronze_axe]"]
    b60["[tools.items.bronze_knife]"]
    b66["[tools.items.bronze_pickaxe]"]
    b74["[tools.items.bronze_scythe]"]
    b79["[tools.items.bronze_shovel]"]
    b86["[tools.items.bronze_spear]"]
    b91["[tools.items.bronze_sword]"]
  end
  subgraph e5["5. [core.eras.iron]"]
    b15["[tools.items.bloomery]"]
    b25["[materials.items.iron_bloom]"]
    b26["[materials.items.iron_bar]"]
    b27["[tools.items.anvil]"]
    b37["[tools.items.iron_hoe]"]
    b52["[tools.items.iron_axe]"]
    b61["[tools.items.iron_knife]"]
    b67["[tools.items.iron_pickaxe]"]
    b75["[tools.items.iron_scythe]"]
    b80["[tools.items.iron_shovel]"]
    b84["[tools.items.iron_sickle]"]
    b87["[tools.items.iron_spear]"]
    b92["[tools.items.iron_sword]"]
  end
  subgraph e6["6. [core.eras.steel]"]
    b48["[materials.items.steel_bar]"]
    b53["[tools.items.steel_axe]"]
    b62["[tools.items.steel_knife]"]
    b68["[tools.items.steel_pickaxe]"]
    b76["[tools.items.steel_scythe]"]
    b81["[tools.items.steel_shovel]"]
    b93["[tools.items.steel_sword]"]
  end
  b43 --> b1
  b63 --> b2
  b49 --> b4
  b3 --> b5
  b3 --> b6
  b3 --> b7
  b3 --> b8
  b3 --> b9
  b3 --> b10
  b3 --> b12
  b3 --> b14
  b41 --> b15
  b49 --> b16
  b1 --> b17
  b45 --> b17
  b1 --> b18
  b45 --> b18
  b1 --> b19
  b45 --> b19
  b14 --> b20
  b20 --> b21
  b58 --> b21
  b45 --> b22
  b41 --> b23
  b41 --> b24
  b15 --> b25
  b66 --> b25
  b25 --> b26
  b26 --> b27
  b14 --> b28
  b45 --> b28
  b21 --> b29
  b45 --> b29
  b21 --> b30
  b45 --> b30
  b21 --> b31
  b45 --> b31
  b21 --> b32
  b45 --> b32
  b21 --> b33
  b45 --> b33
  b21 --> b34
  b45 --> b34
  b3 --> b35
  b2 --> b36
  b24 --> b36
  b49 --> b36
  b27 --> b37
  b3 --> b38
  b2 --> b39
  b24 --> b39
  b49 --> b39
  b3 --> b40
  b14 --> b41
  b21 --> b42
  b45 --> b42
  b49 --> b43
  b14 --> b44
  b45 --> b44
  b58 --> b45
  b49 --> b46
  b46 --> b47
  b65 --> b47
  b26 --> b48
  b14 --> b49
  b2 --> b50
  b24 --> b50
  b49 --> b50
  b47 --> b51
  b27 --> b52
  b27 --> b53
  b48 --> b53
  b49 --> b54
  b41 --> b55
  b46 --> b55
  b49 --> b56
  b16 --> b57
  b21 --> b57
  b41 --> b57
  b46 --> b57
  b3 --> b58
  b2 --> b59
  b24 --> b59
  b49 --> b59
  b47 --> b60
  b27 --> b61
  b27 --> b62
  b48 --> b62
  b14 --> b63
  b3 --> b64
  b2 --> b65
  b24 --> b65
  b49 --> b65
  b47 --> b66
  b27 --> b67
  b27 --> b68
  b48 --> b68
  b49 --> b69
  b21 --> b70
  b14 --> b71
  b3 --> b72
  b2 --> b73
  b24 --> b73
  b49 --> b73
  b47 --> b74
  b27 --> b75
  b27 --> b76
  b48 --> b76
  b49 --> b77
  b2 --> b78
  b24 --> b78
  b49 --> b78
  b47 --> b79
  b27 --> b80
  b27 --> b81
  b48 --> b81
  b3 --> b82
  b2 --> b83
  b24 --> b83
  b49 --> b83
  b27 --> b84
  b3 --> b85
  b47 --> b86
  b27 --> b87
  b3 --> b88
  b14 --> b89
  b2 --> b90
  b24 --> b90
  b49 --> b90
  b47 --> b91
  b27 --> b92
  b27 --> b93
  b48 --> b93
  b49 --> b94
  b21 --> b95
  b45 --> b95
  b95 --> b96
  b95 --> b97
```

## Схема рецептов

Сплошная стрелка — материал рецепта (к изделию и побочному), пунктир — то, что не тратится: станок,
инструмент, вещь в сумке. Скруглено то, что не делает ни один рецепт (его даёт мир или старт), в рамке —
станки, в шестиугольнике — инструмент любого вида.

```mermaid
flowchart LR
  n0["[plants.items.fried_mushrooms]"]
  n1(["[plants.items.mushroom]"])
  n1 --> n0
  n2[["[core.items.campfire]"]]
  n2 -.-> n0
  n3["[materials.items.cord]"]
  n4(["[resources.items.fiber]"])
  n4 --> n3
  n5["[plants.items.bandage]"]
  n6(["[plants.items.moss]"])
  n6 --> n5
  n4 --> n5
  n7["[plants.items.poultice]"]
  n6 --> n7
  n5 --> n7
  n2 -.-> n7
  n8(["[resources.items.branch]"])
  n8 --> n2
  n4 --> n2
  n9["[animals.items.roasted_fish]"]
  n10(["[animals.items.roach]"])
  n10 --> n9
  n8 --> n9
  n2 -.-> n9
  n11(["[animals.items.pike]"])
  n11 --> n9
  n8 --> n9
  n2 -.-> n9
  n12(["[animals.items.salmon]"])
  n12 --> n9
  n8 --> n9
  n2 -.-> n9
  n13(["[animals.items.cod]"])
  n13 --> n9
  n8 --> n9
  n2 -.-> n9
  n14(["[animals.items.parrotfish]"])
  n14 --> n9
  n8 --> n9
  n2 -.-> n9
  n15(["[animals.items.catfish]"])
  n15 --> n9
  n8 --> n9
  n2 -.-> n9
  n16(["[animals.items.perch]"])
  n16 --> n9
  n8 --> n9
  n2 -.-> n9
  n17["[materials.items.log_wall]"]
  n18(["[resources.items.log]"])
  n18 --> n17
  n19{{"[tool.axe] (любой)"}}
  n19 -.-> n17
  n20["[materials.items.wattle]"]
  n8 --> n20
  n21[["[tools.items.boundary_post]"]]
  n18 --> n21
  n8 --> n21
  n3 --> n21
  n22[["[tools.items.fence]"]]
  n8 --> n22
  n3 --> n22
  n23[["[tools.items.wicket]"]]
  n8 --> n23
  n3 --> n23
  n24[["[tools.items.gate]"]]
  n8 --> n24
  n3 --> n24
  n25["[tools.items.fiber_hat]"]
  n4 --> n25
  n26["[tools.items.grass_cape]"]
  n4 --> n26
  n3 --> n26
  n27["[tools.items.leg_wraps]"]
  n4 --> n27
  n3 --> n27
  n28["[tools.items.bast_shoes]"]
  n4 --> n28
  n3 --> n28
  n29["[tools.items.fiber_tunic]"]
  n4 --> n29
  n3 --> n29
  n30["[tools.items.fishing_rod]"]
  n8 --> n30
  n3 --> n30
  n31(["[resources.items.flint]"])
  n31 --> n30
  n32["[tools.items.bait]"]
  n33(["[resources.items.dirt]"])
  n33 --> n32
  n34[["[tools.items.ladder]"]]
  n8 --> n34
  n3 --> n34
  n35["[tools.items.cord_sling]"]
  n3 --> n35
  n4 --> n35
  n36["[tools.items.sling_stone]"]
  n37(["[resources.items.stone]"])
  n37 --> n36
  n38["[tools.items.torch]"]
  n8 --> n38
  n4 --> n38
  n39[["[tools.items.trap]"]]
  n8 --> n39
  n3 --> n39
  n40["[tools.items.wicker_bag]"]
  n4 --> n40
  n3 --> n40
  n41[["[tools.items.workbench]"]]
  n8 --> n41
  n3 --> n41
  n42["[materials.items.cut_stone]"]
  n37 --> n42
  n41 -.-> n42
  n43{{"[tool.pickaxe] (любой)"}}
  n43 -.-> n42
  n44[["[tools.items.big_chest]"]]
  n45["[materials.items.planks]"]
  n45 --> n44
  n3 --> n44
  n41 -.-> n44
  n46[["[tools.items.bloomery]"]]
  n47(["[resources.items.clay]"])
  n47 --> n46
  n37 --> n46
  n48["[materials.items.brick]"]
  n48 --> n46
  n41 -.-> n46
  n49["[tools.items.wooden_bow]"]
  n45 --> n49
  n3 --> n49
  n41 -.-> n49
  n50["[tools.items.arrow]"]
  n8 --> n50
  n31 --> n50
  n4 --> n50
  n41 -.-> n50
  n51[["[tools.items.chest]"]]
  n45 --> n51
  n41 -.-> n51
  n52["[tools.items.bandana]"]
  n53["[materials.items.cloth]"]
  n53 --> n52
  n41 -.-> n52
  n54{{"[tool.needle] (любой)"}}
  n54 -.-> n52
  n55["[tools.items.hood]"]
  n53 --> n55
  n3 --> n55
  n41 -.-> n55
  n54 -.-> n55
  n56["[tools.items.linen_shirt]"]
  n53 --> n56
  n3 --> n56
  n41 -.-> n56
  n54 -.-> n56
  n57[["[tools.items.door]"]]
  n45 --> n57
  n41 -.-> n57
  n58[["[tools.items.door_2x2]"]]
  n45 --> n58
  n41 -.-> n58
  n59[["[tools.items.door_2x3]"]]
  n45 --> n59
  n41 -.-> n59
  n60[["[tools.items.door_3x3]"]]
  n45 --> n60
  n41 -.-> n60
  n61[["[tools.items.drying_rack]"]]
  n8 --> n61
  n3 --> n61
  n41 -.-> n61
  n62["[animals.items.raw_meat]"]
  n63(["[animals.items.small_carcass]"])
  n63 --> n62
  n64["[animals.items.bone]"]
  n63 --> n64
  n65["[animals.items.hide]"]
  n63 --> n65
  n66(["[animals.items.carcass]"])
  n66 --> n62
  n66 --> n65
  n66 --> n64
  n67["[animals.items.fat]"]
  n66 --> n67
  n68{{"[tool.knife] (любой)"}}
  n68 -.-> n62
  n69["[animals.items.roasted_meat]"]
  n62 --> n69
  n8 --> n69
  n2 -.-> n69
  n70["[animals.items.jerky]"]
  n62 --> n70
  n61 -.-> n70
  n71["[materials.items.leather]"]
  n65 --> n71
  n67 --> n71
  n61 -.-> n71
  n72[["[tools.items.grass_mat]"]]
  n4 --> n72
  n3 --> n72
  n73[["[tools.items.fur_bedroll]"]]
  n65 --> n73
  n3 --> n73
  n54 -.-> n73
  n74["[tools.items.tallow_candle]"]
  n67 --> n74
  n4 --> n74
  n75["[tools.items.canvas_backpack]"]
  n53 --> n75
  n71 --> n75
  n3 --> n75
  n54 -.-> n75
  n76[["[tools.items.fireplace]"]]
  n48 --> n76
  n37 --> n76
  n47 --> n76
  n41 -.-> n76
  n77[["[tools.items.forge]"]]
  n48 --> n77
  n37 --> n77
  n47 --> n77
  n41 -.-> n77
  n78["[materials.items.copper_bar]"]
  n79(["[materials.items.copper_ore]"])
  n79 --> n78
  n80["[materials.items.charcoal]"]
  n80 --> n78
  n77 -.-> n78
  n81["[materials.items.glass]"]
  n82(["[resources.items.sand]"])
  n82 --> n81
  n80 --> n81
  n77 -.-> n81
  n83["[materials.items.iron_bloom]"]
  n84(["[materials.items.iron_ore]"])
  n84 --> n83
  n80 --> n83
  n46 -.-> n83
  n85["[materials.items.iron_bar]"]
  n83 --> n85
  n80 --> n85
  n77 -.-> n85
  n86["[materials.items.tin_bar]"]
  n87(["[materials.items.tin_ore]"])
  n87 --> n86
  n80 --> n86
  n77 -.-> n86
  n88[["[tools.items.anvil]"]]
  n85 --> n88
  n18 --> n88
  n41 -.-> n88
  n89["[materials.items.gold_bar]"]
  n90(["[materials.items.gold_ore]"])
  n90 --> n89
  n80 --> n89
  n77 -.-> n89
  n91["[materials.items.gold_block]"]
  n89 --> n91
  n88 -.-> n91
  n92["[materials.items.platinum_bar]"]
  n93(["[materials.items.platinum_ore]"])
  n93 --> n92
  n80 --> n92
  n77 -.-> n92
  n94["[materials.items.platinum_block]"]
  n92 --> n94
  n88 -.-> n94
  n95["[materials.items.silver_bar]"]
  n96(["[materials.items.silver_ore]"])
  n96 --> n95
  n80 --> n95
  n77 -.-> n95
  n97["[materials.items.silver_block]"]
  n95 --> n97
  n88 -.-> n97
  n98[["[tools.items.hatch]"]]
  n45 --> n98
  n41 -.-> n98
  n99[["[tools.items.hatch_2x2]"]]
  n45 --> n99
  n41 -.-> n99
  n100["[tools.items.fur_hat]"]
  n65 --> n100
  n3 --> n100
  n41 -.-> n100
  n54 -.-> n100
  n101["[tools.items.fur_coat]"]
  n65 --> n101
  n71 --> n101
  n3 --> n101
  n41 -.-> n101
  n54 -.-> n101
  n102["[tools.items.leather_trousers]"]
  n71 --> n102
  n3 --> n102
  n41 -.-> n102
  n54 -.-> n102
  n103["[tools.items.fur_boots]"]
  n65 --> n103
  n71 --> n103
  n3 --> n103
  n41 -.-> n103
  n54 -.-> n103
  n104["[tools.items.leather_hat]"]
  n71 --> n104
  n3 --> n104
  n41 -.-> n104
  n54 -.-> n104
  n105["[tools.items.leather_vest]"]
  n71 --> n105
  n3 --> n105
  n41 -.-> n105
  n54 -.-> n105
  n106["[tools.items.apron]"]
  n71 --> n106
  n3 --> n106
  n41 -.-> n106
  n54 -.-> n106
  n107["[tools.items.stone_hoe]"]
  n31 --> n107
  n8 --> n107
  n3 --> n107
  n108["[tools.items.copper_hoe]"]
  n78 --> n108
  n45 --> n108
  n41 -.-> n108
  n109["[tools.items.iron_hoe]"]
  n85 --> n109
  n45 --> n109
  n88 -.-> n109
  n110["[tools.items.ice_pick]"]
  n8 --> n110
  n37 --> n110
  n3 --> n110
  n111["[tools.items.ice_auger]"]
  n78 --> n111
  n45 --> n111
  n41 -.-> n111
  n112["[tools.items.winter_rod]"]
  n8 --> n112
  n3 --> n112
  n31 --> n112
  n113[["[tools.items.kiln]"]]
  n37 --> n113
  n47 --> n113
  n41 -.-> n113
  n47 --> n48
  n113 -.-> n48
  n18 --> n80
  n113 -.-> n80
  n114["[plants.items.flour]"]
  n115(["[plants.items.grain]"])
  n115 --> n114
  n116["[plants.items.flatbread]"]
  n114 --> n116
  n113 -.-> n116
  n117["[tools.items.leather_bag]"]
  n71 --> n117
  n3 --> n117
  n54 -.-> n117
  n118["[tools.items.leather_sling]"]
  n71 --> n118
  n3 --> n118
  n54 -.-> n118
  n119[["[tools.items.loom]"]]
  n45 --> n119
  n8 --> n119
  n3 --> n119
  n41 -.-> n119
  n3 --> n53
  n119 -.-> n53
  n120["[animals.items.wool_yarn]"]
  n121(["[animals.items.rabbit_fluff]"])
  n121 --> n120
  n120 --> n53
  n119 -.-> n53
  n122["[animals.items.poncho]"]
  n120 --> n122
  n41 -.-> n122
  n54 -.-> n122
  n123["[plants.items.linen_thread]"]
  n124(["[plants.items.flax_stalks]"])
  n124 --> n123
  n123 --> n53
  n119 -.-> n53
  n125[["[tools.items.table]"]]
  n45 --> n125
  n41 -.-> n125
  n126[["[tools.items.stool]"]]
  n45 --> n126
  n41 -.-> n126
  n127[["[tools.items.wooden_bed]"]]
  n45 --> n127
  n53 --> n127
  n41 -.-> n127
  n128[["[tools.items.cupboard]"]]
  n45 --> n128
  n41 -.-> n128
  n129[["[tools.items.wide_cupboard]"]]
  n45 --> n129
  n41 -.-> n129
  n130[["[tools.items.barrel]"]]
  n45 --> n130
  n3 --> n130
  n41 -.-> n130
  n131[["[tools.items.rug]"]]
  n53 --> n131
  n119 -.-> n131
  n132["[tools.items.bone_needle]"]
  n64 --> n132
  n68 -.-> n132
  n133[["[tools.items.potters_wheel]"]]
  n45 --> n133
  n37 --> n133
  n8 --> n133
  n41 -.-> n133
  n134["[tools.items.raw_pot]"]
  n47 --> n134
  n133 -.-> n134
  n135["[tools.items.pot]"]
  n134 --> n135
  n113 -.-> n135
  n136["[materials.items.bone_glue]"]
  n64 --> n136
  n8 --> n136
  n2 -.-> n136
  n135 -.-> n136
  n137["[materials.items.raw_crucible]"]
  n47 --> n137
  n82 --> n137
  n133 -.-> n137
  n138["[materials.items.crucible]"]
  n137 --> n138
  n113 -.-> n138
  n139["[materials.items.bronze_bar]"]
  n78 --> n139
  n86 --> n139
  n80 --> n139
  n77 -.-> n139
  n138 -.-> n139
  n140["[materials.items.steel_bar]"]
  n85 --> n140
  n80 --> n140
  n46 -.-> n140
  n138 -.-> n140
  n141["[materials.items.tar]"]
  n18 --> n141
  n18 --> n80
  n113 -.-> n141
  n135 -.-> n141
  n142["[plants.items.primrose_tea]"]
  n143(["[plants.items.evening_primrose]"])
  n143 --> n142
  n2 -.-> n142
  n135 -.-> n142
  n144["[plants.items.flower_wreath]"]
  n143 --> n144
  n4 --> n144
  n145["[plants.items.roasted_acorns]"]
  n146(["[plants.items.acorn]"])
  n146 --> n145
  n2 -.-> n145
  n135 -.-> n145
  n147(["[plants.items.sundew]"])
  n147 --> n136
  n8 --> n136
  n2 -.-> n136
  n135 -.-> n136
  n148["[tools.items.stone_axe]"]
  n31 --> n148
  n8 --> n148
  n3 --> n148
  n41 -.-> n148
  n18 --> n45
  n41 -.-> n45
  n19 -.-> n45
  n149["[tools.items.copper_axe]"]
  n78 --> n149
  n45 --> n149
  n41 -.-> n149
  n150["[tools.items.bronze_axe]"]
  n139 --> n150
  n45 --> n150
  n41 -.-> n150
  n151["[tools.items.iron_axe]"]
  n85 --> n151
  n45 --> n151
  n88 -.-> n151
  n152["[tools.items.steel_axe]"]
  n140 --> n152
  n45 --> n152
  n88 -.-> n152
  n153["[tools.items.raft]"]
  n18 --> n153
  n3 --> n153
  n154["[tools.items.boat]"]
  n45 --> n154
  n141 --> n154
  n41 -.-> n154
  n155["[tools.items.oars]"]
  n45 --> n155
  n41 -.-> n155
  n156["[tools.items.composite_bow]"]
  n49 --> n156
  n64 --> n156
  n136 --> n156
  n71 --> n156
  n41 -.-> n156
  n8 --> n50
  n64 --> n50
  n4 --> n50
  n41 -.-> n50
  n157["[tools.items.flint_knife]"]
  n31 --> n157
  n8 --> n157
  n3 --> n157
  n158["[tools.items.copper_knife]"]
  n78 --> n158
  n45 --> n158
  n41 -.-> n158
  n159["[tools.items.bronze_knife]"]
  n139 --> n159
  n45 --> n159
  n41 -.-> n159
  n160["[tools.items.iron_knife]"]
  n85 --> n160
  n45 --> n160
  n88 -.-> n160
  n161["[tools.items.steel_knife]"]
  n140 --> n161
  n45 --> n161
  n88 -.-> n161
  n162["[tools.items.lantern]"]
  n81 --> n162
  n78 --> n162
  n141 --> n162
  n41 -.-> n162
  n163["[tools.items.stone_pickaxe]"]
  n31 --> n163
  n8 --> n163
  n3 --> n163
  n41 -.-> n163
  n164["[tools.items.wooden_pickaxe]"]
  n8 --> n164
  n3 --> n164
  n165["[tools.items.copper_pickaxe]"]
  n78 --> n165
  n45 --> n165
  n41 -.-> n165
  n166["[tools.items.bronze_pickaxe]"]
  n139 --> n166
  n45 --> n166
  n41 -.-> n166
  n167["[tools.items.iron_pickaxe]"]
  n85 --> n167
  n45 --> n167
  n88 -.-> n167
  n168["[tools.items.steel_pickaxe]"]
  n140 --> n168
  n45 --> n168
  n88 -.-> n168
  n169[["[tools.items.rain_barrel]"]]
  n45 --> n169
  n3 --> n169
  n41 -.-> n169
  n170[["[tools.items.rain_catcher]"]]
  n8 --> n170
  n71 --> n170
  n3 --> n170
  n41 -.-> n170
  n171["[tools.items.stone_scythe]"]
  n31 --> n171
  n8 --> n171
  n3 --> n171
  n41 -.-> n171
  n172["[tools.items.wooden_scythe]"]
  n8 --> n172
  n3 --> n172
  n173["[tools.items.copper_scythe]"]
  n78 --> n173
  n45 --> n173
  n41 -.-> n173
  n174["[tools.items.bronze_scythe]"]
  n139 --> n174
  n45 --> n174
  n41 -.-> n174
  n175["[tools.items.iron_scythe]"]
  n85 --> n175
  n45 --> n175
  n88 -.-> n175
  n176["[tools.items.steel_scythe]"]
  n140 --> n176
  n45 --> n176
  n88 -.-> n176
  n177["[tools.items.wooden_shovel]"]
  n45 --> n177
  n8 --> n177
  n41 -.-> n177
  n178["[tools.items.copper_shovel]"]
  n78 --> n178
  n45 --> n178
  n41 -.-> n178
  n179["[tools.items.bronze_shovel]"]
  n139 --> n179
  n45 --> n179
  n41 -.-> n179
  n180["[tools.items.iron_shovel]"]
  n85 --> n180
  n45 --> n180
  n88 -.-> n180
  n181["[tools.items.steel_shovel]"]
  n140 --> n181
  n45 --> n181
  n88 -.-> n181
  n182["[tools.items.stone_sickle]"]
  n31 --> n182
  n8 --> n182
  n3 --> n182
  n183["[tools.items.copper_sickle]"]
  n78 --> n183
  n8 --> n183
  n41 -.-> n183
  n184["[tools.items.iron_sickle]"]
  n85 --> n184
  n8 --> n184
  n88 -.-> n184
  n185[["[tools.items.sign]"]]
  n45 --> n185
  n8 --> n185
  n186[["[tools.items.signpost]"]]
  n45 --> n186
  n8 --> n186
  n187[["[tools.items.notice_board]"]]
  n45 --> n187
  n41 -.-> n187
  n188["[tools.items.flint_spear]"]
  n8 --> n188
  n31 --> n188
  n3 --> n188
  n189["[tools.items.bronze_spear]"]
  n139 --> n189
  n45 --> n189
  n41 -.-> n189
  n190["[tools.items.iron_spear]"]
  n85 --> n190
  n45 --> n190
  n88 -.-> n190
  n191["[tools.items.wooden_sword]"]
  n8 --> n191
  n3 --> n191
  n192["[tools.items.stone_sword]"]
  n31 --> n192
  n8 --> n192
  n3 --> n192
  n41 -.-> n192
  n193["[tools.items.copper_sword]"]
  n78 --> n193
  n45 --> n193
  n41 -.-> n193
  n194["[tools.items.bronze_sword]"]
  n139 --> n194
  n45 --> n194
  n41 -.-> n194
  n195["[tools.items.iron_sword]"]
  n85 --> n195
  n45 --> n195
  n88 -.-> n195
  n196["[tools.items.steel_sword]"]
  n140 --> n196
  n45 --> n196
  n88 -.-> n196
  n197["[tools.items.tar_torch]"]
  n8 --> n197
  n53 --> n197
  n141 --> n197
  n198["[tools.items.watering_can]"]
  n45 --> n198
  n3 --> n198
  n41 -.-> n198
  n199["[tools.items.waterskin]"]
  n71 --> n199
  n3 --> n199
  n54 -.-> n199
  n200["[tools.items.waterskin_full]"]
  n201(["[tools.items.waterskin_sea]"])
  n201 --> n200
  n2 -.-> n200
  n201 --> n200
  n202["[resources.items.salt]"]
  n201 --> n202
  n2 -.-> n200
  n135 -.-> n200
  n203[["[tools.items.window]"]]
  n45 --> n203
  n81 --> n203
  n41 -.-> n203
  n204[["[tools.items.window_1x2]"]]
  n45 --> n204
  n81 --> n204
  n41 -.-> n204
  n205[["[tools.items.window_2x1]"]]
  n45 --> n205
  n81 --> n205
  n41 -.-> n205
  n206[["[tools.items.window_2x2]"]]
  n45 --> n206
  n81 --> n206
  n41 -.-> n206
  n207[["[tools.items.window_3x2]"]]
  n45 --> n207
  n81 --> n207
  n41 -.-> n207
```
