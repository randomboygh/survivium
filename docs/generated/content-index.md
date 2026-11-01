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

- `core` Основа
- `animals` Животные: `animals/bear` Медведь, `animals/boar` Кабан, `animals/butterfly` Бабочка, `animals/cat` Дикая кошка, `animals/crow` Ворона, `animals/deer` Олень, `animals/duck` Утка, `animals/fish` Рыба, `animals/fox` Лиса, `animals/frog` Лягушка, `animals/game` Добыча, `animals/hedgehog` Ёж, `animals/owl` Сова, `animals/perch` Окунь, `animals/rabbit` Заяц, `animals/sparrow` Воробей, `animals/squirrel` Белка, `animals/wolf` Волк
- `biomes` Биомы: `biomes/alpine_meadow` Альпийский луг, `biomes/beach` Берег, `biomes/birch_grove` Берёзовая роща, `biomes/desert` Пустыня, `biomes/floodplain` Пойма, `biomes/forest` Лес, `biomes/forest_steppe` Лесостепь, `biomes/glacier` Ледник, `biomes/ice_waste` Ледяная пустошь, `biomes/jungle` Джунгли, `biomes/mangrove` Мангровые заросли, `biomes/maple_wood` Кленовник, `biomes/meadow` Луг, `biomes/peat_bog` Торфяное болото, `biomes/pine_wood` Бор, `biomes/plateau` Плато, `biomes/red_rocks` Красные скалы, `biomes/rock` Скалы, `biomes/salt_flat` Солончак, `biomes/savanna` Саванна, `biomes/sea` Море, `biomes/steppe` Степь, `biomes/stony_tundra` Каменистая тундра, `biomes/swamp` Болото, `biomes/taiga` Тайга, `biomes/tropical_beach` Тропический берег, `biomes/tropical_sea` Тропическое море, `biomes/tundra` Тундра
- `materials` Материалы: `materials/bone_glue` Костный клей, `materials/brick` Кирпич, `materials/bronze` Бронза, `materials/charcoal` Уголь, `materials/cloth` Ткань, `materials/copper` Медь, `materials/cord` Верёвка, `materials/glass` Стекло, `materials/iron` Железо, `materials/leather` Кожа, `materials/planks` Доски, `materials/steel` Сталь, `materials/tar` Смола, `materials/tin` Олово
- `music` Музыка
- `plants` Растения: `plants/acacia` Акация, `plants/apple` Яблоня, `plants/banana` Банан, `plants/birch` Берёза, `plants/bird_cherry` Черёмуха, `plants/blueberry` Черника, `plants/ceiba` Сейба, `plants/cherry` Вишня, `plants/cranberry` Клюква, `plants/currant` Смородина, `plants/deadwood` Сухое дерево, `plants/ears` Колоски, `plants/fern` Папоротник, `plants/fir` Пихта, `plants/flax` Лён, `plants/grass` Травы, `plants/larch` Лиственница, `plants/linden` Липа, `plants/mangrove` Мангр, `plants/maple` Клён, `plants/monstera` Монстера, `plants/moss` Мох, `plants/mushrooms` Грибы, `plants/nettle` Крапива, `plants/oak` Дуб, `plants/palm` Пальма, `plants/pine` Сосна, `plants/poplar` Тополь, `plants/raspberry` Малина, `plants/red_maple` Клён красный, `plants/reeds` Тростник, `plants/roasted_acorns` Жареные жёлуди, `plants/rosehip` Шиповник, `plants/rowan` Рябина, `plants/shrub` Куст, `plants/spruce` Ель, `plants/willow` Ива, `plants/wood` Древесина
- `resources` Ресурсы: `resources/fiber` Волокно, `resources/peat` Торф, `resources/salt` Соль, `resources/snow` Снег, `resources/soil` Грунт, `resources/stone` Камень, `resources/wood` Дерево
- `sounds` Звуки: `sounds/nature` Природа, `sounds/player` Игрок, `sounds/ui` Интерфейс
- `tools` Инструменты и крафт: `tools/anvil` Наковальня, `tools/axe` Топор, `tools/bloomery` Сыродутная печь, `tools/bow` Лук, `tools/candle` Сальная свеча, `tools/chest` Сундук, `tools/composite_bow` Составной лук, `tools/drying_rack` Сушилка, `tools/fishing_rod` Удочка, `tools/forge` Горн, `tools/kiln` Печь для обжига, `tools/knife` Нож, `tools/lantern` Фонарь, `tools/leather_sling` Кожаная праща, `tools/loom` Ткацкий станок, `tools/needle` Игла, `tools/pickaxe` Кирка, `tools/potters_wheel` Гончарный круг, `tools/scythe` Коса, `tools/shovel` Лопата, `tools/sling` Праща, `tools/spear` Копьё, `tools/sword` Меч, `tools/tar_torch` Смоляной факел, `tools/torch` Факел, `tools/workbench` Верстак

## Предметы (`items`, 136)

