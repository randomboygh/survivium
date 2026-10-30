# Моды, бандлы и реестры (код)

Статус: ACTIVE. Модель данных (виды, id, роли, сохранения): [../DATA_MODEL.md](../DATA_MODEL.md).
Здесь — код загрузчика и реестров.

**Назначение.** Найти моды и бандлы под `content/`, выбрать набор мира с зависимостями, прочитать YAML,
проверить записи по схемам, наложить патчи и заполнить реестры, через которые остальной код видит
контент.

**Файлы**
- `src/shared/content/content.gd` — `SCHEMAS` всех видов, `MOD_SCHEMA`, `BUNDLE_SCHEMA`; поиск модов и
  бандлов, `resolve` (порядок и выпавшие бандлы), загрузка, патчи, проверка ссылок, `asset`,
  `sound_files`.
- `src/shared/content/yaml.gd` — свой разбор той части YAML, что нужна данным (ключи с `:` внутри,
  `{core:fiber: 1}`).
- `src/shared/content/mods.gd` — набор бандлов игры: `activate`, `rescan`, `expand` (старые списки),
  `RENAMED`, названия для экрана «Моды».
- Реестры (заполняют static var при загрузке класса и в `refresh`): `materials.gd` (`Mat`), `items.gd`,
  `crafting.gd`, `trees.gd`, `bushes.gd`, `plants.gd`, `biomes.gd`, `ai_rules.gd`; `tools.gd` — правила
  инструментов над `Items` и `Mat` (без своего вида данных).

**Интерфейс**
- `Content.records(kind)`, `Content.find(kind, id)`, `Content.asset(rec, "sprites/x.png")` (бандл, затем
  `common/` мода), `Content.problems`, `Content.loaded`, `Content.dropped[b]` (почему выпал).
- `Content.all_bundles()`, `bundles_of(mod)`, `mod_of(b)`, `deps(b)`, `closure(b)`, `resolve(set)`.
- `Mods.activate(bundles)` — сделать набор мира текущим и пересобрать реестры; `Mods.rescan()` —
  перечитать `content/` (кнопка на «Тестировании»); `Mods.expand(list)` — старые id модов в бандлы.
- Реестры: `Mat.GRASS` и др. (только ядро), `Mat.of_role`, `Mat.index`, `Mat.remap`; `Items.get_item`,
  `with_prop`, `with_tool`, `of_category`, `fuel_in`, `canon`; `Crafting.get_recipe`, `reachable`,
  `canon`; `Trees.first`, `Trees.any`; `Bushes.first`; `Plants.of_kind`; `Biomes.pick`, `tree`, `bush`;
  `AiRules.SPECIES`, `is_food`, `is_threat`.

**Кто использует.** Почти всё: `materials.gd` грузят 41 файл, `items.gd` — 32, `content.gd` — 17.
Правка схемы или реестра затрагивает генератор, меши, правила и UI.

**Данные.** `content/<мод>/mod.yaml`, `content/<мод>/<бандл>/bundle.yaml`, `data/<вид>.yaml`. Смысл
полей — комментарий в начале каждого YAML и схема в `content.gd`.

**Как добавить**
- Поле: строка в `SCHEMAS[вид]` (тип, `default`, `min`/`max`, `soft` для мягкой ссылки), чтение в
  реестре, комментарий в YAML, проверка в `tests/unit/content_test.gd`.
- Вид данных: схема в `SCHEMAS`, новый реестр со `refresh()`, вызов его в `Mods._refresh_registries`,
  проверка в `tools/validate.gd`.
- Бандл с готовыми ролями — только данные и ассеты, код не нужен (пример: `content/animals/sparrow/`).

**Подводные камни**
- Статическая функция с именем метода `Script` (`reload`, `get_class`, `is_tool`) затеняется:
  `Mat.reload()` перекомпилирует скрипт. Поэтому `Mods.rescan`, а не `reload`.
- `const X := Mat.GRASS` — ошибка разбора: номера материалов известны только после загрузки.
- Номера материалов идут в порядке загрузки: набор бандлов мира менять нельзя, старый мир переводится
  `Mat.remap` по списку `materials` из `world.json`.
- Ссылка без пространства имён значит «тот же мод»; в патче чужой записи ссылку пишите полностью.
- Возврат с типом своего же скрипта (`-> VoxelModel`) без `class_name` — ошибка разбора, на которой
  инструменты `make_*` молча висят; сначала `--check-only`.
- Атлас материалов полон: 13 материалов и 8 разных кор = 21 из 21 (`PixelTextures.MOST_MATERIALS`:
  номер плитки — 6 бит в меше; `uniform int material_bits[21]` в `world.gdshader`). Новый материал
  или своя кора в любом бандле валит `validate.gd`; поднять предел — правка упаковки мешей и шейдера.

**Тесты.** `tests/unit/content_test.gd` (`yaml`, `content`, `mods`, `items`, `tools`, `crafting`, `layers`),
`tools/validate.gd` (каждый бандл отдельно, звуки, картинки в руках, иконки, текстуры, модели, листы
существ; строгий режим: мягкая ссылка в пустоту — тоже ошибка), `tests/progress_test.gd` (все рецепты
достижимы игрой).

**Известные проблемы.** Роли — закрытые списки (`items.tool`, `items.prop`, `plants.kind`,
`materials.role`, `biomes.where`), новая роль требует кода. Голоса зверей синтезирует таблица в
`tools/make_sounds.gd`, бандл приносит только готовые `.wav`.

**Подробнее.** `plan/architecture/modding.md`; решения 140, 142, 143, 146 в `plan/README.md`; README
каждого мода.
