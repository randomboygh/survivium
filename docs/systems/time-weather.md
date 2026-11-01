# Время, сезоны, погода

Статус: ACTIVE.

**Назначение.** Время суток, дни и сезоны, фазы луны, длина дня по сезону; погода по сезону и местности
(сила дождя, снега, града, ветра, снег на земле, сырость, лёд); сторона ветра, листопад; буря ломает ветки
и сбивает ягоды; по настройке «как в жизни» — время устройства, сезон по календарю и настоящая погода.

**Файлы**
- `src/shared/game/clock.gd` — часы мира: `step(delta, at)`, `daylight()`, `day_share()`, `sun_time()`,
  `sunrise()` / `sunset()`, `moon_phase_light`, `wind_dir()`, `set_weather`, `settle_weather`,
  `set_real_weather`, `ground_fog`, `ice`; таблица `WEATHERS` (11 видов: что приносит и как часто по
  сезонам); сигнал `season_changed` (сеанс подключает к нему весенний сброс `WorldActions.on_season`:
  кусты, ветки, скошенная трава — только на часах мира, не на копии); `to_dict` / `from_dict` (сохранение), `snapshot` / `from_snapshot`
  (всё, что часы показывают, поля `SNAPSHOT`, для копии клиента).
- `src/client/net/remote_clock.gd` — копия часов на клиенте (`game.clock`): снимки сервера раз в 0,25 с
  (событие `clock`, [network.md](network.md)), между ними ведёт только время суток (`advance`); сезон первого снимка берёт молча (без тоста
  при загрузке), следующие смены сезона показывает `Sky.on_season`. Часы
  мира — `game.session.clock`: в них пишут сохранение, настоящая погода и страница «Тестирование».
- `src/shared/game/real_weather.gd` — узел с `HTTPRequest`: место по IP (ipapi.co, ipwho.is), погода
  Open-Meteo, `apply(data)` → `clock.set_real_weather`. Сетевой сервис устройства в общей папке — место
  спорное (см. аудит).
- `src/shared/game/storms.gd` — что делает сильный ветер: по чанку вокруг места за такт (`TICK` 0,25 с;
  `step_around(delta, места)` — игроки по очереди, `last_at`; зовёт сеанс мира),
  правила — `WorldActions.blow_branch` / `blow_berries`.
- `src/client/view/sky.gd` — как это выглядит: свет, цветокор, облака, оттенки шейдеров
  (см. [rendering.md](rendering.md)); `src/client/audio/nature.gd` — как звучит.

**Данные.** Погода и календарь — константы `clock.gd` (в данные модов пока не вынесены, это в планах
MVP); песчаные бури — флаг биома `sandstorms`.

**Ограничения.** Длина дня по сезону: рассвет и закат 4–20 летом, 8–16 зимой, 6–18 в середине весны и
осени. Время сцены в скриншотах — солнечное (`tools/shot.gd`).

**Тесты.** `tests/unit/clock_test.gd` (`clock`, `weather`).

**Подробнее.** `plan/design/time-seasons.md`.
