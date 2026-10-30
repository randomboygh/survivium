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
- `src/shared/content/crafting.gd` — реестр рецептов: `get_recipe`, `missing`, `has_tool`, `why_not`
  («Нужен инструмент: …» по `Items.tool_title`), `take`, `canon` (старые id), `check` (станок каждого рецепта
  — станок). Можно ли сделать каждый рецепт со
  старта, решает граф контента `content_graph.gd` ([content.md](content.md)).
- `src/shared/game/placed.gd` — вещи на клетках по роли предмета `prop` (`chest`, `workbench`, `kiln`,
  `forge`, `campfire`): `put_from_bag`, `take_up`, `put_out`, `light`, `destroy`, `stations_near`,
  `burns`; твёрдые через `WorldData.blockers`; новый мир начинает с лагеря старта у спавна
  (`start_camp` по `Starts.START.camp`: костёр, сундук — патч бандла сундука). Сигналы
  `added`, `removed`, `lit_changed`, `cell_changed`.
- `src/client/game/props.gd`, `src/client/view/voxel_props.gd` — модели вещей и огонь на экране.
- `src/client/ui/craft_panel.gd`, `inventory_window.gd` — вкладка «Крафт» и окно сумки.

**Данные.** Рецепты — вид `recipes` (`makes`, `count`, `needs`, `at` — станок, `tool`, `time`) в бандлах
инструментов и материалов; станок ищется по роли (`Items.with_prop`), топливо костра — по `fuel`
(`Items.fuel_in`); модели — `models/<model>.png`. Износ и починка включаются переключателем
«Тестирования».

**Станки флагами.** `prop` — открытый класс вещи (модель, твёрдые части), а что она делает — флаги
предмета: `storage` (хранит вещи, сундук: 16 мест; такая вещь не станок), `fire` (горит: тушится,
разжигается топливом, обжигает), `repairs` (у неё чинят инструменты: верстак), `serves` (заменяет названные
станки: их рецепты и починка), `place_tool` (ставится, только если в сумке инструмент этого класса).
`Placed` и `Workshop` спрашивают флаги; новый станок — одни данные: предмет, модель, иконка, рецепты.

**Ограничения.** Твёрдые
части вещи клиент берёт из её воксельной модели (`Placed.footprints`); серверу их нужно будет отдать
из данных.

**Тесты.** `tests/unit/content_test.gd` (`crafting`), `tests/unit/actions_test.gd` (`placed`, `station_flags` —
станок другого класса, который заменяет верстак и ставится с ножом, ящик на 4 места, починка по флагу),
`tests/unit/character_test.gd` (`wear`), `tests/progress_test.gd` (с пустой сумкой: собирает, ставит
станки и делает каждый рецепт), `tests/unit/graph_test.gd` и `tools/validate.gd` (граф: каждый рецепт
достижим со старта с инструментами добычи, без замкнутых кругов). Что из чего и на каком станке —
`docs/generated/content-graph.md`.

**Подробнее.** `plan/design/crafting.md`, `plan/design/first-hours.md`, README мода `content/tools/`.
