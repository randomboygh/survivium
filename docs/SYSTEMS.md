# Системы

Статус: ACTIVE. Найдите систему, откройте её контекст в `systems/`, затем только её файлы.
Все файлы с описанием: [generated/code-index.md](generated/code-index.md).

| Система | Главные файлы | Контекст | Тесты (`tests/unit/` и др.) |
|---|---|---|---|
| Моды, бандлы, данные | `src/shared/content/content.gd`, `mods.gd`, `yaml.gd`, реестры (и `starts.gd` — старт нового мира, `eras.gd` — эпохи), `content_graph.gd` (граф контента, эпохи вещей и проверки) | [systems/content.md](systems/content.md), [DATA_MODEL.md](DATA_MODEL.md) | `content_test.gd`, `graph_test.gd`, `bundle_system_test.gd`, `properties_test.gd` (граф), `tools/validate.gd` |
| Генерация мира | `src/shared/world/land_layout.gd`, `world_gen.gd`, `src/shared/content/biomes.gd`, `trees.gd`, `bushes.gd`, `src/shared/world/growth.gd`, `test_ground.gd` | [systems/world-generation.md](systems/world-generation.md) | `generation_test.gd` |
| Данные мира: ячейки, формы, трава | `src/shared/world/world_cells.gd`, `world_data.gd`, `grass.gd`, `voxel_raycast.gd` | [systems/world-data.md](systems/world-data.md) | `shapes_test.gd`, `generation_test.gd` |
| Чанки на экране | `src/client/world/chunk_streamer.gd`, `chunk_mesher.gd` (+ `mesh_faces`, `slope_mesher`, `water_mesher`, `trunk_mesher`), `foliage.gd` | [systems/chunks.md](systems/chunks.md) | `mesher_test.gd`, `frame_test.gd` |
| Картинка: камера, свет, шейдеры, вид в пещере | `src/client/view/*` (`cave_layers.gd` — вид в пещере), `src/client/world/solid_map.gd`, `shaders/*` | [systems/rendering.md](systems/rendering.md) | `view_test.gd` (pixel_view, sprite_sheet, hidden, camera_spin), скриншоты `tools/shot.gd` |
| Руки и мир: копать, строить (и по чертежу), рубить, косить, собирать | `src/shared/game/world_actions.gd`, `felling.gd`, `plans.gd`, `src/shared/content/tools.gd`, `src/client/input/controls.gd`, `cursor.gd`, `src/client/view/plan_view.gd`, `src/client/game/gathering.gd` | [systems/interaction.md](systems/interaction.md) | `actions_test.gd` (и `stairs_placed`, `openings`), `plans_test.gd`, `progress_test.gd` |
| Сеанс мира и правила игры | `src/shared/game/session.gd`, `rules.gd`, `src/server/runner.gd` | [systems/session.md](systems/session.md) | `session_test.gd`, `save_test.gd` |
| Протокол и сервер | `src/shared/net/protocol.gd`, `src/server/requests.gd`, `player.gd`, `player_link.gd`, `server.gd`, `server_main.gd`, `server_store.gd`, `config.gd`, `console.gd`, `tunnel.gd`, `scenes/server.tscn`, `src/client/net/connection.gd`, `socket.gd`, `local_host.gd`, `server_list.gd`, `mirror.gd`, `remote_gen.gd`, `remote_workshop.gd`, `remote_placed.gd`, `remote_clock.gd`, `remote_wildlife.gd` | [systems/network.md](systems/network.md) | `net_test.gd`, `content_test.gd` (layers), `save_test.gd`, `server_test.gd` |
| Персонаж: сумка, силы, навыки, тело, смерть | `src/shared/game/character.gd`, `inventory.gd`, `vitals.gd`, `warmth.gd`, `skill_set.gd`, `src/shared/content/skills.gd`, `body.gd`, `src/client/game/character.gd`, `src/client/view/player.gd`, `figure.gd`, `hands.gd`, `others.gd` | [systems/character.md](systems/character.md) | `character_test.gd`, `body_test.gd`, `skills_test.gd`, `properties_test.gd` (сумка) |
| Крафт, станки, вещи на клетках (двери, окна, лестницы, мебель, камин) | `src/shared/game/workshop.gd`, `craft_queue.gd`, `knowledge.gd`, `placed.gd`, `src/shared/content/crafting.gd`, `src/client/game/props.gd` | [systems/crafting.md](systems/crafting.md) | `content_test.gd` (crafting), `graph_test.gd`, `actions_test.gd` (placed, station_flags, recipe_fields, furniture, openings), `character_test.gd` (wear), `progress_test.gd` |
| Команды, территория и PvP | `src/shared/game/teams.gd`, `territory.gd`, `fights.gd`, `src/client/game/team.gd`, `land.gd`, `src/client/view/land_view.gd`, `src/client/ui/land_page.gd`, `src/client/ui/person_card.gd`, `team_page.gd` | [systems/territory.md](systems/territory.md) | `territory_test.gd`, `server_test.gd` |
| Звери и рыбалка | `src/shared/game/wildlife.gd`, `fishing.gd`, `src/shared/content/ai_rules.gd`, `src/client/game/creatures.gd`, `src/client/view/fishing_line.gd` | [systems/wildlife.md](systems/wildlife.md) | `wildlife_test.gd` |
| Время, сезоны, погода | `src/shared/game/clock.gd`, `real_weather.gd`, `storms.gd`, `src/client/view/sky.gd` | [systems/time-weather.md](systems/time-weather.md) | `clock_test.gd` |
| Сохранение | `src/shared/world/world_store.gd`, `src/client/save_game.gd` | [systems/saving.md](systems/saving.md) | `store_test.gd`, `save_test.gd` |
| Интерфейс и настройки | `src/client/ui/*`, `src/client/settings.gd`, `src/client/game/markers.gd` | [systems/ui.md](systems/ui.md) | `browser_smoke.mjs`; юнит-тестов нет |
| Звук и музыка | `src/client/audio/*`, `content/sounds/`, `content/music/` | [systems/audio.md](systems/audio.md) | `view_test.gd` (sound) |
| Тесты, инструменты, CI, версии | `tests/*`, `tools/*`, `.github/*` | [systems/testing.md](systems/testing.md), [testing/](testing/TESTING_GUIDE.md) | `tools/lint.py`, `tools/parse_check.gd` |

