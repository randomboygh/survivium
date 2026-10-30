# Звери

Статус: ACTIVE.

**Назначение.** Животные мира. Вид задаёт только свойства; кто кому еда и угроза, выводят общие правила.
Звери появляются вокруг людей, бродят, пасутся, отдыхают вне своих часов, убегают от угроз, охотятся
голодными; стаи идут за вожаком, летуны ночуют в кронах, лазающие ходоки забираются на деревья, пловцы
держатся открытой воды, вид с `biomes` появляется только на своей земле.

**Файлы**
- `src/shared/game/wildlife.gd` — правила: `start(seed)`, `update(delta)`, `count(kind)`, `wanted(kind)`;
  зверь без зрителя (`near` выключен) ходит шагами раз в 0,1 с; толчки тел по массе (`_jostle`,
  `pushes` для игрока). Сигналы `born`, `gone`, `stepped`.
- `src/shared/content/ai_rules.gd` — общие правила по свойствам: `reaches`, `is_food`, `is_threat`,
  `is_active`; `AiRules.SPECIES`.
- `src/client/game/creatures.gd` — рисует зверей: кадр 0 в покое, кадры шага по шагам, кадры крыльев в
  воздухе; ставит `near` по экрану.
- `src/client/audio/voices.gd` — голоса (`calls`) и крик испуга (`alarm`); `src/client/world/tracks.gd` —
  следы.

**Кто использует.** Main (`wildlife.start` после готовности мира), `creatures.gd`, `voices.gd`, следы,
`fire_shadows.gd` (тени зверей у огня), тесты.

**Данные.** Вид `creatures` (`mass`, `diet`, `speed`, `sight`, `human_wariness`, `active`, `count`,
`sprite`, `frames`, `flies`, `swims`, `ashore`, `hops`, `after_rain`, `flight`, `tints`, `flock`, `roost`,
`likes`, `biomes`, `calls`, `alarm`) в бандлах `content/animals/<зверь>/`; картинка —
`sprites/creatures/<sprite>.png` бандла, ряд из `frames` кадров (новые рисует `tools/make_creatures.py`).
Пример зверя одними данными и картинкой: `content/animals/sparrow/README.md`.

**Ограничения.** Ходок не достаёт пловца и наоборот, летун достаёт обоих. Биом столбца берётся из
`gen.lay_out`. У ходоков один кадр стояния; ныряния нет. Голоса бандл приносит готовыми `.wav`
(синтез — таблица в `tools/make_sounds.gd`).

**Тесты.** `tests/unit/wildlife_test.gd` (`ai_relations`, `wildlife`, `climbers`, `biomes`, `swimmers`,
`birds`, `shore`, `jostle`; стая ждёт тактов мышления, а не порядка случайных чисел).

**Подробнее.** `plan/design/creatures-ai.md`; `plan/architecture/ai.md` — замысел движка поведения
(формулы помечены как черновик, в коде проще).
