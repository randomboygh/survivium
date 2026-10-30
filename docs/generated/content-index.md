# Реестр сущностей

Создаёт `tools/content_report.gd` из данных всех модов, как их грузит игра; руками не править. После
правки данных: `godot --headless --path . --script res://tools/content_report.gd`; CI проверяет, что
реестр свежий. Правила системы — [BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md).

Категория — у предметов та, что выводит игра (у рецепта — его предмета), у остальных их роль или вид.
Бандл — где запись определена; «→» — кто её заменил (`replaces`), «патчи» — кто поправил.
Связи — сколько записей называет эта и сколько называют её (поля-ссылки с типом связи `rel`).
Проверка — что говорят о записи проверки загрузки и графа: «ок», ошибки или предупреждения. Граф —
[content-graph.md](content-graph.md), что нашли проверки — [content-checks.md](content-checks.md).

## Моды и бандлы

- `core` Основа
- `animals` Животные: `animals/bear` Медведь, `animals/boar` Кабан, `animals/butterfly` Бабочка, `animals/cat` Дикая кошка, `animals/crow` Ворона, `animals/deer` Олень, `animals/duck` Утка, `animals/fox` Лиса, `animals/frog` Лягушка, `animals/hedgehog` Ёж, `animals/owl` Сова, `animals/perch` Окунь, `animals/rabbit` Заяц, `animals/sparrow` Воробей, `animals/squirrel` Белка, `animals/wolf` Волк
- `biomes` Биомы: `biomes/beach` Берег, `biomes/birch_grove` Берёзовая роща, `biomes/desert` Пустыня, `biomes/forest` Лес, `biomes/meadow` Луг, `biomes/pine_wood` Бор, `biomes/plateau` Плато, `biomes/rock` Скалы, `biomes/sea` Море, `biomes/steppe` Степь, `biomes/swamp` Болото, `biomes/taiga` Тайга, `biomes/tundra` Тундра
- `materials` Материалы: `materials/brick` Кирпич, `materials/charcoal` Уголь, `materials/copper` Медь, `materials/cord` Верёвка, `materials/planks` Доски
- `music` Музыка
- `plants` Растения: `plants/apple` Яблоня, `plants/birch` Берёза, `plants/bird_cherry` Черёмуха, `plants/blueberry` Черника, `plants/cherry` Вишня, `plants/cranberry` Клюква, `plants/currant` Смородина, `plants/deadwood` Сухое дерево, `plants/ears` Колоски, `plants/fern` Папоротник, `plants/fir` Пихта, `plants/grass` Травы, `plants/larch` Лиственница, `plants/linden` Липа, `plants/maple` Клён, `plants/moss` Мох, `plants/mushrooms` Грибы, `plants/nettle` Крапива, `plants/oak` Дуб, `plants/pine` Сосна, `plants/poplar` Тополь, `plants/raspberry` Малина, `plants/reeds` Тростник, `plants/rosehip` Шиповник, `plants/rowan` Рябина, `plants/shrub` Куст, `plants/spruce` Ель, `plants/willow` Ива, `plants/wood` Древесина
- `resources` Ресурсы: `resources/fiber` Волокно, `resources/soil` Грунт, `resources/stone` Камень, `resources/wood` Дерево
- `sounds` Звуки: `sounds/nature` Природа, `sounds/player` Игрок, `sounds/ui` Интерфейс
- `tools` Инструменты и крафт: `tools/axe` Топор, `tools/chest` Сундук, `tools/forge` Горн, `tools/kiln` Печь для обжига, `tools/pickaxe` Кирка, `tools/scythe` Коса, `tools/shovel` Лопата, `tools/sword` Меч, `tools/torch` Факел, `tools/workbench` Верстак

