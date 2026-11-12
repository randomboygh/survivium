# Архитектура

Английская версия: [ARCHITECTURE.md](ARCHITECTURE.md) (она основная, эта — копия).

Статус: ACTIVE, сверено с кодом `main` 2026-11-09 (PR #457). Здесь только то, что есть; замыслы
(редактор, скрипты модов, Android) — в библиотеке, `plan/architecture/`.

## Слои

```mermaid
graph TD
  client["src/client/ — картинка, ввод, звук, UI, сохранение на устройстве"]
  server["src/server/ — сторона сервера: персонаж игрока, его запросы и события"]
  net["src/shared/net/ — протокол: виды запросов, сообщения в байты"]
  game["src/shared/game/ — правила игры"]
  world["src/shared/world/ — мир, генератор, файлы мира"]
  content["src/shared/content/ — загрузчик модов и реестры"]
  data["content/ — данные и ассеты модов"]
  client -. только net/local_host.gd .-> server
  client --> net
  client --> game
  client --> world
  client --> content
  server --> net
  server --> game
  net --> content
  game --> world
  game -. protocol.gd .-> net
  game --> content
  world --> content
  content -. читает .-> data
```

- `src/shared/` — то, что крутит сервер. Он не загружает ничего из `src/client/` и `src/server/`: это
  проверяет `_test_layers` в `tests/unit/content_test.gd`, нарушение валит CI.
- Внутри `src/shared/`: `content/` не грузит других папок `src/`, `world/` грузит только `content/`,
  `net/` — только `content/`, `game/` — `content/`, `world/` и `net/protocol.gd` (табличка чистит текст
  `Protocol.clean_text`, PR #452). Это проверяет тот же `_test_layers` (запрета для `game/` в нём нет).
- `src/server/` грузит только `src/shared/`; клиент грузит `src/server/` только из
  `src/client/net/local_host.gd` — сервера внутри игры для одиночной (решение 153). Что клиент просит
  у правил, идёт запросами протокола через `game.net`; персонаж и мастерская игрока живут на сервере,
  клиент держит их копии по событиям сервера ([systems/network.md](systems/network.md)).
- Папки `src/client/` ссылаются друг на друга свободно (без циклов `preload`): общий стиль UI
  (`ui/ui_style.gd`) нужен вводу и картинке, проекция (`view/pixel_view.gd`) — мешам.
- Скрипты подключаются константой `preload("res://…")` с полным путём, без `class_name`; базовый
  скрипт расширяется `extends "res://…"`. При переносе файла меняются только пути.
- Всё, что `main.gd` грузит через `preload`, компилируется при каждом старте до меню (это большая часть
  запуска, `start_times.gd`). Поэтому экраны, которые открывают не сразу, грузятся по пути при первом
  открытии: `load(CONST_PATH)` вместо `preload` (2026-11-01: настройки `hud.settings_menu()` и
  `main_menu.settings_menu()`, выбор и создание мира, «Присоединиться», «Создать сервер», сервер
  `local_host.gd`, план тестового мира: о нём спрашивают по `WorldStore.TEST_SEED`). Новый такой экран
  делается так же.

Граф по папкам из кода: [DEPENDENCIES.md](DEPENDENCIES_RU.md).

## Точки входа

| Вход | Что запускает |
|---|---|
| `scenes/main.tscn` (главная сцена в `project.godot`) | `src/client/main.gd` — игра |
| `godot --headless --path . -- --server [--port N] [--seed N \| --world <папка>]` (из сборки ПК — `Survivium.console.exe --headless -- --server`) | `scenes/server.tscn` со `src/server/server_main.gd` — сервер без окна ([systems/network.md](systems/network.md)) |
| `godot --headless --path . --script res://tests/<имя>.gd` | тесты, каждый `extends SceneTree` |
| `godot … --script res://tools/<имя>.gd` | инструменты: валидатор, скриншоты, карта, бенчмарки, генераторы ассетов |
| `python3 tools/<имя>.py` | версия сборки, патч web-сборки, рисовалки на Pillow, индекс документов |
| `.github/workflows/build.yml` | CI: линт, проверки, тесты, тест фризов, web- и ПК-экспорт, проверка в Chrome, публикация на Pages и в `pc-latest` ([testing/CI_PIPELINE.md](testing/CI_PIPELINE_RU.md)) |

Тесты и инструменты запускают ту же сцену: создают `main.tscn`, ставят `main.skip_setup = true`
(без меню «Новый мир») и при необходимости `save_root` (свои сохранения).

## Main и модули

`main.gd` только собирает сцену и ведёт кадр; работа живёт в модулях. Клиентский модуль получает узел
Main как `game` (`Controls.new(self)`, `ChunkStreamer.new(self)`…) и через него видит соседей
(`game.world`, `game.clock`, `game.settings`). Общие (shared) модули Main не знают: им передают только
нужное (`Workshop.new(character, placed, rules)`). Правила над миром держит сеанс
(`src/shared/game/session.gd`): он делает `WorldActions`, `Storms` и `Wildlife`, принимает персонажей и
делает тик (каждый кадр узла сервера: в игре — кадр клиента, у сервера без окна — до 60 раз в секунду,
`FPS` в `src/server/server_main.gd`), и заказывает мир (генерация вокруг игроков в
бюджете, забывание дальних чанков); его крутит узел сервера `src/server/runner.gd` под корнем дерева,
раньше Main в каждом кадре ([systems/session.md](systems/session_RU.md)). Сеанс крутится на сервере внутри
игры; виды клиента читают
копии (`game.character`, `game.workshop`, `game.placed`, `game.clock`, `game.wildlife`), которые
`src/client/net/mirror.gd` кормит событиями протокола ([systems/network.md](systems/network.md)).

Порядок сборки (`_ready`, затем `start_world`): ввод и настройки → звук → сохранение (выбор мира) →
`Mods.activate` (набор бандлов мира) → камера, стример чанков, небо, часы, настоящая погода → вещи на
клетках, персонаж, сбор, руки, мастерская, маркеры → интерфейс и меню → генератор (`WorldGen` или
`TestGround`) с картой материалов сохранения → мир и сеанс (звери, действия рук, бури; персонаж входит в
него с мастерской), хост с узлом сервера под корнем дерева → сцена, игрок.

Кадр: узел сервера (до Main): шаги сеанса — часы, персонажи и мастерские, звери, бури — и генерация
чанков в бюджете клиента; `_process` Main: пока мир не готов, достраиваются ближние чанки (затем спавн,
вещи, звери, прогрев шейдеров) → копия часов и небо → события тика (`host.flush`), тело игрока, ввод,
сбор, руки, `input` серверу → следы, автосохранение → срез уровней, меши чанков (за вычетом времени
генерации), крышки, бюджеты узлу на следующий кадр → карта крыши и миникарта → камера, прогрев, журнал
фризов → HUD и экран смерти. Время каждого шага отмечается `perf.note` / `perf.add` (панель F3). Пауза
меню останавливает Main и шаги сеанса, но не узел: мир достраивается дальше (`_build_while_paused`).

## Как правила говорят с картинкой

- Правило получает того, кто действует, как `who` (на клиенте — `src/client/game/character.gd`: тело,
  руки, сумка, сообщения игроку) и спрашивает у него только нужное.
- Что изменилось, правило сообщает сигналами, клиент подключает к ним свои виды:
  `WorldActions.cell_changed` / `looks_changed` / `drops_changed` / `taken` → чанки и вещи на земле;
  `Placed.added` / `removed` / `lit_changed` / `fuel_changed` / `cell_changed` → `props.gd`, огни, чанки;
  `Wildlife.born` / `gone` / `stepped` → `creatures.gd`, следы, голоса; `Inventory.changed`,
  `Workshop.changed` / `made`, `Knowledge.learned`, `SkillSet.leveled`, `Clock.season_changed`,
  `Character.state_changed`
  → интерфейс и звук. На сервере к ним подключён `player_link.gd`, который шлёт события клиенту; копии
  на клиенте (`src/client/net/remote_*.gd`) отдают видам те же сигналы.
- Правила, которые хозяин задаёт всем (свободная стройка, износ, мгновенный крафт), правила читают из
  общего объекта `rules.gd`; в одиночной игре его заполняет `settings.gd`, у сервера — раздел `[rules]`
  его конфига (`src/server/config.gd`).
- Сигнал подключается методом, а не лямбдой с `self`: лямбда держит объект, и RefCounted не
  освобождается (см. `src/shared/game/character.gd`).

## Работа по кадрам

Ничего размером с карту или чанк не делается в одном кадре:
- генератор делает чанк в три стадии (`TERRAIN` → `PLANTED` → `SHAPED`), каждая заданием по ряду или
  дереву (`WorldGen.start` / `step`);
- меши чанков и растения строятся по столбцу ячеек (`ChunkMesher`, `Foliage`);
- генерацию крутит сеанс (`Session.make_chunks`) до кадра, меши — `chunk_streamer.gd` в бюджетах кадра
  за вычетом генерации (правки, затем дальние чанки, затем крышки);
- автосохранение пишет по чанку за кадр, миникарта красит по чанку, прогрев шейдеров — по шагу.

Нарушение ловит `tests/frame_test.gd`. Подробности бюджетов: `plan/architecture/performance.md`.

## Данные и контент

Код просит контент по роли (`Items.with_prop("workbench")`, `Plants.of_kind("ears")`,
`Mat.of_role("ore", …)`, `Biomes.tree(b, roll)`), а не по id; по id названы только записи ядра
(`Mat.GRASS`, `Placed.CAMPFIRE`). Реестры заполняют свои статические переменные при загрузке класса
и пересобираются `Mods.activate` / `refresh`. Подробно: [DATA_MODEL.md](DATA_MODEL_RU.md).

Текст игры: каждый текст для игрока — ключ `[…]` (решение 186); переводы лежат `lang/<код>.yaml` в моде и бандле, сервер
шлёт ключ или `Lang.line`, клиент переводит у себя (решение 183, [systems/lang.md](systems/lang_RU.md)). При
запуске из папки проекта `content_watch.gd` замечает изменённые файлы модов, а модуль `mod_reload.gd`
перечитывает реестры, картинки и звуки (решение 184, [systems/content.md](systems/content_RU.md)).

## Сохранение

Каждая общая система сама отдаёт и принимает своё состояние (`to_dict` / `from_dict`, `to_list`);
клиентский `save_game.gd` решает, когда писать, и регистрирует части игрока `save.track(имя, объект)`;
файлы пишет и старые сохранения переводит общий `world_store.gd` (`materials_of`, `CONTENT`). Подробно: [systems/saving.md](systems/saving_RU.md).

## Как расширять

1. Новая система — новый модуль в папке своего слоя; Main создаёт его и, если нужно, вызывает в кадре.
   Правило, которое идёт во времени (для всех игроков), — шаг сеанса (`session.gd`), не `_process`.
2. Правило — в `src/shared/game/`; его вид и ввод — в `src/client/`; связь — сигналами правила.
3. Новые числа контента — поле схемы в `src/shared/content/content_schema.gd` и YAML мода, не константа.
4. Новый станок или класс инструмента — только данные: `items.prop` и `items.tool` — открытые классы,
   что делает вещь, говорят её флаги (решение 152, [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md));
   работа в мире есть только у девяти классов `Tools.WORLD_KINDS`. Закрытые роли (`plants.kind`,
   `materials.role`, `biomes.where`, `biomes.zone`) новым значением требуют кода.
5. Работа размером с чанк — задание по частям в бюджете `chunk_streamer.gd`.
6. Текст для игрока — ключ `[…]`; новый ключ или запись — его английский и русский в `lang/en.yaml` и `ru.yaml` рядом (`tools/lang_check.py --write en`, `--write ru`).
7. После правки — проверки из `CLAUDE.md`; правила, станки, рецепты, инструменты — ещё `progress_test`.

Решения, на которых это держится, с причинами: [DECISIONS.md](DECISIONS_RU.md).
