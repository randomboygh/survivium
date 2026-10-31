# Системы

Статус: ACTIVE. Найдите систему, откройте её контекст в `systems/`, затем только её файлы.
Все файлы с описанием: [generated/code-index.md](generated/code-index.md).

| Система | Главные файлы | Контекст | Тесты (`tests/unit/` и др.) |
|---|---|---|---|
| Моды, бандлы, данные | `src/shared/content/content.gd`, `mods.gd`, `yaml.gd`, реестры (и `starts.gd` — старт нового мира, `eras.gd` — эпохи), `content_graph.gd` (граф контента, эпохи вещей и проверки) | [systems/content.md](systems/content.md), [DATA_MODEL.md](DATA_MODEL.md) | `content_test.gd`, `graph_test.gd`, `bundle_system_test.gd`, `tools/validate.gd` |
| Генерация мира | `src/shared/world/land_layout.gd`, `world_gen.gd`, `src/shared/content/biomes.gd`, `trees.gd`, `bushes.gd`, `test_ground.gd` | [systems/world-generation.md](systems/world-generation.md) | `generation_test.gd` |
| Данные мира: ячейки, формы, трава | `src/shared/world/world_cells.gd`, `world_data.gd`, `grass.gd`, `voxel_raycast.gd` | [systems/world-data.md](systems/world-data.md) | `shapes_test.gd`, `generation_test.gd` |
| Чанки на экране | `src/client/world/chunk_streamer.gd`, `chunk_mesher.gd` (+ `mesh_faces`, `slope_mesher`, `water_mesher`, `trunk_mesher`), `foliage.gd` | [systems/chunks.md](systems/chunks.md) | `mesher_test.gd`, `frame_test.gd` |
| Картинка: камера, свет, шейдеры | `src/client/view/*`, `shaders/*` | [systems/rendering.md](systems/rendering.md) | `view_test.gd` (pixel_view, sprite_sheet, hidden, camera_spin), скриншоты `tools/shot.gd` |
| Руки и мир: копать, строить, рубить, косить, собирать | `src/shared/game/world_actions.gd`, `src/shared/content/tools.gd`, `src/client/input/controls.gd`, `cursor.gd`, `src/client/game/gathering.gd` | [systems/interaction.md](systems/interaction.md) | `actions_test.gd`, `progress_test.gd` |
| Сеанс мира и правила игры | `src/shared/game/session.gd`, `rules.gd` | [systems/session.md](systems/session.md) | `session_test.gd` |
| Протокол и сервер в игре | `src/shared/net/protocol.gd`, `src/server/requests.gd`, `player.gd`, `player_link.gd`, `src/client/net/connection.gd`, `local_host.gd`, `mirror.gd`, `remote_workshop.gd`, `remote_placed.gd`, `remote_clock.gd`, `remote_wildlife.gd` | [systems/network.md](systems/network.md) | `net_test.gd`, `content_test.gd` (layers), `save_test.gd` |
| Персонаж: сумка, силы, тело, смерть | `src/shared/game/character.gd`, `inventory.gd`, `vitals.gd`, `body.gd`, `src/client/game/character.gd`, `src/client/view/player.gd`, `figure.gd`, `hands.gd` | [systems/character.md](systems/character.md) | `character_test.gd`, `body_test.gd` |
| Крафт, станки, вещи на клетках | `src/shared/game/workshop.gd`, `craft_queue.gd`, `knowledge.gd`, `placed.gd`, `src/shared/content/crafting.gd`, `src/client/game/props.gd` | [systems/crafting.md](systems/crafting.md) | `content_test.gd` (crafting), `graph_test.gd`, `actions_test.gd` (placed, station_flags, recipe_fields), `character_test.gd` (wear), `progress_test.gd` |
| Звери | `src/shared/game/wildlife.gd`, `src/shared/content/ai_rules.gd`, `src/client/game/creatures.gd` | [systems/wildlife.md](systems/wildlife.md) | `wildlife_test.gd` |
| Время, сезоны, погода | `src/shared/game/clock.gd`, `real_weather.gd`, `storms.gd`, `src/client/view/sky.gd` | [systems/time-weather.md](systems/time-weather.md) | `clock_test.gd` |
| Сохранение | `src/shared/world/world_store.gd`, `src/client/save_game.gd` | [systems/saving.md](systems/saving.md) | `store_test.gd`, `save_test.gd` |
| Интерфейс и настройки | `src/client/ui/*`, `src/client/settings.gd`, `src/client/game/markers.gd` | [systems/ui.md](systems/ui.md) | `browser_smoke.mjs`; юнит-тестов нет |
| Звук и музыка | `src/client/audio/*`, `content/sounds/`, `content/music/` | [systems/audio.md](systems/audio.md) | `view_test.gd` (sound) |
| Тесты, инструменты, CI, версии | `tests/*`, `tools/*`, `.github/*` | [systems/testing.md](systems/testing.md) | — |

Где каждая проверка: `grep -n "func _test" tests/unit/*.gd`.

## Чего нет

| Система | Где замысел | Что в коде |
|---|---|---|
| Сервер, сеть, многопользовательская игра | `plan/architecture/server.md` (решение 153, этапы С1–С7), `networking.md`, `overview.md`, `plan/mvp.md` (этап 1) | сеанс мира с тиком (С1, [systems/session.md](systems/session.md)), протокол запросов через сервер в игре и копии персонажа и мастерской на клиенте (С2.1–С2.2а, [systems/network.md](systems/network.md)) есть; копий вещей, часов и зверей, сети и headless-сервера нет |
| Территории и PvP | `plan/design/territory-pvp.md` | нет |
| Строительство предметами (стены, двери, крыши) | `plan/design/mvp-design.md` | только ячейки: копать и ставить блоки (`world_actions.gd`) |
| Редактор контента | `plan/design/editor.md`, `plan/architecture/editor.md` | нет; схемы `content.gd` — его будущая основа |
| NPC | `plan/design/npc.md` (отложено) | нет |
| Скрипты модов | `plan/architecture/modding.md` | только данные и ассеты |
| Android-сборка | `plan/architecture/deployment.md` | нет пресета экспорта |
| Температура, жажда, навыки | `plan/design/character.md` | нет |
