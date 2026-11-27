# Моды, граф, отчёты, интерфейс

Английская версия: [mods-interface.md](mods-interface.md) (она основная, эта — копия).

Часть раздела [Моды, бандлы и реестры (код)](../content_RU.md). Набор бандлов, граф контента, отчёты и вызовы, которыми пользуется остальной код.

- `src/shared/content/mods.gd` — набор бандлов игры: `activate`, `rescan` (`live` — горячая перезагрузка), `expand` (старые списки),
  `RENAMED`; набор сохранённого мира `of_world` (моды, выделенные из базы, `SPLITS`; дополняющие бандлы,
  `additive`, `OLD_ADDITIVE`); `why` (почему бандл выпал, вся цепочка); названия для экрана «Моды».
- `src/shared/content/content_graph.gd` — граф контента (`ContentGraph`): пути, которыми вещи появляются
  (мир, старт, действие с инструментом по правилам `Tools`, рецепт, станок, посадка), достижимость со старта
  с глубиной (`reached`) и эпохой (`era`: тем же проходом `_settle`, не раньше записанной у предмета),
  `basis(key, by_era)` — из чего вещь выходит; ошибки (нет источника, не достать, рецепт не сделать, не
  растёт, нет корма, замкнутый круг, эпоха раньше пути) и предупреждения (тупик, станок одного рецепта,
  двойники, прибыльный круг, материал не встречается, длинная цепочка для эпохи). Строят только валидатор,
  отчёты и тесты, игра — нет.
- `tools/content_report.gd` — отчёты из загруженных данных: реестр сущностей
  `docs/generated/content-index.md` (с эпохой предметов и рецептов), граф `content-graph.md` (с картой эпох
  и ветками прогресса), реестр рецептов `content-recipes.md`, проверки `content-checks.md`; `-- --check` для
  CI.
- Реестры (заполняют static var при загрузке класса и в `refresh`): `materials.gd` (`Mat`), `items.gd`,
  `crafting.gd`, `trees.gd`, `bushes.gd`, `plants.gd`, `biomes.gd`, `ai_rules.gd`, `starts.gd` (старт нового
  мира: `Starts.START` — умения рук, сумка, лагерь; `check`), `eras.gd` (эпохи по порядку: `Eras.ERAS`, `rank`, `title`, `check` — две
  эпохи одного порядка), `skills.gd` (навыки: `Skills.ALL` по порядку, `of_role`, `need`, `level_at`,
  `progress`); `tools.gd` — правила инструментов над `Items` и `Mat` (без своего вида
  данных; руки `HAND` собирает из полей `hand_*` старта в `refresh`): что чем добывается (`can_dig`, `can_chop`, `can_dig_out`, `can_knock`, `can_gather`, `mows`),
  работа в мире девяти классов `WORLD_KINDS` (с удочкой `rod`, тяпкой `hoe`, серпом `sickle`, лейкой `can`) (любой другой класс там — руки), `holds(inv, класс)`,
  `held_of(inv, класс)`.

**Интерфейс**
- `Content.records_of(kind, bundles)` — записи незагруженного набора (загруженные из него как есть, остальные из их файлов со значениями по умолчанию, без патчей; реестры не трогаются: карта «Нового мира» через `Biomes.refresh(only)`), `Content.records(kind)`, `Content.find(kind, id)` (по указателю `_at`, без перебора), `Content.record_count()`,
  `Content.schema(kind)` (поля вида и общие),
  `Content.refs(kind)` (поля-ссылки, и поля записей внутри `entries` как `camp.item`), `Content.named(r, key)`,
  `Content.canon(kind, id)` (старый id из `was` — в нынешний), `Content.origin(kind, id)` (кто определил,
  заменил, поправил),
  `Content.asset(rec, "sprites/x.png")` (бандл, затем `common/` мода), `Content.problems`,
  `Content.warnings` (имена против правил), `Content.loaded`, `Content.dropped[b]` (почему выпал),
  `Content.read_ms` / `load_ms` (сколько длились последнее чтение `content/` и последняя загрузка набора: строка
  «Загрузка» в «Данных для теста»).
- `Content.all_bundles()`, `available()`, `bundles_of(mod)` (из скана `content/`, не с диска: новую папку видит
  `refresh`), `mod_of(b)`, `deps(b)`, `closure(b)`, `resolve(set)` (порядок Кана: из готовых первым идёт
  стоящий раньше в скане). `Content.generation` растёт с каждой загрузкой; `Mods.activate` пересобирает
  реестры, если они собраны с другой загрузки (после прямого `Content.refresh`).
- `Mods.activate(bundles)` — сделать набор мира текущим и пересобрать реестры; `Mods.rescan()` —
  перечитать `content/` (кнопка на «Тестировании»); `Mods.expand(list)` — старые id модов в бандлы;
  `Mods.of_world(meta)` — бандлы мира по его `world.json`, с вошедшими с тех пор дополняющими (решение 4А);
  `Mods.missing(meta)` — чего он перечисляет, а здесь нет (такой мир не открывается,
  [saving.md](../saving_RU.md)); `Mods.additive(b)` — в бандле только предметы, рецепты, эпохи, старт и звуки; `Mods.why(b, dropped)` —
  чего бандлу не хватает и чего не хватает тому, до выключенного.
- Реестры: `Mat.GRASS` и др. (только ядро), `Mat.of_role`, `Mat.index`, `Mat.remap`; `Items.get_item`,
  `with_prop`, `with_tool`, `tool_title` (ключ класса инструмента `[tool.<класс>]`),
  `is_station`, `most_storage`, `of_category`, `fuel_in`, `canon`; `Crafting.get_recipe`, `canon`, `outputs` (что
  даёт работа с номером n: изделие и побочное по шансу), `possible` (у каждого класса инструментов рецепта
  есть предмет в мире; иначе рецепт не узнают и не показывают); `Trees.first`, `Trees.any`; `Bushes.first`; `Plants.of_kind`; `Biomes.pick`, `tree`, `bush`;
  `AiRules.SPECIES`, `is_food`, `is_threat`; `Starts.START` (`hand_*`, `bag`, `camp`); `Tools.HAND`.
- `ContentGraph.new()` — граф набора, загруженного сейчас: `reached` (ключ «вид/id» → глубина), `how` (путь
  этой глубины), `sources`, `uses`, `basis(key)` (из чего вещь получается), `able(way)` / `by_hand(way)` (чем
  сделать действие пути), `errors`, `warnings`, `findings` (проверка, текст, записи), `cycles()`.
