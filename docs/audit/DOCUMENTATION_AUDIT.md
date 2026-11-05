# Аудит документации (этап 6)

Статус: ACTIVE до решения вопросов из [DOCUMENTATION_UPDATE_REPORT.md](DOCUMENTATION_UPDATE_REPORT.md);
потом — ARCHIVED. Задание: `documentation_audit.md` в корне библиотеки проекта. Аудит 2026-11-05, `main`
ad41a53 (PR #372 слит, клиент 0.2.372). Что исправлено — [DOCUMENTATION_UPDATE_REPORT.md](DOCUMENTATION_UPDATE_REPORT.md).

Прошлая сверка документов с кодом — 2026-11-03 (PR #334, решения 154–162). После неё слиты PR #335–#372:
строительство, навыки, вид в пещере слоями, тестирование и CI этапа 5, огни в темноте, окна и двери разных
размеров, площадки тестового мира. Аудит искал, что эти PR оставили устаревшим, и заодно — давние
расхождения.

## 1. Как проверялось

Источник истины — по разделу 11 ТЗ: код и данные, затем конфигурации (`project.godot`,
`export_presets.cfg`, `.github/workflows/build.yml`), затем тесты.

| Проверка | Как | Итог |
|---|---|---|
| Пути и ссылки | `python3 tools/doc_index.py --check`: каждый путь репозитория и каждая markdown-ссылка в `CLAUDE.md`, `README.md`, `docs/`, README модов | до правок 0 битых; после — 0 |
| Имена в коде | скрипт (не в репозитории): каждое `Имя.член` в обратных кавычках документов сверено с константами `preload` всех скриптов и членами скрипта и его базы (`func`, `var`, `const`, `signal`, `enum`) | 7 промахов: `Hud.toggle_land`, `PersonPanel.SEGMENTS`, `PersonPanel.SKILL_OF` (устарели), `Mat.reload`, `Crafting.TOOL_NAMES`, `Crafting.reachable` (названы нарочно как то, чего нет) |
| Имена тестов | каждое `` `имя` `` в скобках после `*_test.gd` сверено с `func _test_имя` | промахов нет (кроме имён событий протокола в `network.md`, которые тестами не являются) |
| Файлы без описания | каждый `.gd` и шейдер под `src/` и `shaders/` ищется по имени в документах | все описаны; шейдеры — списком в `systems/rendering.md`, `touch_*.gd` — через `controls.gd` |
| Примеры YAML | ключи блоков ```` ```yaml ```` в `BUNDLE_SYSTEM.md` и README модов сверены со схемами `SCHEMAS` и `COMMON` | неизвестных ключей нет |
| Числа контента | данные загружены как в игре (`Mods.activate` всех бандлов, Godot 4.5.1 headless) | 28 материалов, 185 предметов, 139 рецептов, 20 пород, 6 кустов, 14 растений, 23 существа, 28 биомов, 7 эпох, 9 навыков, 56 звуков, 9 модов, 156 бандлов; атлас — 28 материалов и 8 кор = 36 из 63 |
| CI и тесты | `build.yml` (задания, матрицы, условия), `tests/run_tests.gd` (`FILES`), `tests/run_all.sh`, `tests/browser_smoke.mjs`, `tests/frame_test.gd` | совпадает с `docs/testing/`, кроме мелочей ниже |
| Чтение | каждый документ ниже прочитан и сверен с кодом по своим утверждениям | находки — разделы 2–7 |

## 2. Проверенные документы

Репозиторий — все 53 markdown-файла, кроме сгенерированных `docs/generated/*` (их пишут
`tools/doc_index.py` и `tools/content_report.gd`, свежесть проверяет CI):

- корень: `CLAUDE.md`, `README.md`, `.github/pull_request_template.md`;
- `docs/`: `INDEX.md`, `PROJECT_OVERVIEW.md`, `PROJECT_MAP.md`, `ARCHITECTURE.md`, `SYSTEMS.md`, `DATA_MODEL.md`,
  `DEPENDENCIES.md`, `DECISIONS.md`, `ROADMAP.md`;
- `docs/systems/` — все 18 контекстов (audio, character, chunks, content, crafting, interaction, network,
  rendering, saving, session, territory, testing, time-weather, ui, wildlife, world-data, world-generation);
- `docs/specifications/`: `BUNDLE_SYSTEM.md`, `BUNDLE_SYSTEM_READINESS.md`;
- `docs/testing/`: `TESTING_GUIDE.md`, `TEST_COVERAGE.md`, `CI_PIPELINE.md`;
- `docs/audit/` (7 отчётов) и `docs/planning/` (2 плана) — только статус и ссылки: это отчёты на свою дату;
- README всех модов (`content/*/README.md`, `content/animals/sparrow/README.md`).

Библиотека (`plan/`): `README.md` (оглавление и журнал решений), `mvp.md`, `backlog.md`,
`architecture/testing-tools.md` — сверены; `design/*`, остальные `architecture/*`, `history/*` — только
поиском по устаревшим словам («нет», «заглушка», «по умолчанию», «сервера нет»): это замысел и история,
код они не описывают (решение 151).

Комментарии в коде проверялись там, где документ на них ссылается (описание `##` первой строки попадает в
`docs/generated/code-index.md`); расхождений комментария с кодом не найдено.

## 3. Устаревшие сведения

| Где | Что было написано | Как на самом деле (источник) |
|---|---|---|
| `CLAUDE.md` | сервер «does not exist yet»; в дереве нет `src/server/`, `src/shared/net/`, `src/client/net/` | сервер построен (решение 153, `src/server/`), одиночная игра — сервер в том же процессе |
| `CLAUDE.md`, `ARCHITECTURE.md` | `who` правила — `src/client/game/character.gd` | на сервере `src/server/player.gd` (наследует общий `character.gd`); клиентский — копия |
| `CLAUDE.md` | атлас: «28 are used» | 36: 28 материалов и 8 разных кор (`Mat.COUNT` + кора, `tools/validate.gd`) |
| `docs/DATA_MODEL.md`, `systems/content.md` | «занято 21» | 36 |
| `systems/chunks.md` | «материалов и кор вместе не больше 21» | не больше 63 (`PixelTextures.MOST_MATERIALS`) |
| `README.md` | 15 пород, 16 видов зверей; «строить блоками»; «M — карта»; «Что нового» — в «Тестирование» | 20 пород, 22 вида; стройка по чертежу, двери, окна, мебель; клавиши M нет (карта — касание миникарты, `minimap.gd` `open_map`); «Что нового» — кнопка главного меню (#366) |
| `PROJECT_OVERVIEW.md` | «Нет: строительства предметами, навыков (заглушки)»; 25 материалов, 165 предметов, 119 рецептов, 146 бандлов | строительство (решение 163) и навыки (164) есть; числа — раздел 1 |
| `DATA_MODEL.md` | столбец «Сейчас»: 13 материалов, 56 предметов, 28 рецептов, 17 существ, 15 пород, 5 кустов, 12 растений, 15 биомов, 4 эпохи; моды: `animals` 16, `biomes` 15, `plants` 32; `world.json` без `territory` и `plans` | числа — раздел 1; `save_game.gd` и `server_store.gd` пишут `territory`, `plans` (сервер ещё `teams`, `fights`, `next_player`) |
| `ARCHITECTURE.md` | «сервер будет звать 20 раз в секунду»; «сервер заполнит из конфига»; «новая роль станка или инструмента требует кода»; статус «на 2026-10-30, замыслы: сервер, сеть» | тик — каждый кадр `runner.gd` (сервер без окна — `FPS` 60, `server_main.gd`); правила сервера — раздел `[rules]` конфига (`config.gd`); `prop` и `tool` — открытые классы (решение 152) |
| `systems/session.md` | «будет крутиться 20 раз в секунду»; статус «этапы С1–С2.3» | см. выше; С1–С7 построены |
| `DECISIONS.md` | № 2 «сервера пока нет, принято, не сделано»; № 153 «сети пока нет (этапы С2–С7), действует (С1)»; журнал № 1–152 | сервер и сеть есть; журнал до № 164 (и 165–167 после этого аудита) |
| `DEPENDENCIES.md` | загрузки правил shared без `growth`, `felling`, `warmth`, `skill_set`, `tools`, `starts`…; `Workshop.new(…, settings)` в Main | загрузки — по `preload` в коде; мастерскую делает `player_link.gd`, правила — `rules` сеанса |
| `PROJECT_MAP.md` | `export_presets.cfg` — «web-экспорт (единственный)»; число зависимых 41/32/37 | пресеты Web, Windows Desktop, Linux; зависимых больше 40/50 (`doc_index.py uses`) |
| `ROADMAP.md` | Т8 «переезд на этапе С3»; Т9 размеры ≈1000–1130 строк; Т10 «нет серверной сборки»; Т11 без нижнего предела | Т8 не сделан; файлы выросли до 1672 строк; сервер проверяет `server_test`, ПК-сборки в CI; пределы `IDLE_FLOOR` 1,25 и `NIGHT_FLOOR` 1,55 мс (#370) |
| `SYSTEMS.md` | «Чего нет»: «нет мебели»; в строках нет `warmth.gd`, `server_list.gd`, вида в пещере | мебель и камин есть (#339, #371) |
| `systems/ui.md` | навыки в окне — «пример», `PersonPanel.SEGMENTS`, `SKILL_OF`, «пока навыков нет»; в меню нет «Что нового»; smoke падает на SCRIPT ERROR / Parse Error | девять навыков (`Skills.ALL`, `PersonPanel.ROLE_OF`, `POWER_PER_LEVEL`); кнопка «Что нового» (`MainMenu._open_changes`); smoke ловит ещё SHADER ERROR и `Invalid call/access/get/set` (#362) |
| `systems/territory.md` | разметку включает «кнопка с флагом вверху (`Hud.toggle_land`)» | касание своего столба или его квадрата (`Land.tap_post`, `toggle_painting`) |
| `systems/rendering.md` | «разрез по камере (по умолчанию)» рядом с «слои (по умолчанию)» | по умолчанию «слои» (`cave_mode` 0, `settings.gd`) |
| `systems/network.md` | прямой доступ к серверным объектам «до С4 и С5» | так и осталось: работает только с сервером в том же процессе |
| `systems/interaction.md`, `crafting.md` | тесты `actions_test` без `stairs_placed`, `furniture`, `openings` | эти функции есть и вызываются (#372) |
| `systems/content.md` | тесты `content_test` без `parsed_cache`, `recipe_mistakes`; классы инструментов в мире — пять | функции есть; шесть классов с `rod` (`Tools.WORLD_KINDS`) |
| `specifications/BUNDLE_SYSTEM.md` | раздел 4 «Есть сейчас» на 2026-10-30 (нет одежды, оружия, строительства); эпохи 4–7 «iron, steel, gunpowder, electricity», записи только у 0–3; «пять классов»; станок «на клетки 2×2»; «несколько руд — с правкой генератора»; «следующий шаг — хранить разобранные данные» | эпохи 0–6 `foraging…alloy, iron, steel` (`eras.yaml`); шесть классов; размер по модели; руды по `veins`; разобранный YAML в `content_cache.bin` с #285 |
| `content/tools/README.md` | «пять классов `tool`» | шесть (`rod`) |
| `content/biomes/README.md`, `content/animals/README.md` | 18 биомов; без рыб и «Добычи» | 28 биомов; бандлы `animals/fish`, `animals/game` |
| `plan/mvp.md` | задача 7 «Строительство» не отмечена сделанной; состояние только до #333 | сделано (#335–#339, #371, #372) |
| `plan/backlog.md` | «Вид в пещере» по умолчанию — срез в плоскости камеры | по умолчанию «слои» (#345) |
| `plan/architecture/testing-tools.md` | «Сейчас есть (2026-10-20)» без lint, parse, progress, server_test, ПК-сборок | см. `docs/testing/` |
| `plan/README.md` | журнал без решений о виде в пещере, тестах и CI этапа 5, огнях в темноте; список ТЗ — только этапы 0 и бандлов | решения 165–167 записаны по тредам и PR |

## 4. Противоречия между документами

1. `CLAUDE.md` («server does not exist yet») против `README.md`, `PROJECT_OVERVIEW.md`, `systems/network.md`
   (сервер есть).
2. Атлас: `CLAUDE.md` 28, `DATA_MODEL.md` и `content.md` 21, `chunks.md` «не больше 21», код — 36 из 63.
3. `ARCHITECTURE.md` «новая роль станка или инструмента требует кода» против `DATA_MODEL.md` и
   `BUNDLE_SYSTEM.md` (открытые классы).
4. `rendering.md`: два режима «по умолчанию» в одном разделе.
5. `DECISIONS.md` (№ 2, 153: «не сделано», «С1») против `SYSTEMS.md` и `ROADMAP.md` (С1–С7 построены).
6. `ARCHITECTURE.md` `Workshop.new(character, placed, rules)` против `DEPENDENCIES.md`
   `Workshop.new(character, placed, settings)` — в коде `Workshop.new(who, placed, rules)` в `player_link.gd`.
7. Решение 163 в журнале («лестница — ступенчатая ячейка») против кода (лестница — вещь на клетке с
   `steps`): расхождение замысла и реализации, отмечено в журнале строкой «сделано», текст решения не
   переписан.

## 5. Отсутствующие описания

- `src/shared/game/warmth.gd`, `src/client/net/server_list.gd` — описаны в своих контекстах, но не названы в
  `SYSTEMS.md`; `cave_layers.gd`, `cave_sphere.gd`, `solid_map.gd`, `plan_view.gd`, `land_view.gd` — не в
  списке файлов `rendering.md`; шейдеры `land`, `cave_sphere`, `cave_sphere_debug` — не в списке шейдеров.
- Точка входа сервера без окна (`-- --server`, `scenes/server.tscn`) — не в таблице точек входа
  `ARCHITECTURE.md` (была только в `CLAUDE.md` и `network.md`).
- `SkillSet.leveled`, `Placed.fuel_changed`, `Plans.changed` — не в списке сигналов `ARCHITECTURE.md` и
  схеме `DEPENDENCIES.md`.
- Сервер в `systems/saving.md` (`server_store.gd`).
- Связи `starts_with` и `items.ammo` (`consumes`) — не в таблице связей `BUNDLE_SYSTEM.md`.
- `TESTING_GUIDE.md`: что запускать после правки стройки и шейдеров.
- В `CLAUDE.md`: где лежат `docs/testing/` и что `docs/audit/`, `docs/planning/` — история.

## 6. Дубликаты и навигация

- Числа контента повторяются в `README.md`, `PROJECT_OVERVIEW.md`, `DATA_MODEL.md`, `plan/mvp.md`. Это
  сводки для разных читателей; оставлены, с датой и ссылкой на `generated/content-index.md` (там они
  считаются сами). Таблица эпох в `BUNDLE_SYSTEM.md` дублировала «Карту эпох» генератора и устарела —
  заменена списком записей и ссылкой.
- Описание CI есть в `systems/testing.md` (сводка) и `testing/CI_PIPELINE.md` (полное): сводка ссылается на
  полное, противоречий нет — оставлено.
- `docs/INDEX.md`: одна плоская таблица без статусов; отчёты этапов 0, 4, 5 стояли со статусом ACTIVE, хотя
  это снимки на дату (в них «нет», «будет» и пути того дня); строка библиотеки «Замыслы, ещё не сделанные:
  сервер, сеть… территории» устарела; нет ТЗ этапов 4–6.
- Временных заметок, документов без назначения и битых ссылок в репозитории не найдено.

## 7. Ошибки и пробелы в коде (не исправлялись: этап не меняет код)

1. **Т8**: `src/shared/game/real_weather.gd` (HTTP-сервис устройства) лежит в общей папке, его создаёт
   клиентский `main.gd`; решение 153 переносило погоду с улицы на сервер (этап С3) — не сделано. Сервер без
   окна настоящую погоду не спрашивает; у клиента на чужом сервере узел пишет в часы, которых нет у сеанса.
   Задача кода.
2. **Т9**: крупные файлы выросли: `world_actions.gd` 1672 строки, `main_menu.gd` 1523, `content.gd` 1490,
   `hud.gd` 1397, `ui_style.gd` 1315. Деление — изменение структуры, нужен выбор пользователя.
3. Серьёзных ошибок реализации, которые требовали бы отдельного срочного исправления, аудит не нашёл.

## 8. Документы, оставленные без изменений, и почему

| Документ | Почему |
|---|---|
| `systems/audio.md`, `world-data.md`, `world-generation.md`, `time-weather.md`, `wildlife.md` | сверены, расхождений нет (последние PR правили их сами) |
| `testing/CI_PIPELINE.md`, `testing/TEST_COVERAGE.md` | совпадают с `build.yml` и тестами |
| `audit/PERFORMANCE_REPORT.md`, `audit/REFACTORING_REPORT.md`, `planning/REFACTORING_ROADMAP.md` | уже DONE, это отчёты на дату |
| `docs/generated/*` | пишутся генераторами, свежесть проверяет CI |
| README модов `core`, `materials`, `music`, `plants`, `resources`, `sounds`, `animals/sparrow` | совпадают с данными |
| `.github/pull_request_template.md` | одна строка «Что нового», верна |
| `plan/design/*`, `plan/architecture/*` (кроме `testing-tools.md`), `plan/history/*` | замысел и история, не описание кода; статусы в оглавлении `plan/README.md` верны |