| Id | Название | Категория | Описание | Бандл | Эпоха | Связи из / в | Проверка |
|---|---|---|---|---|---|---|---|
| `core:campfire` | Костёр | Станки |  | `core` | 1. Примитивные инструменты | 1 / 12 | ок |
| `materials:brick` | Кирпич | Блоки |  | `materials/brick` | 3. Керамика и ранняя металлургия | 1 / 4 | ок |
| `materials:charcoal` | Уголь | Материалы |  | `materials/charcoal` | 3. Керамика и ранняя металлургия | 0 / 9 | ок |
| `materials:cloth` | Ткань | Материалы | Полотно с ткацкого станка. Идёт на бинты и факелы, потом — на одежду. | `materials/cloth` | 2. Дерево, кости и кожа | 1 / 3 | ок |
| `materials:copper_ore` | Медная руда | Материалы |  | `materials/copper` | 3. Керамика и ранняя металлургия | 1 / 2 | ок |
| `materials:copper_bar` | Медный слиток | Материалы |  | `materials/copper` | 3. Керамика и ранняя металлургия | 0 / 15 | ок |
| `materials:planks` | Доски | Блоки |  | `materials/planks` | 1. Примитивные инструменты | 1 / 40 | ок |
| `plants:blueberry` | Черника | Еда |  | `plants/blueberry` | 0. Выживание без инструментов | 0 / 1 | предупреждения: 1 |
| `plants:blueberry_bush` | Кустик черники | Посадки |  | `plants/blueberry` | 1. Примитивные инструменты | 1 / 1 | ок |
| `plants:cranberry` | Клюква | Еда |  | `plants/cranberry` | 0. Выживание без инструментов | 0 / 1 | предупреждения: 1 |
| `plants:currant` | Смородина | Еда |  | `plants/currant` | 0. Выживание без инструментов | 0 / 1 | предупреждения: 1 |
| `plants:currant_bush` | Куст смородины | Посадки |  | `plants/currant` | 1. Примитивные инструменты | 1 / 1 | ок |
| `plants:grass_seeds` | Семена трав | Посадки |  | `plants/grass` | 0. Выживание без инструментов | 1 / 2 | ок |
| `plants:mushroom` | Гриб | Еда |  | `plants/mushrooms` | 0. Выживание без инструментов | 0 / 2 | ок |
| `plants:glow_mushroom` | Светящийся гриб | Еда |  | `plants/mushrooms` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:fried_mushrooms` | Жареные грибы | Еда |  | `plants/mushrooms` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:raspberry` | Малина | Еда |  | `plants/raspberry` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:raspberry_bush` | Куст малины | Посадки |  | `plants/raspberry` | 1. Примитивные инструменты | 1 / 1 | ок |
| `plants:rosehip` | Шиповник | Еда |  | `plants/rosehip` | 0. Выживание без инструментов | 0 / 1 | предупреждения: 1 |
| `plants:rosehip_bush` | Куст шиповника | Посадки |  | `plants/rosehip` | 1. Примитивные инструменты | 1 / 1 | ок |
| `plants:shrub_bush` | Куст | Посадки |  | `plants/shrub` | 1. Примитивные инструменты | 1 / 1 | ок |
| `resources:fiber` | Волокно | Материалы |  | `resources/fiber` | 0. Выживание без инструментов | 0 / 16 | ок |
| `materials:cord` | Верёвка | Материалы |  | `materials/cord` | 1. Примитивные инструменты | 1 / 24 | ок |
| `plants:moss` | Мох | Материалы |  | `plants/moss` | 0. Выживание без инструментов | 0 / 2 | ок |
| `plants:bandage` | Бинт | Лечение |  | `plants/moss` | 0. Выживание без инструментов | 0 / 1 | ок |
| `resources:peat` | Торф | Блоки |  | `resources/peat` | 0. Выживание без инструментов | 1 / 1 | ок |
| `resources:salt` | Соль | Блоки |  | `resources/salt` | 0. Выживание без инструментов | 1 / 1 | ок |
| `resources:snow` | Снег | Блоки |  | `resources/snow` | 0. Выживание без инструментов | 1 / 1 | ок |
| `resources:ice` | Лёд | Блоки |  | `resources/snow` | 1. Примитивные инструменты | 1 / 1 | ок |
| `resources:dirt` | Земля | Блоки |  | `resources/soil` | 0. Выживание без инструментов | 1 / 2 | ок |
| `resources:sand` | Песок | Блоки |  | `resources/soil` | 0. Выживание без инструментов | 1 / 3 | ок |
| `resources:clay` | Глина | Блоки |  | `resources/soil` | 0. Выживание без инструментов | 1 / 7 | ок |
| `resources:stone` | Камень | Блоки |  | `resources/stone` | 0. Выживание без инструментов | 1 / 7 | ок |
| `resources:flint` | Кремень | Материалы |  | `resources/stone` | 0. Выживание без инструментов | 0 / 17 | ок |
| `resources:branch` | Ветка | Материалы |  | `resources/wood` | 0. Выживание без инструментов | 0 / 53 | ок |
| `resources:log` | Бревно | Блоки |  | `resources/wood`; патчи: `plants/wood` | 1. Примитивные инструменты | 1 / 25 | ок |
| `animals:roach` | Плотва | Еда | Мелкая речная рыба. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 21 | ок |
| `animals:pike` | Щука | Еда | Хищница тихих заводей. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 18 | ок |
| `animals:salmon` | Лосось | Еда | Рыба холодных северных рек. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 11 | ок |
| `animals:cod` | Треска | Еда | Морская рыба холодного берега. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 6 | ок |
| `animals:parrotfish` | Рыба-попугай | Еда | Пёстрая рыба тёплого моря. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 4 | ок |
| `animals:catfish` | Сом | Еда | Большая рыба тёплых болот и рек. Её жарят на костре. | `animals/fish` | 1. Примитивные инструменты | 0 / 15 | ок |
| `animals:roasted_fish` | Жареная рыба | Еда | Рыба, зажаренная на костре. Сытная. | `animals/fish` | 1. Примитивные инструменты | 0 / 6 | ок |
| `plants:apple` | Яблоко | Еда |  | `plants/apple` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:banana` | Банан | Еда |  | `plants/banana` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:banana_bush` | Куст банана | Посадки |  | `plants/banana` | 1. Примитивные инструменты | 1 / 1 | ок |
| `plants:acorn` | Жёлудь | Материалы |  | `plants/oak` | 0. Выживание без инструментов | 0 / 2 | ок |
| `plants:coconut` | Кокос | Еда |  | `plants/palm` | 0. Выживание без инструментов | 0 / 1 | ок |
| `plants:rowan` | Рябина | Еда |  | `plants/rowan` | 0. Выживание без инструментов | 0 / 1 | предупреждения: 1 |
| `plants:cone` | Шишка | Материалы |  | `plants/spruce` | 0. Выживание без инструментов | 0 / 2 | ок |
| `tools:fishing_rod` | Удочка | Инструменты | Гибкое удилище с леской и кремнёвым крючком. Закидывают в воду и ждут поклёвки. | `tools/fishing_rod` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:cord_sling` | Праща | Инструменты | Ремень из верёвки: мечет камешки дальше, чем рука. | `tools/sling` | 1. Примитивные инструменты | 2 / 1 | ок |
| `tools:sling_stone` | Камешки | Материалы | Круглые камешки для пращи. | `tools/sling` | 0. Выживание без инструментов | 0 / 3 | ок |
| `tools:torch` | Факел | Материалы |  | `tools/torch` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:workbench` | Верстак | Станки |  | `tools/workbench` | 1. Примитивные инструменты | 1 / 36 | ок |
| `tools:bloomery` | Сыродутная печь | Станки |  | `tools/bloomery` | 5. Железо | 1 / 3 | ок |
| `tools:wooden_bow` | Деревянный лук | Инструменты | Стреляет стрелами дальше всего. | `tools/bow` | 1. Примитивные инструменты | 2 / 2 | ок |
| `tools:arrow` | Стрела | Материалы | Древко с кремнёвым наконечником. После выстрела её можно подобрать. | `tools/bow` | 1. Примитивные инструменты | 0 / 4 | ок |
| `tools:chest` | Сундук | Станки |  | `tools/chest` | 1. Примитивные инструменты | 0 / 2 | ок |
| `tools:drying_rack` | Сушилка | Станки | Рама из веток. На ней выделывают шкуры и вялят мясо. | `tools/drying_rack` | 2. Дерево, кости и кожа | 1 / 3 | ок |
| `animals:small_carcass` | Тушка | Материалы | Мелкий зверь или птица. Разделывается руками. | `animals/game` | 0. Выживание без инструментов | 0 / 9 | ок |
| `animals:carcass` | Туша | Материалы | Крупный зверь. Разделать её можно только ножом. | `animals/game` | 0. Выживание без инструментов | 0 / 5 | ок |
| `animals:raw_meat` | Сырое мясо | Еда | Есть можно, но жареное сытнее. | `animals/game` | 0. Выживание без инструментов | 0 / 4 | ок |
| `animals:roasted_meat` | Жареное мясо | Еда | Мясо, зажаренное на костре. Очень сытное. | `animals/game` | 0. Выживание без инструментов | 0 / 1 | ок |
| `animals:hide` | Шкура | Материалы | Сырая шкура зверя. | `animals/game` | 0. Выживание без инструментов | 0 / 3 | ок |
| `animals:bone` | Кость | Материалы |  | `animals/game` | 0. Выживание без инструментов | 0 / 6 | ок |
| `animals:fat` | Жир | Материалы |  | `animals/game` | 1. Примитивные инструменты | 0 / 3 | ок |
| `animals:jerky` | Вяленое мясо | Еда | Мясо, провяленное на сушилке. Лёгкое и сытное, огня не нужно. | `animals/game` | 2. Дерево, кости и кожа | 0 / 1 | ок |
| `materials:leather` | Кожа | Материалы | Выделанная шкура. Из неё шьют иглой. | `materials/leather` | 2. Дерево, кости и кожа | 1 / 4 | ок |
| `tools:tallow_candle` | Сальная свеча | Материалы | Фитиль в жиру. Светит слабее факела, но горит дольше. | `tools/candle` | 1. Примитивные инструменты | 0 / 1 | ок |
| `tools:forge` | Горн | Станки |  | `tools/forge` | 3. Керамика и ранняя металлургия | 1 / 6 | ок |
| `materials:glass` | Стекло | Материалы | Мутноватое зелёное стекло из песка. Идёт на фонарь. | `materials/glass` | 3. Керамика и ранняя металлургия | 0 / 2 | ок |
| `materials:iron_ore` | Железная руда | Материалы | Ржаво-бурая тяжёлая руда. Её берёт бронзовая кирка. | `materials/iron` | 4. Бронза | 0 / 2 | ок |
| `materials:iron_bloom` | Крица | Материалы | Пористый ком железа со шлаком из сыродутной печи. В горне из него выходят два слитка. | `materials/iron` | 5. Железо | 1 / 2 | ок |
| `materials:iron_bar` | Железный слиток | Материалы | Тёмный прочный металл. Из него наковальня и железные инструменты. | `materials/iron` | 5. Железо | 1 / 17 | ок |
| `materials:tin_ore` | Оловянная руда | Материалы | Тёмная тяжёлая руда со светлыми крупинками. Её берёт медная кирка. | `materials/tin` | 3. Керамика и ранняя металлургия | 0 / 2 | ок |
| `materials:tin_bar` | Слиток олова | Материалы | Мягкий серебристый металл. С медью даёт бронзу. | `materials/tin` | 3. Керамика и ранняя металлургия | 0 / 2 | ок |
| `tools:anvil` | Наковальня | Станки |  | `tools/anvil` | 5. Железо | 1 / 14 | ок |
| `tools:kiln` | Печь для обжига | Станки |  | `tools/kiln` | 3. Керамика и ранняя металлургия | 1 / 7 | ок |
| `plants:grain` | Зерно | Посадки |  | `plants/ears` | 0. Выживание без инструментов | 2 / 2 | ок |
| `plants:flour` | Мука | Материалы |  | `plants/ears` | 0. Выживание без инструментов | 0 / 2 | ок |
| `plants:flatbread` | Лепёшка | Еда |  | `plants/ears` | 3. Керамика и ранняя металлургия | 0 / 1 | ок |
| `tools:leather_sling` | Кожаная праща | Инструменты | Ремни и чашка из кожи. Мечет камешки дальше и сильнее верёвочной. | `tools/leather_sling` | 2. Дерево, кости и кожа | 2 / 1 | ок |
| `tools:loom` | Ткацкий станок | Станки |  | `tools/loom` | 2. Дерево, кости и кожа | 1 / 3 | ок |
| `plants:flax_stalks` | Стебли льна | Материалы | Срезанный дикий лён. Из него прядут льняную нить. | `plants/flax` | 0. Выживание без инструментов | 0 / 2 | ок |
| `plants:linen_thread` | Льняная нить | Материалы | Тонкая прочная нить. На ткацком станке из неё ткут ткань. | `plants/flax` | 0. Выживание без инструментов | 0 / 2 | ок |
| `tools:bone_needle` | Костяная игла | Инструменты | Шьёт кожу. Лежит в сумке, пока шьёшь. | `tools/needle` | 1. Примитивные инструменты | 0 / 1 | ок |
| `tools:potters_wheel` | Гончарный круг | Станки |  | `tools/potters_wheel` | 1. Примитивные инструменты | 0 / 3 | ок |
| `tools:raw_pot` | Сырой горшок | Материалы | Вылепленный из глины горшок. Его ещё нужно обжечь в печи. | `tools/potters_wheel` | 1. Примитивные инструменты | 0 / 2 | ок |
| `tools:pot` | Глиняный горшок | Материалы | Обожжённый горшок. В нём выгоняют смолу и жарят жёлуди; сам он не тратится. | `tools/potters_wheel` | 3. Керамика и ранняя металлургия | 0 / 4 | ок |
| `materials:bone_glue` | Костный клей | Материалы | Вываренный из костей клей. Склеивает составной лук. | `materials/bone_glue` | 3. Керамика и ранняя металлургия | 0 / 3 | ок |
| `materials:raw_crucible` | Сырой тигель | Материалы | Толстостенная чаша из глины с песком. Её ещё нужно обжечь в печи. | `materials/bronze` | 1. Примитивные инструменты | 0 / 2 | ок |
| `materials:crucible` | Тигель | Материалы | Обожжённая чаша для плавки. В ней сплавляют медь с оловом; сама она не тратится. | `materials/bronze` | 3. Керамика и ранняя металлургия | 0 / 3 | ок |
| `materials:bronze_bar` | Бронзовый слиток | Материалы | Медь с оловом: твёрже меди. Из бронзы — инструменты, которые берут железную руду. | `materials/bronze` | 4. Бронза | 1 / 15 | ок |
| `materials:steel_bar` | Стальной слиток | Материалы | Железо, напитанное углём: твёрже и упруже. Из стали — лучшие инструменты. | `materials/steel` | 6. Сталь | 1 / 13 | ок |
| `materials:tar` | Смола | Материалы | Густая чёрная смола из брёвен. Горит долго и ярко, склеивает. | `materials/tar` | 3. Керамика и ранняя металлургия | 0 / 3 | ок |
| `plants:roasted_acorns` | Жареные жёлуди | Еда | Жёлуди, прокалённые в горшке на костре. Сытные, но горьковатые. | `plants/roasted_acorns` | 3. Керамика и ранняя металлургия | 0 / 1 | ок |
| `tools:stone_axe` | Каменный топор | Инструменты |  | `tools/axe` | 1. Примитивные инструменты | 2 / 1 | ок |
| `tools:copper_axe` | Медный топор | Инструменты |  | `tools/axe` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_axe` | Бронзовый топор | Инструменты |  | `tools/axe` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_axe` | Железный топор | Инструменты |  | `tools/axe` | 5. Железо | 1 / 1 | ок |
| `tools:steel_axe` | Стальной топор | Инструменты |  | `tools/axe` | 6. Сталь | 1 / 1 | ок |
| `tools:composite_bow` | Составной лук | Инструменты | Деревянный лук, усиленный костью и обмотанный кожей. Бьёт дальше и сильнее. | `tools/composite_bow` | 3. Керамика и ранняя металлургия | 2 / 1 | ок |
| `tools:flint_knife` | Кремнёвый нож | Инструменты | Острый осколок кремня на рукояти. Разделывает туши и бьёт зверя. | `tools/knife` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:copper_knife` | Медный нож | Инструменты |  | `tools/knife` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_knife` | Бронзовый нож | Инструменты |  | `tools/knife` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_knife` | Железный нож | Инструменты |  | `tools/knife` | 5. Железо | 1 / 1 | ок |
| `tools:steel_knife` | Стальной нож | Инструменты |  | `tools/knife` | 6. Сталь | 1 / 1 | ок |
| `tools:lantern` | Фонарь | Материалы | Стекло в медной оправе, внутри горит смола. Светит дальше факела и горит намного дольше. | `tools/lantern` | 3. Керамика и ранняя металлургия | 0 / 1 | ок |
| `tools:stone_pickaxe` | Каменная кирка | Инструменты |  | `tools/pickaxe` | 1. Примитивные инструменты | 2 / 1 | ок |
| `tools:wooden_pickaxe` | Деревянная кирка | Инструменты |  | `tools/pickaxe` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:copper_pickaxe` | Медная кирка | Инструменты |  | `tools/pickaxe` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_pickaxe` | Бронзовая кирка | Инструменты |  | `tools/pickaxe` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_pickaxe` | Железная кирка | Инструменты |  | `tools/pickaxe` | 5. Железо | 1 / 1 | ок |
| `tools:steel_pickaxe` | Стальная кирка | Инструменты |  | `tools/pickaxe` | 6. Сталь | 1 / 1 | ок |
| `tools:stone_scythe` | Каменная коса | Инструменты |  | `tools/scythe` | 1. Примитивные инструменты | 2 / 1 | ок |
| `tools:wooden_scythe` | Деревянная коса | Инструменты |  | `tools/scythe` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:copper_scythe` | Медная коса | Инструменты |  | `tools/scythe` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_scythe` | Бронзовая коса | Инструменты |  | `tools/scythe` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_scythe` | Железная коса | Инструменты |  | `tools/scythe` | 5. Железо | 1 / 1 | ок |
| `tools:steel_scythe` | Стальная коса | Инструменты |  | `tools/scythe` | 6. Сталь | 1 / 1 | ок |
| `tools:wooden_shovel` | Деревянная лопата | Инструменты |  | `tools/shovel` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:copper_shovel` | Медная лопата | Инструменты |  | `tools/shovel` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_shovel` | Бронзовая лопата | Инструменты |  | `tools/shovel` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_shovel` | Железная лопата | Инструменты |  | `tools/shovel` | 5. Железо | 1 / 1 | ок |
| `tools:steel_shovel` | Стальная лопата | Инструменты |  | `tools/shovel` | 6. Сталь | 1 / 1 | ок |
| `tools:flint_spear` | Кремнёвое копьё | Инструменты | Длинное копьё с кремнёвым наконечником. Его метают в зверя и подбирают снова. | `tools/spear` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:bronze_spear` | Бронзовое копьё | Инструменты |  | `tools/spear` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_spear` | Железное копьё | Инструменты |  | `tools/spear` | 5. Железо | 1 / 1 | ок |
| `tools:wooden_sword` | Деревянный меч | Инструменты |  | `tools/sword` | 1. Примитивные инструменты | 1 / 1 | ок |
| `tools:stone_sword` | Каменный меч | Инструменты |  | `tools/sword` | 1. Примитивные инструменты | 2 / 1 | ок |
| `tools:copper_sword` | Медный меч | Инструменты |  | `tools/sword` | 3. Керамика и ранняя металлургия | 1 / 1 | ок |
| `tools:bronze_sword` | Бронзовый меч | Инструменты |  | `tools/sword` | 4. Бронза | 1 / 1 | ок |
| `tools:iron_sword` | Железный меч | Инструменты |  | `tools/sword` | 5. Железо | 1 / 1 | ок |
| `tools:steel_sword` | Стальной меч | Инструменты |  | `tools/sword` | 6. Сталь | 1 / 1 | ок |
| `tools:tar_torch` | Смоляной факел | Материалы | Ветка, обмотанная тканью в смоле. Горит втрое дольше простого факела и светит дальше. | `tools/tar_torch` | 3. Керамика и ранняя металлургия | 0 / 1 | ок |

## Рецепты (`recipes`, 95)

| Id | Название | Категория | Описание | Бандл | Эпоха | Связи из / в | Проверка |
|---|---|---|---|---|---|---|---|
| `plants:fried_mushrooms` | Жареные грибы | Еда |  | `plants/mushrooms` | 0. Выживание без инструментов | 3 / 0 | ок |
| `materials:cord` | Верёвка | Материалы |  | `materials/cord` | 0. Выживание без инструментов | 2 / 0 | ок |
| `plants:bandage` | Бинт | Лечение |  | `plants/moss` | 0. Выживание без инструментов | 3 / 0 | ок |
| `resources:campfire` | Костёр | Станки |  | `resources/wood` | 0. Выживание без инструментов | 3 / 0 | ок |
| `animals:roasted_fish_from_roach` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:roasted_fish_from_pike` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:roasted_fish_from_salmon` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:roasted_fish_from_cod` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:roasted_fish_from_parrotfish` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:roasted_fish_from_catfish` | Жареная рыба | Еда |  | `animals/fish` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:fishing_rod` | Удочка | Инструменты |  | `tools/fishing_rod` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:cord_sling` | Праща | Инструменты |  | `tools/sling` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:sling_stone` | Камешки | Материалы |  | `tools/sling` | 0. Выживание без инструментов | 2 / 0 | ок |
| `tools:torch` | Факел | Материалы |  | `tools/torch` | 0. Выживание без инструментов | 3 / 0 | ок |
| `tools:workbench` | Верстак | Станки |  | `tools/workbench` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:bloomery` | Сыродутная печь | Станки |  | `tools/bloomery` | 3. Керамика и ранняя металлургия | 5 / 0 | ок |
| `tools:wooden_bow` | Деревянный лук | Инструменты |  | `tools/bow` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:arrow` | Стрелы | Материалы |  | `tools/bow` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:chest` | Сундук | Станки |  | `tools/chest` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:drying_rack` | Сушилка | Станки |  | `tools/drying_rack` | 1. Примитивные инструменты | 4 / 0 | ок |
| `animals:raw_meat_from_small_carcass` | Разделать тушку | Еда |  | `animals/game` | 0. Выживание без инструментов | 4 / 0 | ок |
| `animals:raw_meat_from_carcass` | Разделать тушу | Еда |  | `animals/game` | 1. Примитивные инструменты | 5 / 0 | ок |
| `animals:roasted_meat` | Жареное мясо | Еда |  | `animals/game` | 0. Выживание без инструментов | 4 / 0 | ок |
| `animals:jerky` | Вяленое мясо | Еда |  | `animals/game` | 2. Дерево, кости и кожа | 3 / 0 | ок |
| `materials:leather` | Кожа | Материалы |  | `materials/leather` | 2. Дерево, кости и кожа | 4 / 0 | ок |
| `tools:tallow_candle` | Сальная свеча | Материалы |  | `tools/candle` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:forge` | Горн | Станки |  | `tools/forge` | 3. Керамика и ранняя металлургия | 5 / 0 | ок |
| `tools:copper_bar` | Медный слиток | Материалы |  | `tools/forge` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `materials:glass` | Стекло | Материалы |  | `materials/glass` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `materials:iron_bloom` | Крица | Материалы |  | `materials/iron` | 5. Железо | 4 / 0 | ок |
| `materials:iron_bar` | Железный слиток | Материалы |  | `materials/iron` | 5. Железо | 4 / 0 | ок |
| `materials:tin_bar` | Слиток олова | Материалы |  | `materials/tin` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:anvil` | Наковальня | Станки |  | `tools/anvil` | 5. Железо | 4 / 0 | ок |
| `tools:kiln` | Печь для обжига | Станки |  | `tools/kiln` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:brick` | Кирпич | Блоки |  | `tools/kiln` | 3. Керамика и ранняя металлургия | 3 / 0 | ок |
| `tools:charcoal` | Уголь | Материалы |  | `tools/kiln` | 3. Керамика и ранняя металлургия | 3 / 0 | ок |
| `plants:flour` | Мука | Материалы |  | `plants/ears` | 0. Выживание без инструментов | 2 / 0 | ок |
| `plants:flatbread` | Лепёшка | Еда |  | `plants/ears` | 3. Керамика и ранняя металлургия | 3 / 0 | ок |
| `tools:leather_sling` | Кожаная праща | Инструменты |  | `tools/leather_sling` | 2. Дерево, кости и кожа | 3 / 0 | ок |
| `tools:loom` | Ткацкий станок | Станки |  | `tools/loom` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:cloth_from_cord` | Грубая ткань | Материалы |  | `tools/loom` | 2. Дерево, кости и кожа | 3 / 0 | ок |
| `plants:linen_thread` | Льняная нить | Материалы |  | `plants/flax` | 0. Выживание без инструментов | 2 / 0 | ок |
| `plants:cloth` | Льняная ткань | Материалы |  | `plants/flax` | 2. Дерево, кости и кожа | 3 / 0 | ок |
| `tools:bone_needle` | Костяная игла | Инструменты |  | `tools/needle` | 1. Примитивные инструменты | 2 / 0 | ок |
| `tools:potters_wheel` | Гончарный круг | Станки |  | `tools/potters_wheel` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:raw_pot` | Сырой горшок | Материалы |  | `tools/potters_wheel` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:pot` | Глиняный горшок | Материалы |  | `tools/potters_wheel` | 3. Керамика и ранняя металлургия | 3 / 0 | ок |
| `materials:bone_glue` | Костный клей | Материалы |  | `materials/bone_glue` | 3. Керамика и ранняя металлургия | 5 / 0 | ок |
| `materials:raw_crucible` | Сырой тигель | Материалы |  | `materials/bronze` | 1. Примитивные инструменты | 4 / 0 | ок |
| `materials:crucible` | Тигель | Материалы |  | `materials/bronze` | 3. Керамика и ранняя металлургия | 3 / 0 | ок |
| `materials:bronze_bar` | Бронзовый слиток | Материалы |  | `materials/bronze` | 3. Керамика и ранняя металлургия | 6 / 0 | ок |
| `materials:steel_bar` | Стальной слиток | Материалы |  | `materials/steel` | 5. Железо | 5 / 0 | ок |
| `materials:tar` | Смола | Материалы |  | `materials/tar` | 3. Керамика и ранняя металлургия | 5 / 0 | ок |
| `plants:roasted_acorns` | Жареные жёлуди | Еда |  | `plants/roasted_acorns` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:stone_axe` | Каменный топор | Инструменты |  | `tools/axe` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:planks` | Доски | Блоки |  | `tools/axe` | 1. Примитивные инструменты | 3 / 0 | ок |
| `tools:copper_axe` | Медный топор | Инструменты |  | `tools/axe` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_axe` | Бронзовый топор | Инструменты |  | `tools/axe` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_axe` | Железный топор | Инструменты |  | `tools/axe` | 5. Железо | 4 / 0 | ок |
| `tools:steel_axe` | Стальной топор | Инструменты |  | `tools/axe` | 6. Сталь | 4 / 0 | ок |
| `tools:composite_bow` | Составной лук | Инструменты |  | `tools/composite_bow` | 3. Керамика и ранняя металлургия | 6 / 0 | ок |
| `tools:arrow_from_bone` | Стрелы с костяным наконечником | Материалы |  | `tools/composite_bow` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:flint_knife` | Кремнёвый нож | Инструменты |  | `tools/knife` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:copper_knife` | Медный нож | Инструменты |  | `tools/knife` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_knife` | Бронзовый нож | Инструменты |  | `tools/knife` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_knife` | Железный нож | Инструменты |  | `tools/knife` | 5. Железо | 4 / 0 | ок |
| `tools:steel_knife` | Стальной нож | Инструменты |  | `tools/knife` | 6. Сталь | 4 / 0 | ок |
| `tools:lantern` | Фонарь | Материалы |  | `tools/lantern` | 3. Керамика и ранняя металлургия | 5 / 0 | ок |
| `tools:stone_pickaxe` | Каменная кирка | Инструменты |  | `tools/pickaxe` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:wooden_pickaxe` | Деревянная кирка | Инструменты |  | `tools/pickaxe` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:copper_pickaxe` | Медная кирка | Инструменты |  | `tools/pickaxe` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_pickaxe` | Бронзовая кирка | Инструменты |  | `tools/pickaxe` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_pickaxe` | Железная кирка | Инструменты |  | `tools/pickaxe` | 5. Железо | 4 / 0 | ок |
| `tools:steel_pickaxe` | Стальная кирка | Инструменты |  | `tools/pickaxe` | 6. Сталь | 4 / 0 | ок |
| `tools:stone_scythe` | Каменная коса | Инструменты |  | `tools/scythe` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:wooden_scythe` | Деревянная коса | Инструменты |  | `tools/scythe` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:copper_scythe` | Медная коса | Инструменты |  | `tools/scythe` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_scythe` | Бронзовая коса | Инструменты |  | `tools/scythe` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_scythe` | Железная коса | Инструменты |  | `tools/scythe` | 5. Железо | 4 / 0 | ок |
| `tools:steel_scythe` | Стальная коса | Инструменты |  | `tools/scythe` | 6. Сталь | 4 / 0 | ок |
| `tools:wooden_shovel` | Деревянная лопата | Инструменты |  | `tools/shovel` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:copper_shovel` | Медная лопата | Инструменты |  | `tools/shovel` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_shovel` | Бронзовая лопата | Инструменты |  | `tools/shovel` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_shovel` | Железная лопата | Инструменты |  | `tools/shovel` | 5. Железо | 4 / 0 | ок |
| `tools:steel_shovel` | Стальная лопата | Инструменты |  | `tools/shovel` | 6. Сталь | 4 / 0 | ок |
| `tools:flint_spear` | Кремнёвое копьё | Инструменты |  | `tools/spear` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:bronze_spear` | Бронзовое копьё | Инструменты |  | `tools/spear` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_spear` | Железное копьё | Инструменты |  | `tools/spear` | 5. Железо | 4 / 0 | ок |
| `tools:wooden_sword` | Деревянный меч | Инструменты |  | `tools/sword` | 1. Примитивные инструменты | 4 / 0 | ок |
| `tools:stone_sword` | Каменный меч | Инструменты |  | `tools/sword` | 1. Примитивные инструменты | 5 / 0 | ок |
| `tools:copper_sword` | Медный меч | Инструменты |  | `tools/sword` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |
| `tools:bronze_sword` | Бронзовый меч | Инструменты |  | `tools/sword` | 4. Бронза | 4 / 0 | ок |
| `tools:iron_sword` | Железный меч | Инструменты |  | `tools/sword` | 5. Железо | 4 / 0 | ок |
| `tools:steel_sword` | Стальной меч | Инструменты |  | `tools/sword` | 6. Сталь | 4 / 0 | ок |
| `tools:tar_torch` | Смоляной факел | Материалы |  | `tools/tar_torch` | 3. Керамика и ранняя металлургия | 4 / 0 | ок |

