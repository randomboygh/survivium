extends RefCounted
## The playtest page's switches on a playtest server (Config.playtest): a player who
## turned on «Читы на тестовом сервере» sends them (Protocol.CHEATS, Requests.may_cheat,
## src/client/settings.gd `send_cheats`), and the server takes them as the game in one's
## own world does (Settings.apply). Their own: the pace of walking and work, jumps in the
## air, the rate of skills, overload, hunger, thirst, fatigue, cold. The world's, for
## everyone on it: free building, tool wear, instant crafting, free items, animal
## attacks, and on the clock the season, the weather, the moon, the hour and the pace
## of time. Every value is checked for its type and clamped; a key not known is left.

## Bounds of the numbers (the page offers at most 8, 200 and 100).
const MOST_SPEED := 8.0
const MOST_SKILL := 200.0
const MOST_BOOST := 100.0
## Switches of the character (vitals and the bag) and of the world's rules.
const VITALS := ["hunger", "thirst", "fatigue", "cold"]
const RULES := ["free_build", "tool_wear", "instant_craft", "free_items", "animal_attacks"]


## Takes the switches in `d` for player `who` in `session`; false when `d` is no
## Dictionary.
static func apply(session, who, d: Variant) -> bool:
	if not d is Dictionary:
		return false
	var speed := _number(d, "speed", 1.0, MOST_SPEED)
	if is_finite(speed):
		who.haste = speed
		who.body.speed_scale = speed
	if d.get("air") is bool:
		who.cheat_air = d.air
	var skill := _number(d, "skill", 0.0, MOST_SKILL)
	if is_finite(skill):
		who.skills.rate = skill
	if d.get("heavy") is bool:
		who.inventory.heavy = d.heavy
	for k: String in VITALS:
		if d.get(k) is bool:
			who.vitals.set(k, d[k])
	for k: String in RULES:
		if d.get(k) is bool:
			session.rules.set(k, d[k])
	var clock = session.clock
	var boost := _number(d, "boost", 0.0, MOST_BOOST)
	if is_finite(boost):
		clock.time_speed = boost
	var season := _number(d, "season", 0.0, 3.0)
	if is_finite(season):
		clock.season = int(season)
		clock.season_clock = 0.0
		session.actions.on_season(clock.season)
	var weather := _number(d, "weather", -1.0, clock.WEATHERS.size() - 1.0)
	if is_finite(weather):
		if weather < 0.0:
			clock.weather_auto = true
		else:
			clock.set_weather(int(weather))
	var moon := _number(d, "moon", -1.0, 1.0)
	if is_finite(moon):
		clock.moon_pin = moon if moon >= 0.0 else -1.0
	var hour := _number(d, "hour", 0.0, 24.0)
	if is_finite(hour):
		clock.time_of_day = fposmod(hour / 24.0, 1.0)
	return true


## `d[key]` clamped to `low`..`high`, INF when it is not there or not a finite number.
static func _number(d: Dictionary, key: String, low: float, high: float) -> float:
	var v: Variant = d.get(key)
	if not (v is float or v is int) or not is_finite(float(v)):
		return INF
	return clampf(float(v), low, high)
