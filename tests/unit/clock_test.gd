extends "res://tests/unit/test_case.gd"
## Time of day, seasons, the moon and the weather.


func run() -> void:
	_test_clock()
	_test_weather()


## The world's clock runs without the client: days and seasons pass, and the snow of
## a winter freezes the water and melts in summer.
func _test_clock() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	var clock := Clock.new()
	clock.world = w
	var seasons: Array[int] = []
	clock.season_changed.connect(func(s: int) -> void: seasons.append(s))
	clock.time_of_day = 0.9
	for i in 60:
		clock.step(1.0)
	_check(clock.day == 2 and is_equal_approx(clock.time_of_day, 0.9 + 60.0 / Clock.DAY_LENGTH - 1.0),
		"a day is DAY_LENGTH seconds long")
	clock.season_clock = Clock.DAYS_PER_SEASON - 0.001
	clock.step(1.0)
	_check(seasons == [2] and clock.season == 2 and clock.season_clock < 0.01, "the season changes after its days")
	clock.season = Clock.WINTER
	clock.set_weather(Clock.WEATHERS.map(func(d: Dictionary) -> String: return d.id).find("snow"))
	for i in 60:
		clock.step(1.0)
	_check(clock.snow > 0.9 and w.water_frozen and clock.weather_icon() == "snow", "snow in winter lies and freezes the water")
	clock.season = 1
	clock.set_weather(Clock.CLEAR)
	for i in 60:
		clock.step(1.0)
	_check(clock.snow == 0.0 and not w.water_frozen, "and melts in summer")
	clock.real_time = true
	clock.time_of_day = fposmod(Clock.local_time_of_day() + 0.5, 1.0)
	var day_was := clock.day
	clock.step(1.0)
	var off := absf(clock.time_of_day - Clock.local_time_of_day())
	_check(minf(off, 1.0 - off) < 0.001 and clock.day - day_was <= 1, "the real-time clock catches up with the device's time")
	day_was = clock.day
	var t0 := clock.time_of_day
	clock.time_of_day = fposmod(t0 + 0.001, 1.0)
	clock.step(1.0)
	_check(clock.day == day_was and is_equal_approx(clock.time_of_day, fposmod(t0 + 0.001, 1.0)),
		"and waits when it is a little ahead, without skipping a day")
	_check(is_equal_approx(clock.days(Clock.REAL_DAY), 1.0), "a real-time day is a real day long")
	clock.real_time = false
	seasons.clear()
	clock.real_season = true
	clock.season = (Clock.calendar_season() + 1) % 4
	clock.step(1.0)
	clock.step(1.0)
	_check(clock.season == Clock.calendar_season() and seasons == [clock.season],
		"the calendar season comes once and stays")
	clock.real_season = false
	var ids := Clock.WEATHERS.map(func(d: Dictionary) -> String: return d.id)
	_check([0, 3, 45, 61, 65, 75, 95, 99].map(func(c: int) -> String: return ids[Clock.weather_of_code(c, 2.0)])
			== ["clear", "cloudy", "fog", "rain", "downpour", "snow", "storm", "hail"]
		and ids[Clock.weather_of_code(73, 15.0)] == "blizzard", "real weather codes become the game's weathers")
	var real := RealWeather.new()
	real.clock = clock
	_check(real.apply({"current": {"weather_code": 63, "wind_speed_10m": 8.0, "wind_direction_10m": 0.0}})
			and ids[clock.weather] == "rain" and not clock.weather_auto
			and is_equal_approx(clock.real_wind, 1.0) and is_equal_approx(clock.wind_to, PI / 2.0)
			and not real.apply({"error": true}),
		"the real weather pins the clock's, a wind from the north blows south")
	real.free()
	clock.clear_real_weather()


