extends "res://tests/unit/test_case.gd"
## Time of day, seasons, the moon and the weather.


func run() -> void:
	_test_clock()
	_test_freezing()
	_test_weather()
	_test_shrooms()


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
	for i in 30:
		clock.step(1.0)
	var early := clock.snow
	_check(early > 0.05 and early < 0.6, "falling snow covers the ground bit by bit: " + str(early))
	for i in 90:
		clock.step(1.0)
	_check(clock.snow > 0.9 and w.water_frozen and clock.weather_icon() == "snow", "snow in winter lies and freezes the water")
	clock.set_weather(Clock.CLEAR)
	clock.snowing = 0.0
	clock.snow = 0.4
	for i in 60:
		clock.step(1.0)
	_check(is_equal_approx(clock.snow, 0.4), "in winter snow lies only while it falls and stays between snowfalls")
	clock.season = 1
	clock.set_weather(Clock.CLEAR)
	for i in 60:
		clock.step(1.0)
	_check(clock.snow == 0.0 and not w.water_frozen, "and melts in summer")
	clock.season = 1
	clock.season_clock = Clock.DAYS_PER_SEASON * 0.5
	var summer := [clock.sunrise(), clock.sunset()]
	clock.time_of_day = 0.71
	var summer_evening := clock.daylight()
	clock.season = Clock.WINTER
	var winter := [clock.sunrise(), clock.sunset()]
	var winter_evening := clock.daylight()
	_check(is_equal_approx(summer[0], 4.0) and is_equal_approx(summer[1], 20.0)
			and is_equal_approx(winter[0], 8.0) and is_equal_approx(winter[1], 16.0)
			and summer_evening > 0.99 and winter_evening < 0.05, "summer days are long, winter days short")
	clock.season = 0
	clock.season_clock = Clock.DAYS_PER_SEASON * 0.5
	_check(is_equal_approx(clock.sunrise(), 6.0) and is_equal_approx(clock.sunset(), 18.0), "and half a day at mid-spring")
	clock.season = Clock.WINTER
	clock.season_clock = Clock.DAYS_PER_SEASON - 0.0001
	var late_winter := clock.day_share()
	clock.season = 0
	clock.season_clock = 0.0
	var round_trip := true
	for t in [0.0, 0.1, 0.3, 0.5, 0.6, 0.8, 0.95]:
		clock.time_of_day = t
		round_trip = round_trip and absf(clock.time_at_sun(clock.sun_time()) - t) < 0.0001
	_check(absf(late_winter - clock.day_share()) < 0.001 and round_trip,
		"the day grows without a jump into spring, and time_at_sun undoes sun_time")
	clock.season = 1
	clock.time_of_day = 0.9
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
	_check([0, 1, 2, 3, 45, 53, 61, 65, 75, 95, 99].map(func(c: int) -> String: return ids[Clock.weather_of_code(c, 2.0)])
			== ["clear", "clear", "partly_cloudy", "cloudy", "fog", "drizzle", "rain", "downpour", "snow", "storm", "hail"]
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

## While the water freezes the ice creeps from the shallows towards the deep, column by
## column (WorldCells.ice_margin), and what is ice holds a walker before all of it is.
func _test_freezing() -> void:
	var w := WorldData.new(16, Vector2i(32, 16))
	# A shore deepening to the east: column x has water x / 3 + 1 cells deep, 8 at most.
	for z in 16:
		for x in 32:
			var depth := mini(x / 3 + 1, 8)
			for y in 10:
				w.set_cell(x, y, z, Mat.STONE if y < 10 - depth else Mat.WATER)
	var frozen := func() -> int:
		var n := 0
		for x in 32:
			if w.frozen_at(x, 8):
				n += 1
		return n
	_check(not w.frozen_at(0, 8), "no ice before the freezing")
	w.ice_spread = 0.2
	_check(w.frozen_at(0, 8) and not w.frozen_at(31, 8) and not w.water_frozen,
		"the shallows freeze first, not the deep")
	var some: int = frozen.call()
	w.ice_spread = 0.6
	var more: int = frozen.call()
	_check(more > some and more < 32, "the ice spreads towards the deep: " + str(some) + " -> " + str(more))
	w.ice_spread = 0.99
	_check(frozen.call() >= 30, "and has nearly all of it just before the water is all ice")
	_check(w.surface_y(0, 8) == 10 and w.blocks_body(0, 9, 8), "frozen shallows are walked on")
	w.ice_spread = 0.2
	_check(w.surface_y(31, 8) == -1, "the open deep is swum in")
	# Values of the 32-bit unsigned hash worked out by hand (uint maths as in water.gdshader).
	_check(is_equal_approx(WorldData.ice_hash(3, -7), 64.0 / 1023.0) and is_equal_approx(WorldData.ice_hash(-1, 0), 533.0 / 1023.0),
		"the ice's noise hashes the lattice in 32-bit unsigned maths, as the shader does")

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
	Growth.place(w, 24, 2, 24, Trees.first(Trees.BROAD))
	for key: Vector2i in w.chunks:
		w.chunks[key].final = true
	var actions := WorldActions.new(w, clock, Rules.new())
	var storms := Storms.new(w, clock, actions)
	clock.time_speed = 20.0
	for i in 2000:
		storms.step(Storms.TICK, Vector3(24.5, 2.0, 24.5) * WorldData.CELL)
	var branches := 0
	var s: Dictionary = Trees.SPECIES[Trees.first(Trees.BROAD)]
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			if d[0] == s.twig:
				branches += WorldActions.count(d)
	_check(branches > 0 and branches == w.tree_twigs.get(Vector2i(24, 24), 0) and branches <= s.twigs,
		"a storm breaks branches off a tree, no more than it has (%d of %d)" % [branches, s.twigs])
	w.tree_twigs[Vector2i(24, 24)] = s.twigs
	_check(not actions.blow_branch(Vector2i(24, 24), Vector3(24.5, 2.0, 26.5) * WorldData.CELL, 0.0), "and none once they are gone")


## Mushrooms that come up after rain (Clock.shrooms) do not grow while it rains, grow on
## the soaked ground once it stops, and wither when it has dried; none in winter.
func _test_shrooms() -> void:
	var w := WorldData.new(40, Vector2i(16, 16))
	var clock := Clock.new()
	clock.world = w
	clock.weather_auto = false
	clock.season = 1
	_check(clock.shrooms == 0.0, "no mushrooms before any rain")
	clock.weather = Clock.RAIN
	clock.rain = 0.5
	clock._grow_shrooms(0.1, false)
	_check(clock.soak > 0.0 and clock.shrooms == 0.0, "rain soaks the ground, nothing grows while it falls")
	clock.weather = Clock.CLEAR
	clock.rain = 0.0
	clock._grow_shrooms(Clock.SHROOM_GROW, false)
	_check(clock.shrooms == 1.0, "after the rain they come up in half a day")
	clock._grow_shrooms(Clock.SOAK_DAYS + Clock.SHROOM_FADE, false)
	_check(clock.shrooms == 0.0 and clock.soak == 0.0, "the ground dries and they wither")
	clock.shrooms = 1.0
	clock._grow_shrooms(Clock.SHROOM_FADE, true)
	_check(clock.shrooms == 0.0, "the frost takes them")
	var saved := Clock.new()
	clock.shrooms = 0.6
	clock.soak = 1.0
	saved.from_dict(clock.to_dict())
	_check(is_equal_approx(saved.shrooms, 0.6) and is_equal_approx(saved.soak, 1.0), "they are kept in the save")
	# The weather and what it left on the ground are kept too (2026-11-27 audit GAME-12, the
	# owner's pick): a reload in winter keeps its snow cover and its snowfall.
	var snowy := Clock.new()
	snowy.season = Clock.WINTER
	snowy.set_weather(Clock.WEATHERS.map(func(w: Dictionary) -> String: return w.id).find("snow"), true)
	snowy.weather_left = 0.2
	snowy.snowing = 0.8
	snowy.snow = 0.9
	snowy.wet = 0.3
	snowy.puddles = 0.4
	snowy.clouds = 0.85
	var back := Clock.new()
	back.from_dict(JSON.parse_string(JSON.stringify(snowy.to_dict())))
	_check(back.weather == snowy.weather and is_equal_approx(back.weather_left, 0.2) and is_equal_approx(back.snowing, 0.8)
		and is_equal_approx(back.snow, 0.9) and is_equal_approx(back.wet, 0.3) and is_equal_approx(back.puddles, 0.4)
		and is_equal_approx(back.clouds, 0.85), "the weather, its snowfall and the snow lying are kept in the save: %s" % [snowy.to_dict()])
	var odd := Clock.new()
	odd.from_dict({"weather": "nonsense", "snow": 7.0, "weather_left": -3.0})
	_check(odd.weather == Clock.CLEAR and odd.snow == 1.0 and odd.weather_left > 0.0, "a save's odd weather is read safely")
