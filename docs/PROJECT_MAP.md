# Карта проекта

Статус: ACTIVE. Полный список скриптов с их назначением: [generated/code-index.md](generated/code-index.md).

## Каталоги

```
project.godot            настройки движка: главная сцена, версия стадии, глобальные параметры шейдеров
export_presets.cfg       web-экспорт (единственный), html head_include со стилями загрузки
default_bus_layout.tres  звуковые шины (web копирует их при старте: новые шины только здесь)
scenes/main.tscn         главная сцена: узел Main со скриптом src/client/main.gd; server.tscn — сцена сервера из терминала (--server)
src/shared/              мир и правила игры; их запустит сервер; ничего не грузит из src/client/
  content/               загрузчик модов (content, yaml, mods) и реестры видов данных
  world/                 ячейки и чанки, формы земли, раскладка и генератор, сохранения на диск, трава, тестовый мир
  game/                  правила: сумка, силы, персонаж, тело, действия рук, вещи на клетках, крафт, часы, погода, бури, звери
  net/                   протокол клиента и сервера: виды запросов, сообщения в байты; грузит только content/
src/server/              сторона сервера: узел с тиком и генерацией под корнем дерева (runner.gd), персонаж игрока (player.gd), его линк с событиями (player_link.gd), запросы к правилам (requests.gd), сервер по сети (server.gd: порт, вход, связи, команды; server_main.gd — корень сцены сервера, config.gd, console.gd, tunnel.gd — доступ из интернета через cloudflared); грузит только src/shared/
src/client/              картинка, ввод и звук этого устройства; main.gd, settings.gd, save_game.gd
  world/                 чанки на экране: стример, меши (ячейки, склоны, вода, стволы), трава и кроны, сугробы, следы, карта крыши
  view/                  проекция, камера, небо и свет, огни и тени, лучи, текстуры, воксельные модели, игрок и его лист, другие игроки, прогрев шейдеров
  input/                 клавиши, мышь, касания, рамка-курсор, джойстик и кнопки
  game/                  клиентские части систем: персонаж игрока, сбор, вещи и звери на экране, маркеры карты
  net/                   соединение с сервером (connection.gd), сокет к серверу по сети (socket.gd), сервер внутри игры (local_host.gd — единственный, кто грузит src/server/), копии мира (remote_gen.gd: чанки с сервера), мастерской, вещей на клетках, часов и зверей (mirror.gd, remote_*.gd)
  audio/                 шины, ухо, природа, шаги, голоса, музыка
  ui/                    HUD, меню, окна сумки и крафта, настройки, карты, смерть, журнал фризов, стиль
shaders/                 3D-шейдеры (общий common.gdshaderinc), цветокор, карта, интерфейс
content/<мод>/           моды: mod.yaml, README, папки-бандлы с bundle.yaml, data/, sprites/, icons/, models/, textures/, sounds/; common/ общие ассеты
assets/                  шрифт, заставка, облака меню, значки интерфейса (ui/), иконки web-страницы (web/, без импорта)
tests/                   headless-тесты (run_tests + unit/, save, progress, frame, server), проверка в браузере, run_all.sh
tools/                   валидатор, скриншоты (shot + shot/), карта, бенчмарки, профиль, генераторы картинок, звуков, иконки; art/, sound/
.github/                 CI (workflows/build.yml), установка Godot (actions/godot), шаблон PR
docs/                    эта документация
```

Подробно по слоям и связям: [ARCHITECTURE.md](ARCHITECTURE.md); по системам: [SYSTEMS.md](SYSTEMS.md).

## Ключевые файлы

| Файл | Почему важен |
|---|---|
| `src/client/main.gd` | собирает сцену и все модули, ведёт кадр; модули получают Main как `game` |
| `src/shared/content/content.gd` | схемы всех видов данных, загрузка бандлов, зависимости, патчи |
| `src/shared/content/materials.gd`, `items.gd` | самые используемые реестры (41 и 32 зависимых файла) |
| `src/shared/world/world_data.gd` | мир, его ячейки и формы (37 зависимых) |
| `src/shared/world/world_gen.gd` | генератор по стадиям и заданиям |
| `src/client/world/chunk_streamer.gd` | что и когда строится в кадре: бюджеты, срез уровней |
| `src/shared/game/world_actions.gd` | всё, что руки делают с миром |
| `src/shared/game/session.gd` | сеанс мира: правила над миром, игроки, тик (то, что крутит сервер) |
| `src/shared/net/protocol.gd` | протокол: виды запросов клиента к правилам и сообщения в байты |
| `src/client/save_game.gd` | когда и что сохраняется (переводы старых сохранений — `world_store.gd`) |
| `shaders/common.gdshaderinc` | общий код шейдеров: сдвиг 3/4, свет, крыша |
| `tests/run_all.sh`, `.github/workflows/build.yml` | все проверки локально и в CI |

## Куда класть новое

| Что | Куда |
|---|---|
| Правило игры (что решает сервер) | `src/shared/game/` (данные мира — `src/shared/world/`, загрузка данных — `src/shared/content/`) |
| Новый запрос клиента к правилу | вид и аргументы в `src/shared/net/protocol.gd`, ветка в `src/server/requests.gd`, вызов `game.net.request` на клиенте ([systems/network.md](systems/network.md)) |
| Как это показать, спросить, озвучить | папка слоя в `src/client/` |
| Новая система | новый модуль-скрипт; Main создаёт его и передаёт себя как `game`; строка в [SYSTEMS.md](SYSTEMS.md) |
| Числа и записи контента | YAML мода и схема в `content.gd`, не константы кода ([DATA_MODEL.md](DATA_MODEL.md)) |
| Новое существо, растение, инструмент, биом | папка-бандл в своём моде (`content/animals/<имя>/` …), см. README мода |
| 3D-шейдер | `shaders/`, с `#include "res://shaders/common.gdshaderinc"` ([systems/rendering.md](systems/rendering.md)) |
| Тест правила | `tests/unit/<тема>_test.gd` и имя темы в `FILES` в `tests/run_tests.gd` |
| Инструмент разработки | `tools/` (рисовалки — `tools/art/`, звук — `tools/sound/`) |
| Картинка интерфейса | `assets/ui/` |
| Документ о коде | `docs/` (система — `docs/systems/`) |
| Геймдизайн, решение, задача | библиотека: `plan/design/`, журнал в `plan/README.md`, `plan/backlog.md` |
| Скриншот | библиотека: `survivium-builds/<тема>/` и строка в его README |

Новые каталоги верхнего уровня без нужды не создаются.

## Что не читать без нужды

- `.godot/`, `*.import`, `*.uid`, `build/`, `build_info.json`: кеши и сборка, не в git.
- `content/**/sounds/*.wav`, `content/**/*.png`, `assets/`: бинарные ассеты; их делают `tools/make_*`.
- `tools/art/*.gd`, `tools/make_plant_art.py`, `tools/make_creatures.py`: рисовалки ассетов, большие таблицы пикселей.
- `src/shared/world/test_ground.gd`: площадки тестового мира, нужен только для них.
- `tools/shot/places.gd`, `tools/shot/shots.gd`: места и таблица скриншотов.
- `assets/fonts/PressStart2P.ttf`, `assets/fonts/OFL.txt`: шрифт и лицензия.
- В библиотеке: `plan/history/` (история закрытых тем), `survivium-builds/` (картинки), `uploads/`.
