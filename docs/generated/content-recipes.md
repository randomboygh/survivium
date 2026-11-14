# Реестр рецептов

Создаёт `tools/content_report.gd` из данных всех модов; руками не править, CI проверяет, что реестр свежий.
Поля рецепта — [DATA_MODEL.md](../DATA_MODEL.md), правила — раздел 6
[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md), что из чего по цепочкам — [content-graph.md](content-graph.md).

Рецепт узнаётся, когда в сумке побывало всё, что он тратит. Тратит — забирается из сумки, когда работа
встаёт в очередь (отмена возвращает); в сумке — нужно, пока идёт работа, и не тратится. Станок — где
делают; годится и тот, что его заменяет (`serves`). Инструменты — классы, по одному каждого в сумке;
износ — сколько ударов снимает с инструмента каждое изделие, когда износ включён. Побочно — что выходит
вместе с изделием, с шансом, который решает номер работы, а не случай. Глубина — шагов изготовления
от старта до изделия по этому рецепту, эпоха — самая поздняя эпоха того, что рецепт требует (карта эпох —
в [content-graph.md](content-graph.md)). Альтернативы — другие рецепты той же вещи.

## Сводка

| Процесс | Рецептов | Где делают |
|---|---|---|
| [crafting] (`craft`) | 123 | руки, [core.items.campfire], [tools.items.workbench], [tools.items.anvil], [tools.items.loom], [tools.items.potters_wheel] |
| Переработка (`refine`) | 12 | руки, [tools.items.workbench], [tools.items.drying_rack], [tools.items.loom] |
| Плавка и обжиг (`smelt`) | 15 | [tools.items.forge], [tools.items.bloomery], [tools.items.kiln] |
| Готовка (`cook`) | 12 | [core.items.campfire], [tools.items.kiln] |

## [crafting] (`craft`)

