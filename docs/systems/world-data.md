# Данные мира: ячейки, формы, трава

Статус: ACTIVE.

**Назначение.** Хранить ячейки мира по чанкам и всё, что стоит и лежит на них; вычислять формы
природной земли (склоны, скошенные углы) и отвечать, что встречает тело.

**Файлы**
- `src/shared/world/world_cells.gd` — ячейки в `Chunk` по ключу (`chunk_at`, `chunk_key`; для
  отрицательных координат `>>` и `&`); отсутствующий чанк читается как воздух (ниже 0 — камень) и не
  пускает тела. На ячейках: деревья, кусты, `blockers` (твёрдые части вещей), `drops` (лежащее), `grows`
  (что растёт), тропы; `track_edits` / `note_edit`, `pack_chunk` / `unpack_chunk` для сохранения.
- `src/shared/world/world_data.gd` (наследует) — формы: `update_shapes` (склоны и углы по столбцу),
  поверхности склонов (`surface_patch`, `ground_height`), что встречает тело (`blocks_body`,
  `blocks_part`, `ground_part`).
- `src/shared/world/grass.gd` — что растёт на верху ячейки земли (ярусы травы, цветы, колосья, мох,
  растения модов `Plants`), облака-шум для теней.
- `src/shared/world/voxel_raycast.gd` — луч по сетке ячеек (Amanatides & Woo), для выбора клетки.

**Интерфейс.** `get_cell` / `set_cell` / `set_material`, `is_natural`, `in_bounds`, `add_tree`,
`remove_tree`, `add_bush`, `add_drop` / `heap_drop` / `take_drop`, `tread` / `trail`, `column_masks`,
`padded`, `biome_at` (биом столбца из `Chunk.biome`, `NO_BIOME` без него); `is_solid`, `blocks_body`, `ground_height`, `surface_height`, `corner_cuts`;
`Grass.kinds`, `plants_on`, `has_tall`; `VoxelRaycast.cast`. Константы: `CELL` (0,5 единицы мира,
8 px), `CHUNK` (16), `SNOW_LINE` (18).

**Кто использует.** Всё, что касается мира: генератор пишет, меши читают, правила (`world_actions`,
`body`, `wildlife`, `placed`) читают и меняют. `world_data.gd` — 37 зависимых файлов.

**Ограничения и подводные камни**
- Никогда не используйте -1 как «нет» для координат мира: отрицательные координаты настоящие.
- Чанк — 16×16 ячеек на всю высоту (48 уровней); сериализация чанка — `pack_chunk` / `unpack_chunk`,
  формат меняется только с переводом старых сохранений.
- Формы пересчитываются по столбцам и только для природной земли (`set_natural`): поставленные блоки
  остаются кубами.

**Тесты.** `tests/unit/shapes_test.gd` (`corners`, `shapes`), `tests/unit/body_test.gd` (`raycast`,
`slopes`, `steps`, `ground`), `tests/unit/generation_test.gd`.

**Подробнее.** `plan/architecture/simulation.md` (раздел «Хранение мира»), `plan/design/landscape.md`.