## Материалы ячеек (`materials`, 19)

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
| `resources:peat` | Торф | peat |  | `resources/peat` | 1 / 1 | ок |
| `resources:salt` | Соль | salt |  | `resources/salt` | 1 / 1 | ок |
| `resources:snow` | Снег | snow |  | `resources/snow` | 1 / 1 | ок |
| `resources:ice` | Лёд | ice |  | `resources/snow` | 1 / 1 | ок |
| `resources:sand` | Песок | beach |  | `resources/soil` | 2 / 1 | ок |
| `resources:clay` | Глина | bank |  | `resources/soil` | 1 / 1 | ок |
| `resources:scree` | Осыпь | scree |  | `resources/stone` | 2 / 0 | ок |
| `plants:log` | Бревно | trunk |  | `plants/wood` | 1 / 1 | ок |
| `plants:leaves` | Листва | crown |  | `plants/wood` | 0 / 0 | ок |
| `materials:iron_ore` | Железная руда | ore |  | `materials/iron` | 1 / 0 | ок |
| `materials:tin_ore` | Оловянная руда | ore |  | `materials/tin` | 1 / 0 | ок |

## Деревья (`trees`, 20)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:acacia` | Акация | broad |  | `plants/acacia` | 2 / 1 | ок |
| `plants:apple` | Яблоня | broad |  | `plants/apple` | 3 / 1 | ок |
| `plants:birch` | Берёза | broad |  | `plants/birch` | 2 / 4 | ок |
| `plants:bird_cherry` | Черёмуха | broad |  | `plants/bird_cherry` | 2 / 5 | ок |
| `plants:ceiba` | Сейба | broad |  | `plants/ceiba` | 2 / 1 | ок |
| `plants:cherry` | Вишня | broad |  | `plants/cherry` | 2 / 1 | ок |
| `plants:deadwood` | Сухое дерево | broad |  | `plants/deadwood` | 2 / 6 | ок |
| `plants:fir` | Пихта | needles |  | `plants/fir` | 2 / 1 | ок |
| `plants:larch` | Лиственница | needles |  | `plants/larch` | 2 / 4 | ок |
| `plants:linden` | Липа | broad |  | `plants/linden` | 2 / 3 | ок |
| `plants:mangrove` | Мангр | broad |  | `plants/mangrove` | 2 / 1 | ок |
| `plants:maple` | Клён | broad |  | `plants/maple` | 2 / 2 | ок |
| `plants:oak` | Дуб | broad |  | `plants/oak` | 3 / 9 | ок |
| `plants:palm` | Пальма | broad |  | `plants/palm` | 3 / 3 | ок |
| `plants:pine` | Сосна | needles |  | `plants/pine` | 3 / 3 | ок |
| `plants:poplar` | Тополь | broad |  | `plants/poplar` | 2 / 3 | ок |
| `plants:red_maple` | Клён красный | broad |  | `plants/red_maple` | 2 / 1 | ок |
| `plants:rowan` | Рябина | broad |  | `plants/rowan` | 3 / 4 | ок |
| `plants:spruce` | Ель | needles |  | `plants/spruce` | 3 / 4 | ок |
| `plants:willow` | Ива | broad |  | `plants/willow` | 2 / 2 | ок |

