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
const WorldData := preload("res://src/shared/world/world_data.gd")

## The air over a biome of warmth 0 and 1 (the middle of its warmth window), at midday
## in spring.
const COLDEST := -10.0
const WARMEST := 35.0
## How the season moves the air (spring, summer, autumn, winter), and how much colder
## the night is than the day.
const SEASON := [0.0, 8.0, -3.0, -14.0]
const NIGHT := 6.0
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
## season, the time of day and the weather of `clock`, under the open sky; `roofed`
## keeps the weather off.
static func air(world, clock, p: Vector3, roofed := false) -> float:
	var t := 0.5
	if world != null:
		var b: int = world.biome_at(floori(p.x / WorldData.CELL), floori(p.z / WorldData.CELL))
		if b >= 0 and b < Biomes.RECORDS.size():
			var w: Array = Biomes.RECORDS[b].warmth
			t = (w[0] + w[1]) * 0.5
	var out := lerpf(COLDEST, WARMEST, t)
	if clock != null:
		out += SEASON[clampi(clock.season, 0, 3)] - NIGHT * (1.0 - clock.daylight())
		if not roofed:
			var w: Dictionary = clock.WEATHERS[clock.weather]
			out -= RAIN_CHILL * w.get("rain", 0.0) + SNOW_CHILL * w.get("snow", 0.0) + WIND_CHILL * w.get("wind", 0.0)
	return out


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


## The warmth of the clothes worn (Inventory.gear, each item's `warmth`).
static func clothes(gear: Dictionary) -> float:
	var out := 0.0
	for on: String in gear:
		out += Items.get_item(gear[on]).get("warmth", 0.0)
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