| Рецепт | Делает | Тратит | В сумке | Станок | Инструменты | Время | Глубина | Эпоха | Альтернативы |
|---|---|---|---|---|---|---|---|---|---|
| [plants.recipes.bandage] `plants:bandage` | [plants.items.bandage] ×1 | [plants.items.moss] ×2, [resources.items.fiber] ×2 | — | руки | — | 3 с | 1 | 0. [core.eras.foraging] | — |
| [plants.recipes.poultice] `plants:poultice` | [plants.items.poultice] ×1 | [plants.items.moss] ×3, [plants.items.bandage] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 4 с | 2 | 0. [core.eras.foraging] | — |
| [resources.recipes.campfire] `resources:campfire` | [core.items.campfire] ×1 | [resources.items.branch] ×5, [resources.items.fiber] ×5 | — | руки | — | 4 с | 1 | 0. [core.eras.foraging] | — |
| [materials.recipes.wattle] `materials:wattle` | [materials.items.wattle] ×1 | [resources.items.branch] ×4 | — | руки | — | 3 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.boundary_post] `tools:boundary_post` | [tools.items.boundary_post] ×1 | [resources.items.log] ×1, [resources.items.branch] ×2, [materials.items.cord] ×2 | — | руки | — | 6 с | 4 | 1. [core.eras.primitive] | — |
| [tools.recipes.fence] `tools:fence` | [tools.items.fence] ×2 | [resources.items.branch] ×3, [materials.items.cord] ×1 | — | руки | — | 3 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.wicket] `tools:wicket` | [tools.items.wicket] ×1 | [resources.items.branch] ×4, [materials.items.cord] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.gate] `tools:gate` | [tools.items.gate] ×1 | [resources.items.branch] ×8, [materials.items.cord] ×2 | — | руки | — | 6 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.fiber_hat] `tools:fiber_hat` | [tools.items.fiber_hat] ×1 | [resources.items.fiber] ×4 | — | руки | — | 4 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.grass_cape] `tools:grass_cape` | [tools.items.grass_cape] ×1 | [resources.items.fiber] ×8, [materials.items.cord] ×2 | — | руки | — | 8 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.leg_wraps] `tools:leg_wraps` | [tools.items.leg_wraps] ×1 | [resources.items.fiber] ×5, [materials.items.cord] ×1 | — | руки | — | 5 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.bast_shoes] `tools:bast_shoes` | [tools.items.bast_shoes] ×1 | [resources.items.fiber] ×4, [materials.items.cord] ×2 | — | руки | — | 5 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.fishing_rod] `tools:fishing_rod` | [tools.items.fishing_rod] ×1 | [resources.items.branch] ×2, [materials.items.cord] ×2, [resources.items.flint] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.bait] `tools:bait` | [tools.items.bait] ×4 | [resources.items.dirt] ×1 | — | руки | — | 2 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.ladder] `tools:ladder` | [tools.items.ladder] ×2 | [resources.items.branch] ×4, [materials.items.cord] ×1 | — | руки | — | 3 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.cord_sling] `tools:cord_sling` | [tools.items.cord_sling] ×1 | [materials.items.cord] ×2, [resources.items.fiber] ×2 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.sling_stone] `tools:sling_stone` | [tools.items.sling_stone] ×8 | [resources.items.stone] ×1 | — | руки | — | 2 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.torch] `tools:torch` | [tools.items.torch] ×1 | [resources.items.branch] ×1, [resources.items.fiber] ×2 | — | руки | — | 2 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.trap] `tools:trap` | [tools.items.trap] ×1 | [resources.items.branch] ×6, [materials.items.cord] ×2 | — | руки | — | 6 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.wicker_bag] `tools:wicker_bag` | [tools.items.wicker_bag] ×1 | [resources.items.fiber] ×6, [materials.items.cord] ×4 | — | руки | — | 8 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.workbench] `tools:workbench` | [tools.items.workbench] ×1 | [resources.items.branch] ×8, [materials.items.cord] ×2 | — | руки | — | 6 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.big_chest] `tools:big_chest` | [tools.items.big_chest] ×1 | [materials.items.planks] ×14, [materials.items.cord] ×2 | — | [tools.items.workbench] | — | 16 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.bloomery] `tools:bloomery` | [tools.items.bloomery] ×1 | [resources.items.clay] ×8, [resources.items.stone] ×10, [materials.items.brick] ×6 | — | [tools.items.workbench] | — | 14 с | 5 | 3. [core.eras.bronze] | — |
| [tools.recipes.wooden_bow] `tools:wooden_bow` | [tools.items.wooden_bow] ×1 | [materials.items.planks] ×1, [materials.items.cord] ×2 | — | [tools.items.workbench] | — | 6 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.arrow] `tools:arrow` | [tools.items.arrow] ×4 | [resources.items.branch] ×1, [resources.items.flint] ×1, [resources.items.fiber] ×1 | — | [tools.items.workbench] | — | 4 с | 3 | 1. [core.eras.primitive] | [tools.recipes.arrow_from_bone] `tools:arrow_from_bone` |
| [tools.recipes.chest] `tools:chest` | [tools.items.chest] ×1 | [materials.items.planks] ×6 | — | [tools.items.workbench] | — | 8 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.door] `tools:door` | [tools.items.door] ×1 | [materials.items.planks] ×4 | — | [tools.items.workbench] | — | 5 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.door_2x2] `tools:door_2x2` | [tools.items.door_2x2] ×1 | [materials.items.planks] ×8 | — | [tools.items.workbench] | — | 8 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.door_2x3] `tools:door_2x3` | [tools.items.door_2x3] ×1 | [materials.items.planks] ×12 | — | [tools.items.workbench] | — | 10 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.door_3x3] `tools:door_3x3` | [tools.items.door_3x3] ×1 | [materials.items.planks] ×18 | — | [tools.items.workbench] | — | 14 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.drying_rack] `tools:drying_rack` | [tools.items.drying_rack] ×1 | [resources.items.branch] ×8, [materials.items.cord] ×3 | — | [tools.items.workbench] | — | 8 с | 3 | 1. [core.eras.primitive] | — |
| [animals.recipes.raw_meat_from_small_carcass] `animals:raw_meat_from_small_carcass` | [animals.items.raw_meat] ×1; побочно: [animals.items.bone] ×1 (50%); побочно: [animals.items.hide] ×1 (30%) | [animals.items.small_carcass] ×1 | — | руки | — | 3 с | 1 | 0. [core.eras.foraging] | [animals.recipes.raw_meat_from_carcass] `animals:raw_meat_from_carcass` |
| [animals.recipes.raw_meat_from_carcass] `animals:raw_meat_from_carcass` | [animals.items.raw_meat] ×5; побочно: [animals.items.hide] ×1; побочно: [animals.items.bone] ×3; побочно: [animals.items.fat] ×2 | [animals.items.carcass] ×1 | — | руки | [tool.knife] (износ 2) | 10 с | 3 | 1. [core.eras.primitive] | [animals.recipes.raw_meat_from_small_carcass] `animals:raw_meat_from_small_carcass` |
| [tools.recipes.grass_mat] `tools:grass_mat` | [tools.items.grass_mat] ×1 | [resources.items.fiber] ×10, [materials.items.cord] ×2 | — | руки | — | 8 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.fur_bedroll] `tools:fur_bedroll` | [tools.items.fur_bedroll] ×1 | [animals.items.hide] ×3, [materials.items.cord] ×2 | — | руки | [tool.needle] (износ 2) | 14 с | 4 | 1. [core.eras.primitive] | — |
| [tools.recipes.tallow_candle] `tools:tallow_candle` | [tools.items.tallow_candle] ×1 | [animals.items.fat] ×1, [resources.items.fiber] ×1 | — | руки | — | 3 с | 4 | 1. [core.eras.primitive] | — |
| [tools.recipes.canvas_backpack] `tools:canvas_backpack` | [tools.items.canvas_backpack] ×1 | [materials.items.cloth] ×4, [materials.items.leather] ×2, [materials.items.cord] ×2 | — | руки | [tool.needle] (износ 3) | 14 с | 7 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.fireplace] `tools:fireplace` | [tools.items.fireplace] ×1 | [materials.items.brick] ×8, [resources.items.stone] ×4, [resources.items.clay] ×2 | — | [tools.items.workbench] | — | 10 с | 5 | 3. [core.eras.bronze] | — |
| [tools.recipes.forge] `tools:forge` | [tools.items.forge] ×1 | [materials.items.brick] ×12, [resources.items.stone] ×8, [resources.items.clay] ×4 | — | [tools.items.workbench] | — | 12 с | 5 | 3. [core.eras.bronze] | — |
| [tools.recipes.anvil] `tools:anvil` | [tools.items.anvil] ×1 | [materials.items.iron_bar] ×5, [resources.items.log] ×1 | — | [tools.items.workbench] | — | 10 с | 13 | 5. [core.eras.iron] | — |
| [materials.recipes.gold_block] `materials:gold_block` | [materials.items.gold_block] ×1 | [materials.items.gold_bar] ×3 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [materials.recipes.platinum_block] `materials:platinum_block` | [materials.items.platinum_block] ×1 | [materials.items.platinum_bar] ×3 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [materials.recipes.silver_block] `materials:silver_block` | [materials.items.silver_block] ×1 | [materials.items.silver_bar] ×3 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.hatch] `tools:hatch` | [tools.items.hatch] ×1 | [materials.items.planks] ×3 | — | [tools.items.workbench] | — | 4 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.hatch_2x2] `tools:hatch_2x2` | [tools.items.hatch_2x2] ×1 | [materials.items.planks] ×10 | — | [tools.items.workbench] | — | 8 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.fur_hat] `tools:fur_hat` | [tools.items.fur_hat] ×1 | [animals.items.hide] ×1, [materials.items.cord] ×1 | — | [tools.items.workbench] | [tool.needle] (износ 1) | 6 с | 4 | 1. [core.eras.primitive] | — |
| [tools.recipes.fur_coat] `tools:fur_coat` | [tools.items.fur_coat] ×1 | [animals.items.hide] ×3, [materials.items.leather] ×1, [materials.items.cord] ×2 | — | [tools.items.workbench] | [tool.needle] (износ 3) | 16 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.leather_trousers] `tools:leather_trousers` | [tools.items.leather_trousers] ×1 | [materials.items.leather] ×2, [materials.items.cord] ×1 | — | [tools.items.workbench] | [tool.needle] (износ 2) | 10 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.fur_boots] `tools:fur_boots` | [tools.items.fur_boots] ×1 | [animals.items.hide] ×1, [materials.items.leather] ×1, [materials.items.cord] ×1 | — | [tools.items.workbench] | [tool.needle] (износ 2) | 8 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.stone_hoe] `tools:stone_hoe` | [tools.items.stone_hoe] ×1 | [resources.items.flint] ×1, [resources.items.branch] ×1, [materials.items.cord] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_hoe] `tools:copper_hoe` | [tools.items.copper_hoe] ×1 | [materials.items.copper_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 5 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.iron_hoe] `tools:iron_hoe` | [tools.items.iron_hoe] ×1 | [materials.items.iron_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.kiln] `tools:kiln` | [tools.items.kiln] ×1 | [resources.items.stone] ×8, [resources.items.clay] ×4 | — | [tools.items.workbench] | — | 10 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.leather_bag] `tools:leather_bag` | [tools.items.leather_bag] ×1 | [materials.items.leather] ×3, [materials.items.cord] ×2 | — | руки | [tool.needle] (износ 2) | 10 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.leather_sling] `tools:leather_sling` | [tools.items.leather_sling] ×1 | [materials.items.leather] ×1, [materials.items.cord] ×1 | — | руки | [tool.needle] (износ 1) | 5 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.loom] `tools:loom` | [tools.items.loom] ×1 | [materials.items.planks] ×6, [resources.items.branch] ×4, [materials.items.cord] ×4 | — | [tools.items.workbench] | — | 10 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.table] `tools:table` | [tools.items.table] ×1 | [materials.items.planks] ×4 | — | [tools.items.workbench] | — | 6 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.stool] `tools:stool` | [tools.items.stool] ×1 | [materials.items.planks] ×2 | — | [tools.items.workbench] | — | 3 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.wooden_bed] `tools:wooden_bed` | [tools.items.wooden_bed] ×1 | [materials.items.planks] ×6, [materials.items.cloth] ×2 | — | [tools.items.workbench] | — | 8 с | 7 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.cupboard] `tools:cupboard` | [tools.items.cupboard] ×1 | [materials.items.planks] ×6 | — | [tools.items.workbench] | — | 8 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.wide_cupboard] `tools:wide_cupboard` | [tools.items.wide_cupboard] ×1 | [materials.items.planks] ×10 | — | [tools.items.workbench] | — | 12 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.barrel] `tools:barrel` | [tools.items.barrel] ×1 | [materials.items.planks] ×4, [materials.items.cord] ×2 | — | [tools.items.workbench] | — | 6 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.rug] `tools:rug` | [tools.items.rug] ×1 | [materials.items.cloth] ×2 | — | [tools.items.loom] | — | 5 с | 7 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.bone_needle] `tools:bone_needle` | [tools.items.bone_needle] ×1 | [animals.items.bone] ×1 | — | руки | [tool.knife] (износ 1) | 3 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.potters_wheel] `tools:potters_wheel` | [tools.items.potters_wheel] ×1 | [materials.items.planks] ×4, [resources.items.stone] ×4, [resources.items.branch] ×2 | — | [tools.items.workbench] | — | 8 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.raw_pot] `tools:raw_pot` | [tools.items.raw_pot] ×1 | [resources.items.clay] ×3 | — | [tools.items.potters_wheel] | — | 5 с | 6 | 1. [core.eras.primitive] | — |
| [materials.recipes.raw_crucible] `materials:raw_crucible` | [materials.items.raw_crucible] ×1 | [resources.items.clay] ×3, [resources.items.sand] ×1 | — | [tools.items.potters_wheel] | — | 5 с | 6 | 1. [core.eras.primitive] | — |
| [tools.recipes.stone_axe] `tools:stone_axe` | [tools.items.stone_axe] ×1 | [resources.items.flint] ×1, [resources.items.branch] ×2, [materials.items.cord] ×1 | — | [tools.items.workbench] | — | 5 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_axe] `tools:copper_axe` | [tools.items.copper_axe] ×1 | [materials.items.copper_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_axe] `tools:bronze_axe` | [tools.items.bronze_axe] ×1 | [materials.items.bronze_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_axe] `tools:iron_axe` | [tools.items.iron_axe] ×1 | [materials.items.iron_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_axe] `tools:steel_axe` | [tools.items.steel_axe] ×1 | [materials.items.steel_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.raft] `tools:raft` | [tools.items.raft] ×1 | [resources.items.log] ×6, [materials.items.cord] ×4 | — | руки | — | 10 с | 4 | 1. [core.eras.primitive] | — |
| [tools.recipes.boat] `tools:boat` | [tools.items.boat] ×1 | [materials.items.planks] ×12, [materials.items.tar] ×2 | — | [tools.items.workbench] | — | 20 с | 9 | 3. [core.eras.bronze] | — |
| [tools.recipes.oars] `tools:oars` | [tools.items.oars] ×1 | [materials.items.planks] ×3 | — | [tools.items.workbench] | — | 6 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.composite_bow] `tools:composite_bow` | [tools.items.composite_bow] ×1 | [tools.items.wooden_bow] ×1, [animals.items.bone] ×2, [materials.items.bone_glue] ×1, [materials.items.leather] ×1 | — | [tools.items.workbench] | — | 10 с | 9 | 3. [core.eras.bronze] | — |
| [tools.recipes.arrow_from_bone] `tools:arrow_from_bone` | [tools.items.arrow] ×4 | [resources.items.branch] ×1, [animals.items.bone] ×1, [resources.items.fiber] ×1 | — | [tools.items.workbench] | — | 4 с | 3 | 1. [core.eras.primitive] | [tools.recipes.arrow] `tools:arrow` |
| [tools.recipes.flint_knife] `tools:flint_knife` | [tools.items.flint_knife] ×1 | [resources.items.flint] ×1, [resources.items.branch] ×1, [materials.items.cord] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_knife] `tools:copper_knife` | [tools.items.copper_knife] ×1 | [materials.items.copper_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 5 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_knife] `tools:bronze_knife` | [tools.items.bronze_knife] ×1 | [materials.items.bronze_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 5 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_knife] `tools:iron_knife` | [tools.items.iron_knife] ×1 | [materials.items.iron_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_knife] `tools:steel_knife` | [tools.items.steel_knife] ×1 | [materials.items.steel_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 5 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.lantern] `tools:lantern` | [tools.items.lantern] ×1 | [materials.items.glass] ×2, [materials.items.copper_bar] ×1, [materials.items.tar] ×1 | — | [tools.items.workbench] | — | 8 с | 9 | 3. [core.eras.bronze] | — |
| [tools.recipes.stone_pickaxe] `tools:stone_pickaxe` | [tools.items.stone_pickaxe] ×1 | [resources.items.flint] ×2, [resources.items.branch] ×2, [materials.items.cord] ×1 | — | [tools.items.workbench] | — | 6 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.wooden_pickaxe] `tools:wooden_pickaxe` | [tools.items.wooden_pickaxe] ×1 | [resources.items.branch] ×3, [materials.items.cord] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_pickaxe] `tools:copper_pickaxe` | [tools.items.copper_pickaxe] ×1 | [materials.items.copper_bar] ×3, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 7 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_pickaxe] `tools:bronze_pickaxe` | [tools.items.bronze_pickaxe] ×1 | [materials.items.bronze_bar] ×3, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 7 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_pickaxe] `tools:iron_pickaxe` | [tools.items.iron_pickaxe] ×1 | [materials.items.iron_bar] ×3, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 7 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_pickaxe] `tools:steel_pickaxe` | [tools.items.steel_pickaxe] ×1 | [materials.items.steel_bar] ×3, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 7 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.stone_scythe] `tools:stone_scythe` | [tools.items.stone_scythe] ×1 | [resources.items.flint] ×2, [resources.items.branch] ×2, [materials.items.cord] ×2 | — | [tools.items.workbench] | — | 6 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.wooden_scythe] `tools:wooden_scythe` | [tools.items.wooden_scythe] ×1 | [resources.items.branch] ×3, [materials.items.cord] ×2 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_scythe] `tools:copper_scythe` | [tools.items.copper_scythe] ×1 | [materials.items.copper_bar] ×2, [materials.items.planks] ×2 | — | [tools.items.workbench] | — | 7 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_scythe] `tools:bronze_scythe` | [tools.items.bronze_scythe] ×1 | [materials.items.bronze_bar] ×2, [materials.items.planks] ×2 | — | [tools.items.workbench] | — | 7 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_scythe] `tools:iron_scythe` | [tools.items.iron_scythe] ×1 | [materials.items.iron_bar] ×2, [materials.items.planks] ×2 | — | [tools.items.anvil] | — | 7 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_scythe] `tools:steel_scythe` | [tools.items.steel_scythe] ×1 | [materials.items.steel_bar] ×2, [materials.items.planks] ×2 | — | [tools.items.anvil] | — | 7 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.wooden_shovel] `tools:wooden_shovel` | [tools.items.wooden_shovel] ×1 | [materials.items.planks] ×2, [resources.items.branch] ×1 | — | [tools.items.workbench] | — | 5 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_shovel] `tools:copper_shovel` | [tools.items.copper_shovel] ×1 | [materials.items.copper_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_shovel] `tools:bronze_shovel` | [tools.items.bronze_shovel] ×1 | [materials.items.bronze_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_shovel] `tools:iron_shovel` | [tools.items.iron_shovel] ×1 | [materials.items.iron_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_shovel] `tools:steel_shovel` | [tools.items.steel_shovel] ×1 | [materials.items.steel_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.stone_sickle] `tools:stone_sickle` | [tools.items.stone_sickle] ×1 | [resources.items.flint] ×2, [resources.items.branch] ×1, [materials.items.cord] ×1 | — | руки | — | 4 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_sickle] `tools:copper_sickle` | [tools.items.copper_sickle] ×1 | [materials.items.copper_bar] ×1, [resources.items.branch] ×1 | — | [tools.items.workbench] | — | 5 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.iron_sickle] `tools:iron_sickle` | [tools.items.iron_sickle] ×1 | [materials.items.iron_bar] ×1, [resources.items.branch] ×1 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.sign] `tools:sign` | [tools.items.sign] ×1 | [materials.items.planks] ×1, [resources.items.branch] ×1 | — | руки | — | 3 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.signpost] `tools:signpost` | [tools.items.signpost] ×1 | [materials.items.planks] ×1, [resources.items.branch] ×2 | — | руки | — | 4 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.notice_board] `tools:notice_board` | [tools.items.notice_board] ×1 | [materials.items.planks] ×3 | — | [tools.items.workbench] | — | 5 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.flint_spear] `tools:flint_spear` | [tools.items.flint_spear] ×1 | [resources.items.branch] ×2, [resources.items.flint] ×1, [materials.items.cord] ×1 | — | руки | — | 5 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.bronze_spear] `tools:bronze_spear` | [tools.items.bronze_spear] ×1 | [materials.items.bronze_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 5 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_spear] `tools:iron_spear` | [tools.items.iron_spear] ×1 | [materials.items.iron_bar] ×1, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 5 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.wooden_sword] `tools:wooden_sword` | [tools.items.wooden_sword] ×1 | [resources.items.branch] ×2, [materials.items.cord] ×1 | — | руки | — | 5 с | 2 | 1. [core.eras.primitive] | — |
| [tools.recipes.stone_sword] `tools:stone_sword` | [tools.items.stone_sword] ×1 | [resources.items.flint] ×2, [resources.items.branch] ×1, [materials.items.cord] ×1 | — | [tools.items.workbench] | — | 5 с | 3 | 1. [core.eras.primitive] | — |
| [tools.recipes.copper_sword] `tools:copper_sword` | [tools.items.copper_sword] ×1 | [materials.items.copper_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.bronze_sword] `tools:bronze_sword` | [tools.items.bronze_sword] ×1 | [materials.items.bronze_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.workbench] | — | 6 с | 10 | 4. [core.eras.alloy] | — |
| [tools.recipes.iron_sword] `tools:iron_sword` | [tools.items.iron_sword] ×1 | [materials.items.iron_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 5. [core.eras.iron] | — |
| [tools.recipes.steel_sword] `tools:steel_sword` | [tools.items.steel_sword] ×1 | [materials.items.steel_bar] ×2, [materials.items.planks] ×1 | — | [tools.items.anvil] | — | 6 с | 14 | 6. [core.eras.steel] | — |
| [tools.recipes.tar_torch] `tools:tar_torch` | [tools.items.tar_torch] ×1 | [resources.items.branch] ×1, [materials.items.cloth] ×1, [materials.items.tar] ×1 | — | руки | — | 3 с | 9 | 3. [core.eras.bronze] | — |
| [tools.recipes.watering_can] `tools:watering_can` | [tools.items.watering_can] ×1 | [materials.items.planks] ×3, [materials.items.cord] ×1 | — | [tools.items.workbench] | — | 5 с | 5 | 1. [core.eras.primitive] | — |
| [tools.recipes.waterskin] `tools:waterskin` | [tools.items.waterskin] ×1 | [materials.items.leather] ×1, [materials.items.cord] ×1 | — | руки | [tool.needle] (износ 1) | 6 с | 5 | 2. [core.eras.bone_leather] | — |
| [tools.recipes.window] `tools:window` | [tools.items.window] ×1 | [materials.items.planks] ×1, [materials.items.glass] ×2 | — | [tools.items.workbench] | — | 4 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.window_1x2] `tools:window_1x2` | [tools.items.window_1x2] ×1 | [materials.items.planks] ×2, [materials.items.glass] ×4 | — | [tools.items.workbench] | — | 5 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.window_2x1] `tools:window_2x1` | [tools.items.window_2x1] ×1 | [materials.items.planks] ×2, [materials.items.glass] ×4 | — | [tools.items.workbench] | — | 5 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.window_2x2] `tools:window_2x2` | [tools.items.window_2x2] ×1 | [materials.items.planks] ×3, [materials.items.glass] ×8 | — | [tools.items.workbench] | — | 7 с | 7 | 3. [core.eras.bronze] | — |
| [tools.recipes.window_3x2] `tools:window_3x2` | [tools.items.window_3x2] ×1 | [materials.items.planks] ×4, [materials.items.glass] ×12 | — | [tools.items.workbench] | — | 9 с | 7 | 3. [core.eras.bronze] | — |

