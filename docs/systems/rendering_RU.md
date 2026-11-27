# Картинка: проекция, камера, свет, шейдеры

Английская версия: [rendering.md](rendering.md) (она основная, эта — копия).

Статус: ACTIVE.

Эта страница — обзор; подробности разбиты по темам в `rendering/`. Прочтите обзор, затем только ту страницу,
которой касается изменение (если она длинная — сначала `grep -n '^#' docs/systems/rendering/<страница>.md`).

**Назначение.** Низкое разрешение без сглаживания (тексель = пиксель, масштаб целым числом), точная
косоугольная проекция 3/4, свет и цветокор по часам мира, огни и тени, частицы, спрайты, воксельные
модели вещей.

**Куда смотреть**

| Тема | Страница | Ключевые файлы |
|---|---|---|
| Вид, камера, авто-качество, кинескоп, небо, частицы и эффекты | [rendering/camera-effects_RU.md](rendering/camera-effects_RU.md) | `src/client/view/pixel_view.gd`, `camera_rig.gd`, `sky.gd`, `effects.gd` |
| Тени огня и солнца, атлас материалов, воксельные модели, шейдеры и глобальные параметры | [rendering/shadows-shaders_RU.md](rendering/shadows-shaders_RU.md) | `fire_shadows.gd`, `pixel_textures.gd`, `shaders/` |
| Правила, которые соблюдает изменение картинки (новые шейдеры, сдвиг, вид в пещере, срез) | [rendering/rules_RU.md](rendering/rules_RU.md) | `shaders/common.gdshaderinc`, `cave_layers.gd` |
| Подводные камни: GPU, веб, огни, атлас материалов и ловушки, перенесённые из CLAUDE.md | [rendering/pitfalls_RU.md](rendering/pitfalls_RU.md) | `world.gdshader`, `chunk_mesher.gd` |

**Тесты.** `tests/unit/view_test.gd` (`pixel_view`, `sprite_sheet`, `tracks`, `hidden`, `camera_spin`, `auto_quality`),
скриншоты `tools/shot.gd` (таблица `tools/shot/shots.gd`, места `tools/shot/places.gd`),
`tools/profile.gd` (вызовы отрисовки под xvfb), `tests/browser_smoke.mjs`.

**Подробнее.** `plan/architecture/rendering.md` (главный документ рендера), `plan/design/visual.md`,
скриншоты по темам в `survivium-builds/`.
