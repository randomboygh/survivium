# Звери

Статус: ACTIVE.

**Назначение.** Животные мира. Вид задаёт только свойства; кто кому еда и угроза, выводят общие правила.
Звери появляются вокруг людей, бродят, пасутся, отдыхают вне своих часов, убегают от угроз, охотятся
голодными; стаи идут за вожаком, летуны ночуют в кронах, лазающие ходоки забираются на деревья, пловцы
держатся открытой воды, вид с `biomes` появляется только на своей земле.

**Файлы**
- `src/shared/game/wildlife.gd` — правила: `start(seed)`, `update(delta)`, `count(kind)`, `wanted(kind)`;
  `people` — все игроки, новый зверь появляется у случайного из них (`_someone`, при одном без броска);
  зверь без зрителя (`near` выключен: дальше круга `NEAR` 28 единиц от всех игроков — столько показывает
  любой экран, `look_from` зовёт сеанс перед шагом) ходит шагами раз в 0,1 с; толчки тел по массе
  (`_jostle`: зверей рядом на земле сортирует с запада на восток и сверяет каждого только с теми, кто в
  досягаемости восточнее; радиус тела хранится в `Animal.radius`; `_shove` берёт пол из последнего
  взгляда зверя, как `_move`; `pushes` для игрока). У зверя номер `id` (по нему его знает копия
  клиента). Сигналы `born`, `gone`, `stepped`.
- `src/shared/content/ai_rules.gd` — общие правила по свойствам: `reaches`, `is_food`, `is_threat`,
  `is_active`; `AiRules.SPECIES`.
- `src/client/net/remote_wildlife.gd` — копия зверей на клиенте из событий сервера `animal`, `snap`,
  `animal_gone`, `step` ([network.md](network.md)): свой `Animal` с полями, что читают виды, те же
  сигналы.
- `src/client/game/creatures.gd` — рисует зверей копии: кадр 0 в покое, кадры шага по шагам, кадры
  крыльев в воздухе; картинку ставит заново, когда сервер сдвинул зверя (`Animal.fresh`).
- `src/client/audio/voices.gd` — голоса (`calls`) и крик испуга (`alarm`); `src/client/world/tracks.gd` —
  следы.

**Кто использует.** Сеанс мира (`session.gd`: создаёт, `start_wildlife` после готовности мира, шаг
`step_wildlife` каждый кадр из Main), `player_link.gd` (события для клиента); копию —
`creatures.gd`, `voices.gd`, следы, `fire_shadows.gd` (тени зверей у огня); тесты и `tools/shot.gd`
пишут в `main.session.wildlife`.

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