## Переработка (`refine`)

| Рецепт | Делает | Тратит | В сумке | Станок | Инструменты | Время | Глубина | Эпоха | Альтернативы |
|---|---|---|---|---|---|---|---|---|---|
| [materials.recipes.cord] `materials:cord` | [materials.items.cord] ×1 | [resources.items.fiber] ×3 | — | руки | — | 2 с | 1 | 0. [core.eras.foraging] | — |
| [materials.recipes.log_wall] `materials:log_wall` | [materials.items.log_wall] ×2 | [resources.items.log] ×1 | — | руки | [tool.axe] | 3 с | 4 | 1. [core.eras.primitive] | — |
| [materials.recipes.cut_stone] `materials:cut_stone` | [materials.items.cut_stone] ×1 | [resources.items.stone] ×2 | — | [tools.items.workbench] | [tool.pickaxe] | 4 с | 3 | 1. [core.eras.primitive] | — |
| [animals.recipes.jerky] `animals:jerky` | [animals.items.jerky] ×1 | [animals.items.raw_meat] ×1 | — | [tools.items.drying_rack] | — | 10 с | 4 | 2. [core.eras.bone_leather] | — |
| [materials.recipes.leather] `materials:leather` | [materials.items.leather] ×1 | [animals.items.hide] ×1, [animals.items.fat] ×1 | — | [tools.items.drying_rack] | — | 12 с | 4 | 2. [core.eras.bone_leather] | — |
| [plants.recipes.flour] `plants:flour` | [plants.items.flour] ×1 | [plants.items.grain] ×4 | — | руки | — | 4 с | 1 | 0. [core.eras.foraging] | — |
| [tools.recipes.cloth_from_cord] `tools:cloth_from_cord` | [materials.items.cloth] ×1 | [materials.items.cord] ×4 | — | [tools.items.loom] | — | 6 с | 6 | 2. [core.eras.bone_leather] | [animals.recipes.cloth_from_wool_yarn] `animals:cloth_from_wool_yarn`, [plants.recipes.cloth] `plants:cloth` |
| [animals.recipes.wool_yarn] `animals:wool_yarn` | [animals.items.wool_yarn] ×1 | [animals.items.rabbit_fluff] ×3 | — | руки | — | 3 с | 1 | 0. [core.eras.foraging] | — |
| [animals.recipes.cloth_from_wool_yarn] `animals:cloth_from_wool_yarn` | [materials.items.cloth] ×2 | [animals.items.wool_yarn] ×4 | — | [tools.items.loom] | — | 6 с | 6 | 2. [core.eras.bone_leather] | [tools.recipes.cloth_from_cord] `tools:cloth_from_cord`, [plants.recipes.cloth] `plants:cloth` |
| [plants.recipes.linen_thread] `plants:linen_thread` | [plants.items.linen_thread] ×1 | [plants.items.flax_stalks] ×3 | — | руки | — | 3 с | 1 | 0. [core.eras.foraging] | — |
| [plants.recipes.cloth] `plants:cloth` | [materials.items.cloth] ×2 | [plants.items.linen_thread] ×4 | — | [tools.items.loom] | — | 6 с | 6 | 2. [core.eras.bone_leather] | [tools.recipes.cloth_from_cord] `tools:cloth_from_cord`, [animals.recipes.cloth_from_wool_yarn] `animals:cloth_from_wool_yarn` |
| [tools.recipes.planks] `tools:planks` | [materials.items.planks] ×2 | [resources.items.log] ×1 | — | [tools.items.workbench] | [tool.axe] | 3 с | 4 | 1. [core.eras.primitive] | — |

