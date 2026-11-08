extends RefCounted
## Gestures (decision 183): a player waves, nods, shakes, points, beckons, bows, claps or
## sits down where they stand, and those near see their figure do it, an icon of it over
## their head for ICON_TIME seconds. A gesture is asked for by name (Protocol.GESTURE),
## kept on the one who made it (`gesture`, until `gesture_until`) and told to the others
## in their PEOPLE entry while it lasts (now); it stops when they move, swim or work, or
## after its `time` (0: until then, sitting). Each is
## {"name", "title" (the wheel's words), "anim" (the figure's animation, player.yaml),
## "time" (seconds), "key" (its number on the wheel)}.

const LIST: Array[Dictionary] = [
	{"name": "wave", "title": "Помахать", "anim": "wave", "time": 3.0},
	{"name": "yes", "title": "Да", "anim": "nod", "time": 2.0},
	{"name": "no", "title": "Нет", "anim": "shake", "time": 2.0},
	{"name": "point", "title": "Указать", "anim": "point", "time": 3.0},
	{"name": "beckon", "title": "Сюда", "anim": "beckon", "time": 3.0},
	{"name": "bow", "title": "Поклон", "anim": "bow", "time": 2.6},
	{"name": "clap", "title": "Хлопать", "anim": "clap", "time": 3.0},
	{"name": "sit", "title": "Сесть", "anim": "sit", "time": 0.0},
]
## Seconds the icon of a gesture shows over the head.
const ICON_TIME := 2.5


## The gesture named `name`, {} for none.
static func of(name: String) -> Dictionary:
	for g: Dictionary in LIST:
		if g.name == name:
			return g
	return {}


## `who` (a Character) makes gesture `name` at `now` (seconds): "" stops the one going.
## False for a name that is none.
static func make(who, name: String, now: float) -> bool:
	if name == "":
		who.gesture = ""
		return true
	var g := of(name)
	if g.is_empty():
		return false
	who.gesture = name
	who.gesture_until = now + g.time if g.time > 0.0 else INF
	return true


## The gesture `who` is making at `now`, "" for none: none once they move, swim, ride,
## sleep or work, or its time is up (and then it is over).
static func now_of(who, now: float) -> String:
	if who.gesture == "":
		return ""
	var body = who.get("body")
	if now >= who.gesture_until or who.moving() or who.riding != "" or body != null and body.swimming \
			or who.vitals.asleep:
		who.gesture = ""
	return who.gesture