## Предметы (`items`, 56)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:campfire` | Костёр | Станки |  | `core` | 0 / 3 | предупреждения: 1 |
| `materials:brick` | Кирпич | Блоки |  | `materials/brick` | 1 / 3 | ок |
| `materials:charcoal` | Уголь | Материалы |  | `materials/charcoal` | 0 / 2 | ок |
| `materials:copper_ore` | Медная руда | Материалы |  | `materials/copper` | 0 / 2 | ок |
| `materials:copper_bar` | Медный слиток | Материалы |  | `materials/copper` | 0 / 11 | ок |
| `materials:planks` | Доски | Блоки |  | `materials/planks` | 1 / 16 | ок |
| `plants:blueberry` | Черника | Еда |  | `plants/blueberry` | 0 / 1 | предупреждения: 1 |
| `plants:blueberry_bush` | Кустик черники | Посадки |  | `plants/blueberry` | 1 / 1 | ок |
| `plants:cranberry` | Клюква | Еда |  | `plants/cranberry` | 0 / 1 | предупреждения: 1 |
| `plants:currant` | Смородина | Еда |  | `plants/currant` | 0 / 1 | предупреждения: 1 |
| `plants:currant_bush` | Куст смородины | Посадки |  | `plants/currant` | 1 / 1 | ок |
| `plants:grass_seeds` | Семена трав | Посадки |  | `plants/grass` | 1 / 2 | ок |
| `plants:mushroom` | Гриб | Еда |  | `plants/mushrooms` | 0 / 2 | ок |
| `plants:glow_mushroom` | Светящийся гриб | Еда |  | `plants/mushrooms` | 0 / 1 | ок |
| `plants:fried_mushrooms` | Жареные грибы | Еда |  | `plants/mushrooms` | 0 / 1 | ок |
| `plants:raspberry` | Малина | Еда |  | `plants/raspberry` | 0 / 1 | ок |
| `plants:raspberry_bush` | Куст малины | Посадки |  | `plants/raspberry` | 1 / 1 | ок |
| `plants:rosehip` | Шиповник | Еда |  | `plants/rosehip` | 0 / 1 | предупреждения: 1 |
| `plants:rosehip_bush` | Куст шиповника | Посадки |  | `plants/rosehip` | 1 / 1 | ок |
| `plants:shrub_bush` | Куст | Посадки |  | `plants/shrub` | 1 / 1 | ок |
| `resources:fiber` | Волокно | Материалы |  | `resources/fiber` | 0 / 11 | ок |
| `materials:cord` | Верёвка | Материалы |  | `materials/cord` | 0 / 12 | ок |
| `plants:moss` | Мох | Материалы |  | `plants/moss` | 0 / 2 | ок |
| `plants:bandage` | Бинт | Лечение |  | `plants/moss` | 0 / 1 | ок |
| `resources:dirt` | Земля | Блоки |  | `resources/soil` | 1 / 2 | ок |
| `resources:sand` | Песок | Блоки |  | `resources/soil` | 1 / 1 | ок |
| `resources:clay` | Глина | Блоки |  | `resources/soil` | 1 / 4 | ок |
| `resources:stone` | Камень | Блоки |  | `resources/stone` | 1 / 4 | ок |
| `resources:flint` | Кремень | Материалы |  | `resources/stone` | 0 / 11 | ок |
| `resources:branch` | Ветка | Материалы |  | `resources/wood` | 0 / 30 | ок |
| `resources:log` | Бревно | Блоки |  | `resources/wood`; патчи: `plants/wood` | 1 / 18 | ок |
| `plants:apple` | Яблоко | Еда |  | `plants/apple` | 0 / 1 | ок |
| `plants:acorn` | Жёлудь | Материалы |  | `plants/oak` | 0 / 1 | предупреждения: 1 |
| `plants:rowan` | Рябина | Еда |  | `plants/rowan` | 0 / 1 | предупреждения: 1 |
| `plants:cone` | Шишка | Материалы |  | `plants/spruce` | 0 / 2 | предупреждения: 1 |
| `tools:torch` | Факел | Материалы |  | `tools/torch` | 0 / 1 | ок |
| `tools:workbench` | Верстак | Станки |  | `tools/workbench` | 0 / 18 | ок |
| `tools:stone_axe` | Каменный топор | Инструменты |  | `tools/axe` | 2 / 1 | ок |
| `tools:copper_axe` | Медный топор | Инструменты |  | `tools/axe` | 1 / 1 | ок |
| `tools:chest` | Сундук | Станки |  | `tools/chest` | 0 / 2 | ок |
| `tools:forge` | Горн | Станки |  | `tools/forge` | 0 / 2 | предупреждения: 1 |
| `tools:kiln` | Печь для обжига | Станки |  | `tools/kiln` | 0 / 4 | ок |
| `plants:grain` | Зерно | Посадки |  | `plants/ears` | 2 / 2 | ок |
| `plants:flour` | Мука | Материалы |  | `plants/ears` | 0 / 2 | ок |
| `plants:flatbread` | Лепёшка | Еда |  | `plants/ears` | 0 / 1 | ок |
| `tools:stone_pickaxe` | Каменная кирка | Инструменты |  | `tools/pickaxe` | 2 / 1 | ок |
| `tools:wooden_pickaxe` | Деревянная кирка | Инструменты |  | `tools/pickaxe` | 1 / 1 | ок |
| `tools:copper_pickaxe` | Медная кирка | Инструменты |  | `tools/pickaxe` | 1 / 1 | ок |
| `tools:stone_scythe` | Каменная коса | Инструменты |  | `tools/scythe` | 2 / 1 | ок |
| `tools:wooden_scythe` | Деревянная коса | Инструменты |  | `tools/scythe` | 1 / 1 | ок |
| `tools:copper_scythe` | Медная коса | Инструменты |  | `tools/scythe` | 1 / 1 | ок |
| `tools:wooden_shovel` | Деревянная лопата | Инструменты |  | `tools/shovel` | 1 / 1 | ок |
| `tools:copper_shovel` | Медная лопата | Инструменты |  | `tools/shovel` | 1 / 1 | ок |
| `tools:wooden_sword` | Деревянный меч | Инструменты |  | `tools/sword` | 1 / 1 | ок |
| `tools:stone_sword` | Каменный меч | Инструменты |  | `tools/sword` | 2 / 1 | ок |
| `tools:copper_sword` | Медный меч | Инструменты |  | `tools/sword` | 1 / 1 | ок |