## Кусты (`bushes`, 6)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:blueberry` | Черника |  |  | `plants/blueberry` | 3 / 8 | ок |
| `plants:currant` | Смородина |  |  | `plants/currant` | 3 / 4 | ок |
| `plants:raspberry` | Малина |  |  | `plants/raspberry` | 3 / 4 | ок |
| `plants:rosehip` | Шиповник |  |  | `plants/rosehip` | 3 / 5 | ок |
| `plants:shrub` | Куст |  |  | `plants/shrub` | 2 / 21 | ок |
| `plants:banana` | Банан |  |  | `plants/banana` | 3 / 2 | ок |

## Растения (`plants`, 14)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `plants:cranberry` | Клюква | custom |  | `plants/cranberry` | 1 / 0 | ок |
| `plants:fern` | Папоротник | custom |  | `plants/fern` | 1 / 0 | ок |
| `plants:tuft` | Трава | tuft |  | `plants/grass` | 1 / 2 | ок |
| `plants:tall_grass` | Высокая трава | tall_grass |  | `plants/grass` | 1 / 1 | ок |
| `plants:flowers` | Цветы | flowers |  | `plants/grass` | 1 / 2 | ок |
| `plants:herbs` | Травы | herbs |  | `plants/grass` | 1 / 0 | ок |
| `plants:monstera` | Монстера | custom |  | `plants/monstera` | 3 / 0 | ок |
| `plants:mushrooms` | Грибы | mushrooms |  | `plants/mushrooms` | 1 / 2 | ок |
| `plants:glow_mushrooms` | Светящиеся грибы | glow_mushrooms |  | `plants/mushrooms` | 1 / 0 | ок |
| `plants:nettle` | Крапива | custom |  | `plants/nettle` | 1 / 0 | ок |
| `plants:reeds` | Тростник | reeds |  | `plants/reeds` | 1 / 0 | ок |
| `plants:moss` | Мох | moss |  | `plants/moss` | 1 / 0 | ок |
| `plants:ears` | Колоски | ears |  | `plants/ears` | 1 / 3 | ок |
| `plants:flax` | Лён | custom |  | `plants/flax` | 4 / 0 | ок |