## The weather works on the world without the client: deep snow, a head wind and a
## blizzard slow walking in the open but not under a roof, a trail in the snow is
## easier, the autumn wind strips the leaves, and a storm breaks branches off the
## trees and knocks the berries off the bushes.
func _test_weather() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.GRASS)
	var clock := Clock.new()
	clock.world = w
	var body := Body.new()
	body.world = w
	body.clock = clock
	body.on_ground = true
	var p := Vector3(10.5, 2.0, 10.5)
	_check(is_equal_approx(body.weather_pace(p, Vector2(-1.0, 0.0)), 1.0), "clear weather does not slow walking")
	clock.season = Clock.WINTER
	clock.set_weather(Clock.WEATHERS.map(func(d: Dictionary) -> String: return d.id).find("blizzard"))
	clock.settle_weather()
	clock.wind_angle = 0.0
	clock.snow = 1.0
	var head := body.weather_pace(p, Vector2(-1.0, 0.0))
	var tail := body.weather_pace(p, Vector2(1.0, 0.0))
	_check(head < tail and tail < 1.0 and head >= Body.WEATHER_FLOOR, "a blizzard slows walking, against the wind most (%.2f, %.2f)" % [head, tail])
	var across := body.weather_pace(p, Vector2(0.0, 1.0))
	w.tread(10, 10, clock.now())
	_check(body.weather_pace(p, Vector2(0.0, 1.0)) > across, "a fresh trail in the snow is easier to walk")
	_check(body.air_drift(p) == Vector2.ZERO, "the wind does not carry a body on the ground")
	body.on_ground = false
	_check(body.air_drift(p).x > 1.0, "a blizzard carries a body in the air downwind")
	var jumper := Body.new()
	jumper.world = w
	jumper.clock = clock
	var at := Vector3(20.5, 2.0, 30.5) * WorldData.CELL
	jumper.step(at, 0.02, false)
	at = jumper.step(at, 0.02, true)
	while true:
		at = jumper.step(at, 0.02, false)
		if jumper.on_ground:
			break
	_check(at.x / WorldData.CELL > 20.5 + 0.5, "a jump in a blizzard lands downwind (%.2f cells)" % (at.x / WorldData.CELL - 20.5))
	body.on_ground = true
	w.set_cell(10, 6, 10, Mat.STONE)
	_check(is_equal_approx(body.weather_pace(p, Vector2(-1.0, 0.0)), 1.0), "under a roof the weather does not slow walking")
	clock.season = Clock.AUTUMN
	clock.set_weather(Clock.WEATHERS.map(func(d: Dictionary) -> String: return d.id).find("storm"))
	clock.settle_weather()
	for i in 30:
		clock.step(1.0)
	_check(clock.leaf_fall > 0.05, "an autumn storm strips the leaves (%.2f)" % clock.leaf_fall)
	clock.next_season()
	clock.next_season()
	_check(clock.season == Clock.SPRING and clock.leaf_fall == 0.0, "and spring grows them back")
	clock.season = Clock.AUTUMN
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Trees.place(w, 24, 2, 24, Trees.sample(Trees.LOWLAND), rng)
	for key: Vector2i in w.chunks:
		w.chunks[key].final = true
	var actions := WorldActions.new(w, clock, {"free_build": false})
	var storms := Storms.new(w, clock, actions)
	clock.time_speed = 20.0
	for i in 2000:
		storms.step(Storms.TICK, Vector3(24.5, 2.0, 24.5) * WorldData.CELL)
	var branches := 0
	var s: Dictionary = Trees.SPECIES[Trees.sample(Trees.LOWLAND)]
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			if d[0] == s.twig:
				branches += WorldActions.count(d)
	_check(branches > 0 and branches == w.tree_twigs.get(Vector2i(24, 24), 0) and branches <= s.twigs,
		"a storm breaks branches off a tree, no more than it has (%d of %d)" % [branches, s.twigs])
	w.tree_twigs[Vector2i(24, 24)] = s.twigs
	_check(not actions.blow_branch(Vector2i(24, 24), Vector3(24.5, 2.0, 26.5) * WorldData.CELL, 0.0), "and none once they are gone")