## Рецепты (`recipes`, 28)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:fried_mushrooms` | Жареные грибы | Еда |  | `plants/mushrooms` | 3 / 0 | ок |
| `materials:cord` | Верёвка | Материалы |  | `materials/cord` | 2 / 0 | ок |
| `plants:bandage` | Бинт | Лечение |  | `plants/moss` | 3 / 0 | ок |
| `resources:campfire` | Костёр | Станки |  | `resources/wood` | 3 / 0 | ок |
| `tools:torch` | Факел | Материалы |  | `tools/torch` | 3 / 0 | ок |
| `tools:workbench` | Верстак | Станки |  | `tools/workbench` | 3 / 0 | ок |
| `tools:stone_axe` | Каменный топор | Инструменты |  | `tools/axe` | 5 / 0 | ок |
| `tools:planks` | Доски | Блоки |  | `tools/axe` | 3 / 0 | ок |
| `tools:copper_axe` | Медный топор | Инструменты |  | `tools/axe` | 4 / 0 | ок |
| `tools:chest` | Сундук | Станки |  | `tools/chest` | 3 / 0 | ок |
| `tools:forge` | Горн | Станки |  | `tools/forge` | 5 / 0 | ок |
| `tools:copper_bar` | Медный слиток | Материалы |  | `tools/forge` | 4 / 0 | ок |
| `tools:kiln` | Печь для обжига | Станки |  | `tools/kiln` | 4 / 0 | ок |
| `tools:brick` | Кирпич | Блоки |  | `tools/kiln` | 3 / 0 | ок |
| `tools:charcoal` | Уголь | Материалы |  | `tools/kiln` | 3 / 0 | ок |
| `plants:flour` | Мука | Материалы |  | `plants/ears` | 2 / 0 | ок |
| `plants:flatbread` | Лепёшка | Еда |  | `plants/ears` | 3 / 0 | ок |
| `tools:stone_pickaxe` | Каменная кирка | Инструменты |  | `tools/pickaxe` | 5 / 0 | ок |
| `tools:wooden_pickaxe` | Деревянная кирка | Инструменты |  | `tools/pickaxe` | 4 / 0 | ок |
| `tools:copper_pickaxe` | Медная кирка | Инструменты |  | `tools/pickaxe` | 4 / 0 | ок |
| `tools:stone_scythe` | Каменная коса | Инструменты |  | `tools/scythe` | 5 / 0 | ок |
| `tools:wooden_scythe` | Деревянная коса | Инструменты |  | `tools/scythe` | 5 / 0 | ок |
| `tools:copper_scythe` | Медная коса | Инструменты |  | `tools/scythe` | 4 / 0 | ок |
| `tools:wooden_shovel` | Деревянная лопата | Инструменты |  | `tools/shovel` | 4 / 0 | ок |
| `tools:copper_shovel` | Медная лопата | Инструменты |  | `tools/shovel` | 4 / 0 | ок |
| `tools:wooden_sword` | Деревянный меч | Инструменты |  | `tools/sword` | 4 / 0 | ок |
| `tools:stone_sword` | Каменный меч | Инструменты |  | `tools/sword` | 5 / 0 | ок |
| `tools:copper_sword` | Медный меч | Инструменты |  | `tools/sword` | 4 / 0 | ок |

