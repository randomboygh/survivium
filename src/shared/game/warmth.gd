extends RefCounted
## How warm it is where a body stands, and how it feels to that body (plan/design/
## first-hours.md: soft survival, wet freezes faster, fire and a roof warm, winter nights
## are dangerous without fire or warm clothes). The air comes from the column's biome
## (its warmth window), the season, the time of day and the weather; the body feels it
## warmer by a burning campfire, under a roof and in clothes (an item's `warmth`, less
## when wet), colder when wet or swimming. Vitals turns the feel into the body's warmth.
## Shared: the server decides it, the client shows the air on the clock line. Numbers are
## degrees Celsius.

const Biomes := preload("res://src/shared/content/biomes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Quality := preload("res://src/shared/game/quality.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## The air over a biome of warmth 0 and 1 (the middle of its warmth window), at midday
## in spring.
const COLDEST := -10.0
const WARMEST := 35.0
## How the season moves the air (spring, summer, autumn, winter).
const SEASON := [0.0, 8.0, -3.0, -14.0]
## The day's round of the air (see daily): the warmest of a clear day comes at this
## sun time (Clock.sun_time: sunrise 0.25, noon 0.5, sunset 0.75; 0.6 is about three in
## the afternoon in spring), the coldest at sunrise, DAY_SWING degrees below it; clouds
## keep the warmth in at night and the sun off by day, a full sky of them leaves
## CLOUDED_SWING of the swing.
const WARMEST_AT := 0.6
const DAY_SWING := 11.0
const CLOUDED_SWING := 0.4
## How much colder rain, snow and wind make the air felt under the open sky (per their
## strength in Clock.WEATHERS).
const RAIN_CHILL := 4.0
const SNOW_CHILL := 5.0
const WIND_CHILL := 2.0
## A burning campfire warms this much at its middle, down to nothing FIRE_REACH world
## units off; a fire low on fuel warms less (FIRE_LOW of it about to go out).
const FIRE_HEAT := 26.0
const FIRE_REACH := 3.5
const FIRE_LOW := 0.4
## A roof overhead keeps rain, snow and wind off and holds this much warmth.
const ROOF := 3.0
## Wet clothes and skin: this much colder at full wetness, and clothes keep only
## WET_CLOTHES of their warmth then.
const WET_CHILL := 8.0
const WET_CLOTHES := 0.5
## Water is this much colder than the air (and never warmer than WATER_MOST).
const WATER_CHILL := 6.0
const WATER_MOST := 22.0


## The air at world point `p` (world units), by its column's biome in `world`, the
## season, the hour (daily) and the weather of `clock`, under the open sky; `roofed`
## keeps the weather off. The air the playtest page pins (Clock.air_pin) takes the place
## of the biome's and the season's, the same everywhere; the night and the weather still
## cool it.
static func air(world, clock, p: Vector3, roofed := false) -> float:
	var t := 0.5
	if world != null and (clock == null or not clock.air_pinned()):
		var b: int = world.biome_at(floori(p.x / WorldData.CELL), floori(p.z / WorldData.CELL))
		if b >= 0 and b < Biomes.RECORDS.size():
			var w: Array = Biomes.RECORDS[b].warmth
			t = (w[0] + w[1]) * 0.5
	var out := lerpf(COLDEST, WARMEST, t)
	if clock != null:
		if clock.air_pinned():
			out = clock.air_pin
		else:
			out += SEASON[clampi(clock.season, 0, 3)]
		out -= daily(clock)
		if not roofed:
			var w: Dictionary = clock.WEATHERS[clock.weather]
			out -= RAIN_CHILL * w.get("rain", 0.0) + SNOW_CHILL * w.get("snow", 0.0) + WIND_CHILL * w.get("wind", 0.0)
	return out


## How many degrees colder than the warmest of the day the air is now, by `clock`'s
## sun time and clouds: it warms from sunrise till WARMEST_AT and cools slowly through
## the evening and the night down to the next sunrise.
static func daily(clock) -> float:
	var s: float = clock.sun_time()
	var w: float
	var rise := 0.25
	if s >= rise and s < WARMEST_AT:
		w = 0.5 - 0.5 * cos(PI * (s - rise) / (WARMEST_AT - rise))
	else:
		w = 0.5 + 0.5 * cos(PI * fposmod(s - WARMEST_AT, 1.0) / (1.0 - WARMEST_AT + rise))
	var swing := DAY_SWING * lerpf(1.0, CLOUDED_SWING, clampf(clock.clouds, 0.0, 1.0))
	return swing * (1.0 - w)


## The warmth of the burning campfires of `placed` near world point `p`: the most any one
## gives (see FIRE_HEAT).
static func fire_heat(placed, p: Vector3) -> float:
	if placed == null:
		return 0.0
	var best := 0.0
	for e: Dictionary in placed.things:
		if not e.lit or not placed.is_fire(e):
			continue
		var d: float = placed.center(e).distance_to(p)
		if d < FIRE_REACH:
			var strength := lerpf(FIRE_LOW, 1.0, placed.fuel_share(e))
			best = maxf(best, FIRE_HEAT * strength * (1.0 - d / FIRE_REACH))
	return best


## The warmth of the clothes worn (Inventory.gear, each item's `warmth`), by their
## quality (`quality`: body slot -> its quality, Quality.lasts; normal for one not in it).
static func clothes(gear: Dictionary, quality := {}) -> float:
	var out := 0.0
	for on: String in gear:
		var q: int = quality.get(on, Items.NORMAL_QUALITY)
		out += Items.get_item(gear[on]).get("warmth", 0.0) * Quality.lasts(q)
	return out


## How warm it feels to a body in air `air`, by fires giving `fire`, in clothes of
## warmth `worn`, wet by `wet` (0..1), under a roof or not, swimming or not.
static func feel(air_t: float, fire: float, worn: float, wet: float, roofed: bool, swimming: bool) -> float:
	var out := air_t
	if swimming:
		return minf(air_t - WATER_CHILL, WATER_MOST)
	out += fire + worn * lerpf(1.0, WET_CLOTHES, wet) - WET_CHILL * wet
	if roofed:
		out += ROOF
	return out
