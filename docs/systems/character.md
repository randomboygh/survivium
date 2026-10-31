# Персонаж: сумка, силы, тело, смерть, спрайт

Статус: ACTIVE.

**Назначение.** Тот, кто играет: сумка и вес, здоровье, сытость, выносливость, цена действий, еда,
статистика жизни, смерть с мешком и возрождение; тело на клетках (ходьба по склонам, прыжки, вода, лёд,
снег, ветер); спрайт игрока из слоёв PNG.

**Файлы**
- `src/shared/game/character.gd` — правила персонажа (`in_hands`, `act`, `give`, `eat`, `throw_away`,
  `die`, `revive`, `respawn_points`, `to_dict` / `from_dict`); сигнал `state_changed`.
- `src/shared/game/inventory.gd` — сумка: `SLOTS` 16, первые `HOTBAR` 8 — панель внизу; стопки, вес
  (40 кг без замедления), сортировка, перенос в сундук, износ (`wear_tool`, `mend`); сигнал `changed`.
- `src/shared/game/vitals.gd` — здоровье, сытость, выносливость (0..`MAX`), цена действий (`spend`, `can`).
- `src/shared/game/body.gd` — тело на сетке: `step(at, delta, jump)`, склоны и ступени, вода и плавание,
  лёд, глубокий снег и ветер (`weather_pace`, `air_drift`), толчки (`knock`), тропы. Где стоит тело,
  держит владелец: на клиенте узел игрока передаёт своё место в `body.step` каждый кадр.
- `src/server/player.gd` (наследует общий) — персонаж игрока на сервере, тот, над кем идут правила:
  тело и руки такие, какими клиент прислал их событием `input` ([network.md](network.md)).
- `src/client/game/character.gd` (наследует общий) — копия персонажа на клиенте: сумка, силы, смерть
  из событий сервера (`take`, `take_vitals`), место игрока, руки (из `controls`), строки под часами,
  экран смерти, `go_to_column` («Тестирование»); правил не крутит.
- `src/client/view/player.gd` — игрок на экране: двигает тело, рисует спрайт по состоянию тела;
  `player.work` начинает замах.
- `src/client/view/figure.gd` — лист кадров игрока из `content/core/sprites/` по `player.yaml` (слои,
  метки кистей `hands.png`, лист на каждый инструмент в руке или иконка предмета), строится по части ряда
  за кадр; `hands.gd` — что в руках видно на спрайте; `sprite_sheet.gd` — лист кадров по данным.
- `src/client/ui/death_screen.gd`, `vitals_panel.gd`, `body_feedback.gd`, `vibration.gd` — экран смерти,
  полоски сил, отклик экрана на урон, вибрация телефона.

**Данные.** Предметы (`food`, `heal`, `weight`, `stack`, `light`, `sprite`, `anim`, `hands`); существо
`core:human`; слои и работы фигуры — `content/core/sprites/player.yaml`, листы инструментов в руке —
`sprites/held/` бандла инструмента. Сохраняются части `inventory`, `vitals`, `character` (с серверного
персонажа, `game.host.player`), `hands` (с клиента).

**Подводные камни.** Сигналы сумки и очереди подключайте методом, не лямбдой с `self` (цикл ссылок,
RefCounted не освободится — см. комментарий в `src/shared/game/character.gd`). `var i := expr`, где
`expr` — Variant (поле нетипизированного объекта), — ошибка разбора: тип указывается явно;
`typed_array = expr if c else []` — ошибка времени выполнения, которая молча обрывает функцию.

**Тесты.** `tests/unit/character_test.gd` (`inventory`, `wear`, `torch`, `vitals`, `changes`, `death`),
`tests/unit/body_test.gd` (`walking_rules`, `water`, `bog`, `slopes`, `steps`, `ground`),
`tests/save_test.gd`, `tools/sheet.gd` (лист кадров в PNG).

**Подробнее.** `plan/design/character.md`, `plan/design/ui.md` (сумка, смерть).