## Существа (`creatures`, 17)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:human` | Человек |  |  | `core` | 0 / 0 | ок |
| `animals:bear` | Медведь |  |  | `animals/bear`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:boar` | Кабан |  |  | `animals/boar`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:butterfly` | Бабочка |  |  | `animals/butterfly` | 1 / 0 | ок |
| `animals:cat` | Дикая кошка |  |  | `animals/cat` | 3 / 0 | ок |
| `animals:crow` | Ворона |  |  | `animals/crow` | 2 / 0 | ок |
| `animals:deer` | Олень |  |  | `animals/deer`; патчи: `biomes/birch_grove`, `biomes/steppe` | 8 / 0 | ок |
| `animals:duck` | Утка |  |  | `animals/duck` | 1 / 0 | ок |
| `animals:fox` | Лиса |  |  | `animals/fox`; патчи: `biomes/birch_grove`, `biomes/steppe` | 6 / 0 | ок |
| `animals:frog` | Лягушка |  |  | `animals/frog` | 0 / 0 | ок |
| `animals:hedgehog` | Ёж |  |  | `animals/hedgehog`; патчи: `biomes/birch_grove` | 4 / 0 | ок |
| `animals:owl` | Сова |  |  | `animals/owl`; патчи: `biomes/birch_grove`, `biomes/pine_wood` | 5 / 0 | ок |
| `animals:perch` | Окунь |  |  | `animals/perch` | 0 / 0 | ок |
| `animals:rabbit` | Заяц |  |  | `animals/rabbit`; патчи: `biomes/birch_grove`, `biomes/steppe` | 7 / 0 | ок |
| `animals:sparrow` | Воробей |  |  | `animals/sparrow` | 1 / 0 | ок |
| `animals:squirrel` | Белка |  |  | `animals/squirrel`; патчи: `biomes/pine_wood` | 5 / 0 | ок |
| `animals:wolf` | Волк |  |  | `animals/wolf`; патчи: `biomes/pine_wood` | 5 / 0 | ок |