## Материалы ячеек (`materials`, 13)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:air` | Воздух |  |  | `core` | 0 / 0 | ок |
| `core:grass` | Трава |  |  | `core` | 4 / 2 | ок |
| `core:dirt` | Земля |  |  | `core` | 2 / 2 | ок |
| `core:stone` | Камень |  |  | `core` | 1 / 1 | ок |
| `core:water` | Вода |  |  | `core` | 0 / 0 | ок |
| `materials:brick` | Кирпич |  |  | `materials/brick` | 1 / 1 | ок |
| `materials:copper_ore` | Медная руда | ore |  | `materials/copper` | 1 / 0 | ок |
| `materials:planks` | Доски |  |  | `materials/planks` | 1 / 1 | ок |
| `resources:sand` | Песок | beach |  | `resources/soil` | 2 / 1 | ок |
| `resources:clay` | Глина | bank |  | `resources/soil` | 1 / 1 | ок |
| `resources:scree` | Осыпь | scree |  | `resources/stone` | 2 / 0 | ок |
| `plants:log` | Бревно | trunk |  | `plants/wood` | 1 / 1 | ок |
| `plants:leaves` | Листва | crown |  | `plants/wood` | 0 / 0 | ок |

## Деревья (`trees`, 15)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:apple` | Яблоня | broad |  | `plants/apple` | 3 / 1 | ок |
| `plants:birch` | Берёза | broad |  | `plants/birch` | 2 / 2 | ок |
| `plants:bird_cherry` | Черёмуха | broad |  | `plants/bird_cherry` | 2 / 4 | ок |
| `plants:cherry` | Вишня | broad |  | `plants/cherry` | 2 / 1 | ок |
| `plants:deadwood` | Сухое дерево | broad |  | `plants/deadwood` | 2 / 4 | ок |
| `plants:fir` | Пихта | needles |  | `plants/fir` | 2 / 1 | ок |
| `plants:larch` | Лиственница | needles |  | `plants/larch` | 2 / 2 | ок |
| `plants:linden` | Липа | broad |  | `plants/linden` | 2 / 2 | ок |
| `plants:maple` | Клён | broad |  | `plants/maple` | 2 / 1 | ок |
| `plants:oak` | Дуб | broad |  | `plants/oak` | 3 / 5 | ок |
| `plants:pine` | Сосна | needles |  | `plants/pine` | 3 / 1 | ок |
| `plants:poplar` | Тополь | broad |  | `plants/poplar` | 2 / 2 | ок |
| `plants:rowan` | Рябина | broad |  | `plants/rowan` | 3 / 2 | ок |
| `plants:spruce` | Ель | needles |  | `plants/spruce` | 3 / 4 | ок |
| `plants:willow` | Ива | broad |  | `plants/willow` | 2 / 1 | ок |

## Кусты (`bushes`, 5)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:blueberry` | Черника |  |  | `plants/blueberry` | 3 / 5 | ок |
| `plants:currant` | Смородина |  |  | `plants/currant` | 3 / 2 | ок |
| `plants:raspberry` | Малина |  |  | `plants/raspberry` | 3 / 3 | ок |
| `plants:rosehip` | Шиповник |  |  | `plants/rosehip` | 3 / 3 | ок |
| `plants:shrub` | Куст |  |  | `plants/shrub` | 2 / 11 | ок |

