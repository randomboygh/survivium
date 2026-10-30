# Крафт, станки и вещи на клетках

Статус: ACTIVE.

**Назначение.** Какие рецепты персонаж знает, очередь работы у станка, износ и починка инструментов;
вещи, которые стоят на клетках 2×2 и не являются ячейками: сундуки, верстаки, печи, горны, костры.

**Файлы**
- `src/shared/game/workshop.gd` — крафт одного персонажа (`game.workshop`): `stations()`, `recipes()`,
  `why_not(r)`, `start(r, times)`, `cancel`, `update(delta)`, `use_tool`, `repair`; сигналы `changed`,
  `made`.
- `src/shared/game/knowledge.gd` — рецепт известен, когда в сумке побывали все его материалы
  (`look_at`, `knows`); сигнал `learned`.
- `src/shared/game/craft_queue.gd` — очередь: идёт, пока станок рядом; пауза и отмена с возвратом.
- `src/shared/content/crafting.gd` — реестр рецептов: `get_recipe`, `missing`, `has_tool`, `why_not`,
  `take`, `reachable` (всё ли можно сделать из того, что даёт мир), `canon` (старые id).
- `src/shared/game/placed.gd` — вещи на клетках по роли предмета `prop` (`chest`, `workbench`, `kiln`,
  `forge`, `campfire`): `put_from_bag`, `take_up`, `put_out`, `light`, `destroy`, `stations_near`,
  `burns`; твёрдые через `WorldData.blockers`; новый мир начинает с костра и сундука у спавна. Сигналы
  `added`, `removed`, `lit_changed`, `cell_changed`.
- `src/client/game/props.gd`, `src/client/view/voxel_props.gd` — модели вещей и огонь на экране.
- `src/client/ui/craft_panel.gd`, `inventory_window.gd` — вкладка «Крафт» и окно сумки.

**Данные.** Рецепты — вид `recipes` (`makes`, `count`, `needs`, `at` — станок, `tool`, `time`) в бандлах
инструментов и материалов; станок ищется по роли (`Items.with_prop`), топливо костра — по `fuel`
(`Items.fuel_in`); модели — `models/<model>.png`. Износ и починка включаются переключателем
«Тестирования».

**Ограничения.** Виды станков — закрытый список `prop` в схеме: новый вид станка требует кода. Твёрдые
части вещи клиент берёт из её воксельной модели (`Placed.footprints`); серверу их нужно будет отдать
из данных.

**Тесты.** `tests/unit/content_test.gd` (`crafting`), `tests/unit/actions_test.gd` (`placed`),
`tests/unit/character_test.gd` (`wear`), `tests/progress_test.gd` (с пустой сумкой: собирает, ставит
станки и делает каждый рецепт), `tools/validate.gd` (рецепты достижимы из того, что даёт мир).

**Подробнее.** `plan/design/crafting.md`, `plan/design/first-hours.md`, README мода `content/tools/`.