## Биомы (`biomes`, 28)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `biomes:alpine_meadow` | Альпийский луг | alpine |  | `biomes/alpine_meadow` | 6 / 0 | ок |
| `biomes:beach` | Берег | beach |  | `biomes/beach` | 2 / 0 | ок |
| `biomes:birch_grove` | Берёзовая роща | climate |  | `biomes/birch_grove` | 11 / 5 | ок |
| `biomes:desert` | Пустыня | climate |  | `biomes/desert` | 3 / 0 | ок |
| `biomes:floodplain` | Пойма | climate |  | `biomes/floodplain` | 9 / 1 | ок |
| `biomes:forest` | Лес | climate |  | `biomes/forest` | 13 / 10 | ок |
| `biomes:forest_steppe` | Лесостепь | climate |  | `biomes/forest_steppe` | 9 / 1 | ок |
| `biomes:glacier` | Ледник | glacier |  | `biomes/glacier` | 2 / 0 | ок |
| `biomes:ice_waste` | Ледяная пустошь | climate |  | `biomes/ice_waste` | 2 / 0 | ок |
| `biomes:jungle` | Джунгли | climate |  | `biomes/jungle` | 7 / 1 | ок |
| `biomes:mangrove` | Мангровые заросли | swamp |  | `biomes/mangrove` | 5 / 1 | ок |
| `biomes:maple_wood` | Кленовник | climate |  | `biomes/maple_wood` | 11 / 0 | ок |
| `biomes:meadow` | Луг | climate |  | `biomes/meadow` | 12 / 7 | ок |
| `biomes:peat_bog` | Торфяное болото | climate |  | `biomes/peat_bog` | 8 / 0 | ок |
| `biomes:pine_wood` | Бор | climate |  | `biomes/pine_wood` | 8 / 5 | ок |
| `biomes:plateau` | Плато | plateau |  | `biomes/plateau` | 4 / 0 | ок |
| `biomes:red_rocks` | Красные скалы | climate |  | `biomes/red_rocks` | 3 / 0 | ок |
| `biomes:rock` | Скалы | rock |  | `biomes/rock` | 3 / 0 | ок |
| `biomes:salt_flat` | Солончак | climate |  | `biomes/salt_flat` | 2 / 0 | ок |
| `biomes:savanna` | Саванна | climate |  | `biomes/savanna` | 6 / 0 | ок |
| `biomes:sea` | Море | sea |  | `biomes/sea` | 1 / 0 | ок |
| `biomes:steppe` | Степь | climate |  | `biomes/steppe` | 5 / 3 | ок |
| `biomes:stony_tundra` | Каменистая тундра | climate |  | `biomes/stony_tundra` | 5 / 0 | ок |
| `biomes:swamp` | Болото | swamp |  | `biomes/swamp` | 8 / 1 | ок |
| `biomes:taiga` | Тайга | climate |  | `biomes/taiga` | 10 / 6 | ок |
| `biomes:tropical_beach` | Тропический берег | beach |  | `biomes/tropical_beach` | 3 / 0 | ок |
| `biomes:tropical_sea` | Тропическое море | sea |  | `biomes/tropical_sea` | 2 / 0 | ок |
| `biomes:tundra` | Тундра | climate |  | `biomes/tundra` | 6 / 1 | ок |