## Растения (`plants`, 12)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:cranberry` | Клюква | custom |  | `plants/cranberry` | 1 / 0 | ок |
| `plants:fern` | Папоротник | custom |  | `plants/fern` | 1 / 0 | ок |
| `plants:tuft` | Трава | tuft |  | `plants/grass` | 1 / 2 | ок |
| `plants:tall_grass` | Высокая трава | tall_grass |  | `plants/grass` | 1 / 1 | ок |
| `plants:flowers` | Цветы | flowers |  | `plants/grass` | 1 / 2 | ок |
| `plants:herbs` | Травы | herbs |  | `plants/grass` | 1 / 0 | ок |
| `plants:mushrooms` | Грибы | mushrooms |  | `plants/mushrooms` | 1 / 2 | ок |
| `plants:glow_mushrooms` | Светящиеся грибы | glow_mushrooms |  | `plants/mushrooms` | 1 / 0 | ок |
| `plants:nettle` | Крапива | custom |  | `plants/nettle` | 1 / 0 | ок |
| `plants:reeds` | Тростник | reeds |  | `plants/reeds` | 1 / 0 | ок |
| `plants:moss` | Мох | moss |  | `plants/moss` | 1 / 0 | ок |
| `plants:ears` | Колоски | ears |  | `plants/ears` | 1 / 3 | ок |

## Существа (`creatures`, 17)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:human` | Человек |  |  | `core` | 0 / 0 | ок |
| `animals:bear` | Медведь |  |  | `animals/bear`; патчи: `biomes/pine_wood` | 4 / 0 | ок |
| `animals:boar` | Кабан |  |  | `animals/boar`; патчи: `biomes/pine_wood` | 4 / 0 | ок |
| `animals:butterfly` | Бабочка |  |  | `animals/butterfly` | 1 / 0 | ок |
| `animals:cat` | Дикая кошка |  |  | `animals/cat` | 2 / 0 | ок |
| `animals:crow` | Ворона |  |  | `animals/crow` | 1 / 0 | ок |
| `animals:deer` | Олень |  |  | `animals/deer`; патчи: `biomes/birch_grove`, `biomes/steppe` | 7 / 0 | ок |
| `animals:duck` | Утка |  |  | `animals/duck` | 0 / 0 | ок |
| `animals:fox` | Лиса |  |  | `animals/fox`; патчи: `biomes/birch_grove`, `biomes/steppe` | 5 / 0 | ок |
| `animals:frog` | Лягушка |  |  | `animals/frog` | 0 / 0 | ок |
| `animals:hedgehog` | Ёж |  |  | `animals/hedgehog`; патчи: `biomes/birch_grove` | 3 / 0 | ок |
| `animals:owl` | Сова |  |  | `animals/owl`; патчи: `biomes/birch_grove`, `biomes/pine_wood` | 4 / 0 | ок |
| `animals:perch` | Окунь |  |  | `animals/perch` | 0 / 0 | ок |
| `animals:rabbit` | Заяц |  |  | `animals/rabbit`; патчи: `biomes/birch_grove`, `biomes/steppe` | 6 / 0 | ок |
| `animals:sparrow` | Воробей |  |  | `animals/sparrow` | 1 / 0 | ок |
| `animals:squirrel` | Белка |  |  | `animals/squirrel`; патчи: `biomes/pine_wood` | 4 / 0 | ок |
| `animals:wolf` | Волк |  |  | `animals/wolf`; патчи: `biomes/pine_wood` | 4 / 0 | ок |

## Биомы (`biomes`, 13)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `biomes:beach` | Берег | beach |  | `biomes/beach` | 0 / 0 | ок |
| `biomes:birch_grove` | Берёзовая роща | climate |  | `biomes/birch_grove` | 8 / 5 | ок |
| `biomes:desert` | Пустыня | climate |  | `biomes/desert` | 1 / 0 | ок |
| `biomes:forest` | Лес | climate |  | `biomes/forest` | 10 / 10 | ок |
| `biomes:meadow` | Луг | climate |  | `biomes/meadow` | 9 / 6 | ок |
| `biomes:pine_wood` | Бор | climate |  | `biomes/pine_wood` | 5 / 5 | ок |
| `biomes:plateau` | Плато | plateau |  | `biomes/plateau` | 1 / 0 | ок |
| `biomes:rock` | Скалы | rock |  | `biomes/rock` | 0 / 0 | ок |
| `biomes:sea` | Море | sea |  | `biomes/sea` | 0 / 0 | ок |
| `biomes:steppe` | Степь | climate |  | `biomes/steppe` | 2 / 3 | ок |
| `biomes:swamp` | Болото | swamp |  | `biomes/swamp` | 5 / 1 | ок |
| `biomes:taiga` | Тайга | climate |  | `biomes/taiga` | 7 / 6 | ок |
| `biomes:tundra` | Тундра | climate |  | `biomes/tundra` | 4 / 1 | ок |