Где каждая проверка: `grep -n "func _test" tests/unit/*.gd`.

## Чего нет

| Система | Где замысел | Что в коде |
|---|---|---|
| Сервер, сеть, многопользовательская игра | `plan/architecture/server.md` (решение 153, этапы С1–С7), `plan/mvp.md` (этап 1) | этапы С1–С7 сделаны ([systems/session.md](systems/session.md), [systems/network.md](systems/network.md)); нет докачки модов с сервера (после MVP, решение 153) и сервера в браузере для других игроков |
| Территории и PvP | `plan/design/territory-pvp.md` | команды, участки земли, права и защита, возрождение у костров команды, PvP, упадок заброшенной земли есть (Т1–Т6, [systems/territory.md](systems/territory.md)); ветшания построек вне территории и союзов нет |
| Строительство: крыши, ворота, люк | `plan/design/mvp-design.md`, решение 163 | есть материалы стен, лестница, двери 1×2, 2×2, 2×3, окна 1×1…3×2, чертёж (стена, пол, комната) со стройкой по клеткам, мебель и камин ([systems/interaction.md](systems/interaction.md), [systems/crafting.md](systems/crafting.md)); нет скатных крыш, ворот, люка, приставной лестницы, ветшания построек |
| Редактор контента | `plan/design/editor.md`, `plan/architecture/editor.md` | нет; схемы `content.gd` — его будущая основа |
| NPC | `plan/design/npc.md` (отложено) | нет |
| Скрипты модов | `plan/architecture/modding.md` | только данные и ассеты |
| Android-сборка | `plan/architecture/deployment.md` | нет пресета экспорта |
