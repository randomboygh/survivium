# Time, seasons, weather

Status: ACTIVE. A Russian copy: [time-weather_RU.md](time-weather_RU.md).

**Purpose.** The time of day, days and seasons, the phases of the moon, the length of the day by season;
weather by season and terrain (the strength of rain, snow, hail, wind, snow on the ground, dampness, ice); the
wind's side, leaf fall; a storm breaks twigs and knocks off berries; by the setting «as in life» — the
device's time, the season by the calendar and real weather.

**Files**
- `src/shared/game/clock.gd` — the world's clock: `step(delta, at)`, `daylight()`, `day_share()`,
  `sun_time()`, `sunrise()` / `sunset()`, `moon_phase_light`, `wind_dir()`, `set_weather`, `settle_weather`,
  `set_real_weather`, `ground_fog`, `ice`; the table `WEATHERS` (13 kinds, new ones at the end: the index is
  stored by saves and the server; what each brings and how often by season); the signal `season_changed` (the
  session connects the spring reset `WorldActions.on_season` to it: shrubs, twigs, mown grass — only on the
  world's clock, not on a copy); `warm_days` — how many days of non-winter have begun (nature grows by them,
  `WorldActions.step_nature`); `to_dict` / `from_dict` (saving), `snapshot` / `from_snapshot` (everything the
  clock shows, the fields `SNAPSHOT`, for the client's copy).
- `src/client/net/remote_clock.gd` — the clock's copy on the client (`game.clock`): the server's snapshots
  every 0.25 s (the event `clock`, [network.md](network.md)), between them it leads only the time of day
  (`advance`); the season of the first snapshot is taken silently (no toast at loading), the following
  changes of season are shown by `Sky.on_season`. The world's clock is `game.session.clock`: saving, real
  weather (the server) and the «Testing» page write into it.
- `src/server/real_weather.gd` — a server service (decisions 153, 168): a node with `HTTPRequest`, the
  server's place by IP (ipapi.co, ipwho.is), Open-Meteo weather every 30 min (`REFRESH`, after a failure in 2
  min), `apply(data)` → `clock.set_real_weather` on the world's clock; the players get it with the clock's
  snapshots. The lines «real weather: …» go to the server's log (`report`). Who starts it: a server from a
  terminal or from the menu with `Config.real_weather` (`--real-weather`, `[server] real_weather`, the
  checkbox «Real weather outside» in «Create a server»; `server_main.gd`); the server inside the game
  (`LocalHost.real_weather`, a node under `ServerRunner`) — by the game's setting «Weather: as in life»
  (`Settings.apply`), that is the weather where the device is. For a player on another's server this setting
  is dimmed: the host decides the weather.
- `src/shared/game/storms.gd` — what a strong wind does: by a chunk around a place per tick (`TICK` 0.25 s;
  `step_around(delta, places)` — the players in turn, `last_at`; called by the world session), the rules —
  `WorldActions.blow_branch` / `blow_berries`.
- `src/client/view/sky.gd` — how it looks: light, colour correction, clouds, shader tints (see
  [rendering.md](rendering.md)); `src/client/audio/nature.gd` — how it sounds. Cloud shadows
  (`cloud_light` in `shaders/common.gdshaderinc`) fall along the light: `cloud_slant`, set by `_aim_sun`, moves the
  point looked up by its height (at most `CLOUD_SLANT`), so a shadow's edge goes down a wall at a slant.

**Data.** Weather and the calendar are constants of `clock.gd` (not yet moved into the mods' data, it is in the
MVP plans); sand storms — the biome's flag `sandstorms`.

**Limits.** The length of the day by season: sunrise and sunset 4–20 in summer, 8–16 in winter, 6–18 in the
middle of spring and autumn. The scene's time in screenshots is sunny (`tools/shot.gd`).

**Tests.** `tests/unit/clock_test.gd` (`clock`, `weather`).

**In more detail.** `plan/design/time-seasons.md`.