## Плавка и обжиг (`smelt`)

| Рецепт | Делает | Тратит | В сумке | Станок | Инструменты | Время | Глубина | Эпоха | Альтернативы |
|---|---|---|---|---|---|---|---|---|---|
| [tools.recipes.copper_bar] `tools:copper_bar` | [materials.items.copper_bar] ×1 | [materials.items.copper_ore] ×2, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 6 с | 6 | 3. [core.eras.bronze] | — |
| [materials.recipes.glass] `materials:glass` | [materials.items.glass] ×1 | [resources.items.sand] ×2, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 6 с | 6 | 3. [core.eras.bronze] | — |
| [materials.recipes.iron_bloom] `materials:iron_bloom` | [materials.items.iron_bloom] ×1 | [materials.items.iron_ore] ×2, [materials.items.charcoal] ×1 | — | [tools.items.bloomery] | — | 10 с | 11 | 5. [core.eras.iron] | — |
| [materials.recipes.iron_bar] `materials:iron_bar` | [materials.items.iron_bar] ×2 | [materials.items.iron_bloom] ×1, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 6 с | 12 | 5. [core.eras.iron] | — |
| [materials.recipes.tin_bar] `materials:tin_bar` | [materials.items.tin_bar] ×1 | [materials.items.tin_ore] ×2, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 6 с | 8 | 3. [core.eras.bronze] | — |
| [materials.recipes.gold_bar] `materials:gold_bar` | [materials.items.gold_bar] ×1 | [materials.items.gold_ore] ×2, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 8 с | 11 | 4. [core.eras.alloy] | — |
| [materials.recipes.platinum_bar] `materials:platinum_bar` | [materials.items.platinum_bar] ×1 | [materials.items.platinum_ore] ×3, [materials.items.charcoal] ×2 | — | [tools.items.forge] | — | 12 с | 11 | 4. [core.eras.alloy] | — |
| [materials.recipes.silver_bar] `materials:silver_bar` | [materials.items.silver_bar] ×1 | [materials.items.silver_ore] ×2, [materials.items.charcoal] ×1 | — | [tools.items.forge] | — | 7 с | 11 | 4. [core.eras.alloy] | — |
| [tools.recipes.brick] `tools:brick` | [materials.items.brick] ×1 | [resources.items.clay] ×1 | — | [tools.items.kiln] | — | 4 с | 4 | 3. [core.eras.bronze] | — |
| [tools.recipes.charcoal] `tools:charcoal` | [materials.items.charcoal] ×2 | [resources.items.log] ×1 | — | [tools.items.kiln] | — | 6 с | 4 | 3. [core.eras.bronze] | — |
| [tools.recipes.pot] `tools:pot` | [tools.items.pot] ×1 | [tools.items.raw_pot] ×1 | — | [tools.items.kiln] | — | 6 с | 7 | 3. [core.eras.bronze] | — |
| [materials.recipes.crucible] `materials:crucible` | [materials.items.crucible] ×1 | [materials.items.raw_crucible] ×1 | — | [tools.items.kiln] | — | 8 с | 7 | 3. [core.eras.bronze] | — |
| [materials.recipes.bronze_bar] `materials:bronze_bar` | [materials.items.bronze_bar] ×3 | [materials.items.copper_bar] ×3, [materials.items.tin_bar] ×1, [materials.items.charcoal] ×1 | [materials.items.crucible] ×1 | [tools.items.forge] | — | 8 с | 9 | 3. [core.eras.bronze] | — |
| [materials.recipes.steel_bar] `materials:steel_bar` | [materials.items.steel_bar] ×1 | [materials.items.iron_bar] ×1, [materials.items.charcoal] ×1 | [materials.items.crucible] ×1 | [tools.items.bloomery] | — | 12 с | 13 | 5. [core.eras.iron] | — |
| [materials.recipes.tar] `materials:tar` | [materials.items.tar] ×1; побочно: [materials.items.charcoal] ×1 (50%) | [resources.items.log] ×2 | [tools.items.pot] ×1 | [tools.items.kiln] | — | 8 с | 8 | 3. [core.eras.bronze] | — |