## Старт (`starts`, 1)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:default` | Обычный старт |  | Пустые руки, пустая сумка и костёр у точки появления. | `core`; патчи: `tools/chest` | 2 / 0 | ок |

## Эпохи (`eras`, 7)

| Id | Название | Категория | Описание | Бандл | Связи из / в | Проверка |
|---|---|---|---|---|---|---|
| `core:foraging` | Выживание без инструментов | порядок 0 | Сбор руками, ветки, волокно, камни, ягоды и грибы; простые вещи из них руками. | `core` | 0 / 0 | ок |
| `core:primitive` | Примитивные инструменты | порядок 1 | Верёвка, костёр, верстак, каменные и деревянные инструменты, брёвна и доски, сундук. | `core` | 0 / 4 | ок |
| `core:bone_leather` | Дерево, кости и кожа | порядок 2 | Разделка зверей, сушилка, кожа из шкуры с жиром, костяные игла и клей, свеча, луки и праща, ткань. | `core` | 0 / 4 | ок |
| `core:bronze` | Керамика и ранняя металлургия | порядок 3 | Печь для обжига, кирпич, уголь, горн, медь и медные инструменты. | `core` | 0 / 3 | ок |
| `core:alloy` | Бронза | порядок 4 | Олово, тигель, бронзовый сплав и бронзовые инструменты, которые берут железную руду. | `core` | 0 / 1 | ок |
| `core:iron` | Железо | порядок 5 | Железная руда, сыродутная печь и крица, железные слитки, наковальня и железные инструменты. | `core` | 0 / 4 | ок |
| `core:steel` | Сталь | порядок 6 | Сталь из железа с углём в тигле и стальные инструменты. | `core` | 0 / 1 | ок |

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