## Старт (`starts`, 1)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:default` | Обычный старт |  | Пустые руки, пустая сумка и костёр у точки появления. | `core`; патчи: `tools/chest` | 2 / 0 | ок |

## Звуки (`sounds`, 55)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `animals:bear` | Рёв медведя |  |  | `animals/bear` | 0 / 0 | ок |
| `animals:boar` | Хрюканье кабана |  |  | `animals/boar` | 0 / 0 | ок |
| `animals:cat` | Мяуканье |  |  | `animals/cat` | 0 / 0 | ок |
| `animals:crow` | Карканье |  |  | `animals/crow` | 0 / 0 | ок |
| `animals:deer` | Крик оленя |  |  | `animals/deer` | 0 / 0 | ок |
| `animals:duck` | Кряканье |  |  | `animals/duck` | 0 / 0 | ок |
| `animals:fox` | Лай лисы |  |  | `animals/fox` | 0 / 0 | ок |
| `animals:frog` | Кваканье |  |  | `animals/frog` | 0 / 0 | ок |
| `animals:hedgehog` | Фырканье ежа |  |  | `animals/hedgehog` | 0 / 0 | ок |
| `animals:owl` | Сова |  |  | `animals/owl` | 0 / 0 | ок |
| `animals:rabbit` | Писк кролика |  |  | `animals/rabbit` | 0 / 0 | ок |
| `animals:sparrow` | Чириканье |  |  | `animals/sparrow` | 0 / 0 | ок |
| `animals:bird` | Птицы |  |  | `animals/sparrow` | 0 / 0 | ок |
| `animals:squirrel` | Цоканье белки |  |  | `animals/squirrel` | 0 / 0 | ок |
| `animals:wolf_howl` | Вой волка |  |  | `animals/wolf` | 0 / 0 | ок |
| `animals:wolf_growl` | Рык волка |  |  | `animals/wolf` | 0 / 0 | ок |
| `materials:knock` | Стук по доскам |  |  | `materials/planks` | 0 / 0 | ок |
| `music:note_pluck` | Нота, щипок |  |  | `music` | 0 / 0 | ок |
| `music:note_bell` | Нота, колокольчик |  |  | `music` | 0 / 0 | ок |
| `music:pad` | Протяжный тон |  |  | `music` | 0 / 0 | ок |
| `resources:step_sand` | Шаг по песку |  |  | `resources/soil` | 0 / 0 | ок |
| `plants:chop` | Удар по дереву |  |  | `plants/wood` | 0 / 0 | ок |
| `plants:rustle` | Шорох листьев |  |  | `plants/wood` | 0 / 0 | ок |
| `plants:step_wood` | Шаг по дереву |  |  | `plants/wood` | 0 / 0 | ок |
| `sounds:wind` | Ветер |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:rain` | Дождь |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:hail` | Град |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:blizzard` | Метель |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:water` | Вода |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:fire` | Костёр |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:crickets` | Сверчки |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:thunder` | Гром |  |  | `sounds/nature` | 0 / 0 | ок |
| `sounds:step_grass` | Шаг по траве |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_dirt` | Шаг по земле |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_stone` | Шаг по камню |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_snow` | Шаг по снегу |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:step_water` | Шаг по воде |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:swim` | Гребок |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:jump` | Прыжок |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:land` | Приземление |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:land_snow` | Приземление в снег |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:splash` | Всплеск |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:dig` | Копание |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:hit_stone` | Удар по камню |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:place` | Блок поставлен |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:pickup` | Подбор |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:craft` | Сделано |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:eat` | Еда |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:ignite` | Огонь зажжён |  |  | `sounds/player` | 0 / 0 | ок |
| `sounds:click` | Кнопка |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:tab` | Вкладка |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:open` | Окно открыто |  |  | `sounds/ui` | 0 / 0 | ок |
| `sounds:close` | Окно закрыто |  |  | `sounds/ui` | 0 / 0 | ок |
| `tools:mow` | Покос |  |  | `tools/scythe` | 0 / 0 | ок |
| `tools:swish` | Взмах |  |  | `tools/sword` | 0 / 0 | ок |
