extends RefCounted
## The looks a player picks for their character (plan/design/character.md «Настройка
## внешности»): what content/core/sprites/player.yaml `looks` offers, and a look made
## sound. A look is {"build": an id of `build`, "figure": an id of `figure`, "skin": place in `skin`, "hair": a style's id, "hair_colour": place in
## `hair_colour`, "eyes": place in `eyes`, "face": an id of `face` or "", "on_face": an id
## of `on_face` or ""}. A character keeps its look in the world it lives in (Character
## `looks`): the server takes the one a player comes with only for a new character, and
## makes it sound first (`clean`), as everything a socket sends.

const Yaml := preload("res://src/shared/content/yaml.gd")
const Content := preload("res://src/shared/content/content.gd")

## Where the looks are told.
static var PATH: String = Content.ROOT + "/core/sprites/player.yaml"
## The fields of a look; those that are places in a list of colours.
const FIELDS := ["build", "figure", "skin", "hair", "hair_colour", "eyes", "face", "on_face"]
const COLOURS := ["skin", "hair_colour", "eyes"]
## The fields that may be left bare ("").
const BARE := ["face", "on_face"]

static var _data := {}
## The load of Content (Content.generation) _data was read from.
static var _read := -1


## player.yaml `looks`, read again after the mods change.
static func data() -> Dictionary:
	if _read != Content.generation:
		_read = Content.generation
		var all: Variant = Yaml.new().parse(Content.text(PATH), "player.yaml")
		_data = all.looks if all is Dictionary and all.get("looks") is Dictionary else {}
	return _data


## How many options field `field` has (a list of colours, or the ids of the others).
static func count(field: String) -> int:
	var v: Variant = data().get(field)
	return v.size() if v is Array or v is Dictionary else 0


## The ids of the options of `field` (all but the colours), in order; "" first for the
## face's two, which may be left bare (BARE).
static func ids(field: String) -> Array:
	var v: Variant = data().get(field)
	var out: Array = [""] if field in BARE else []
	if v is Dictionary:
		out += v.keys()
	return out


## The look of a character nobody picked one for.
static func default_look() -> Dictionary:
	return clean({})


## A look of options picked at random from `rng` (the bots'): the face's two left bare
## half the time.
static func random(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for field: String in FIELDS:
		if field in COLOURS:
			out[field] = rng.randi_range(0, maxi(count(field) - 1, 0))
		else:
			var all := ids(field)
			out[field] = all[rng.randi_range(0, all.size() - 1)] if all.size() > 0 and (field not in BARE or rng.randf() < 0.5) else ""
	return clean(out)


## `v` as a sound look: each field of the right type and among the options, else the
## default's (a face's fields: none; a look saved before a field was added gets its default). Anything else in `v` is left out.
static func clean(v: Variant) -> Dictionary:
	var d := data()
	var given: Dictionary = v if v is Dictionary else {}
	var base: Dictionary = d.get("default", {}) if d.get("default") is Dictionary else {}
	var out := {}
	for field: String in FIELDS:
		var n := count(field)
		if field in COLOURS:
			var fallback := clampi(int(base.get(field, 0)) if base.get(field) is int else 0, 0, maxi(n - 1, 0))
			# A saved look read from JSON has its numbers as floats.
			var at: Variant = given.get(field)
			var whole: bool = at is int or at is float and is_finite(at) and at == floorf(at)
			out[field] = int(at) if whole and at >= 0 and at < n else fallback
		else:
			var known: Variant = d.get(field)
			var styles: Dictionary = known if known is Dictionary else {}
			var at: Variant = given.get(field)
			var fallback := "" if field in BARE else str(base.get(field, ""))
			out[field] = at if at is String and styles.has(at) else (fallback if styles.has(fallback) else "")
	return out