## Готовка (`cook`)

| Рецепт | Делает | Тратит | В сумке | Станок | Инструменты | Время | Глубина | Эпоха | Альтернативы |
|---|---|---|---|---|---|---|---|---|---|
| [plants.recipes.fried_mushrooms] `plants:fried_mushrooms` | [plants.items.fried_mushrooms] ×1 | [plants.items.mushroom] ×4 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 4 с | 1 | 0. [core.eras.foraging] | — |
| [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach` | [animals.items.roasted_fish] ×1 | [animals.items.roach] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike` | [animals.items.roasted_fish] ×1 | [animals.items.pike] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon` | [animals.items.roasted_fish] ×1 | [animals.items.salmon] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod` | [animals.items.roasted_fish] ×1 | [animals.items.cod] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish` | [animals.items.roasted_fish] ×1 | [animals.items.parrotfish] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish` | [animals.items.roasted_fish] ×1 | [animals.items.catfish] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` |
| [animals.recipes.roasted_fish_from_perch] `animals:roasted_fish_from_perch` | [animals.items.roasted_fish] ×1 | [animals.items.perch] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 3 с | 3 | 1. [core.eras.primitive] | [animals.recipes.roasted_fish_from_roach] `animals:roasted_fish_from_roach`, [animals.recipes.roasted_fish_from_pike] `animals:roasted_fish_from_pike`, [animals.recipes.roasted_fish_from_salmon] `animals:roasted_fish_from_salmon`, [animals.recipes.roasted_fish_from_cod] `animals:roasted_fish_from_cod`, [animals.recipes.roasted_fish_from_parrotfish] `animals:roasted_fish_from_parrotfish`, [animals.recipes.roasted_fish_from_catfish] `animals:roasted_fish_from_catfish` |
| [animals.recipes.roasted_meat] `animals:roasted_meat` | [animals.items.roasted_meat] ×1 | [animals.items.raw_meat] ×1, [resources.items.branch] ×1 | — | [core.items.campfire] (или [tools.items.fireplace]) | — | 4 с | 2 | 0. [core.eras.foraging] | — |
| [plants.recipes.flatbread] `plants:flatbread` | [plants.items.flatbread] ×1 | [plants.items.flour] ×2 | — | [tools.items.kiln] | — | 5 с | 4 | 3. [core.eras.bronze] | — |
| [materials.recipes.bone_glue] `materials:bone_glue` | [materials.items.bone_glue] ×1 | [animals.items.bone] ×3, [resources.items.branch] ×1 | [tools.items.pot] ×1 | [core.items.campfire] (или [tools.items.fireplace]) | — | 6 с | 8 | 3. [core.eras.bronze] | — |
| [plants.recipes.roasted_acorns] `plants:roasted_acorns` | [plants.items.roasted_acorns] ×1 | [plants.items.acorn] ×6 | [tools.items.pot] ×1 | [core.items.campfire] (или [tools.items.fireplace]) | — | 5 с | 8 | 3. [core.eras.bronze] | — |
