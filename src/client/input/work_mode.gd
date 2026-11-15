extends RefCounted
## What the build mode and the farming mode share (BuildMode, FarmMode extend this): a
## mode is entered from the bag with an item, takes the hands for its palette and gives
## them back as they were when it is left; it has a palette of the bag's items under a
## filter, an eraser, and the action button that works on by itself (`auto`). Each mode
## adds what it draws and asks of the server.

const ToolKinds := preload("res://src/shared/content/tools.gd")

## Seconds between two looks at whether the work going on by itself can go on.
const CHECK_TIME := 0.25

## The mode's state the bar shows changed.
signal changed

var game
var on := false
## Whether a stroke takes off what the mode draws instead of drawing it.
var erasing := false
## The palette's filter, one of the mode's FILTERS. Kept with the player.
var filter := "all"
## The action button is down: the work goes on until nothing is left of it.
var auto := false
## What the hands held and which was in use before the mode.
var _saved_hands: Array[String] = ["", ""]
var _saved_active := 0
var _check_clock := 0.0
## How many of each palette item the bag held at the last look (_on_bag_changed), and
## the bag looked at.
var _counts := {}
var _watched = null


func _init(g) -> void:
	game = g


## The mode's filters, "all" first.
func _filters() -> Array:
	return ["all"]


## Whether item `id` is in the palette under the filter now.
func _in_palette(_id: String) -> bool:
	return false


## Shows or hides the mode's bar.
func _show(_shown: bool) -> void:
	pass


## The mode is being left (its strokes are cancelled, the hands not given back yet).
func _left() -> void:
	pass


## The items of the bag the mode works with that pass the filter, in the bag's order,
## each once.
func palette() -> Array[String]:
	var out: Array[String] = []
	for s in game.character.inventory.slots:
		if s != null and _in_palette(s[0]) and not out.has(s[0]):
			out.append(s[0])
	return out


## What the hands held before the mode, as Controls.to_dict keeps them.
func saved_hands() -> Dictionary:
	return {"hands": _saved_hands.duplicate(), "active": _saved_active}


## Turns the mode on, if it is not: the hands are remembered and its bar shows.
func _begin() -> void:
	if on:
		return
	var c = game.controls
	_saved_hands = [c.hands[0], c.hands[1]]
	_saved_active = c.active
	on = true
	erasing = false
	auto = false
	# The bar shows no filters for now: the palette holds everything.
	filter = "all"
	c.cancel_stroke()
	_watch()
	_show(true)


## Watches the bag: what comes into it while the mode is on (a thing taken back, a block
## knocked out, a harvest) has its slot chosen on the palette, unless the hand holds a tool
## (the user's rule, 2026-11-15).
func _watch() -> void:
	var inv = game.character.inventory
	if _watched != inv:
		if _watched != null and _watched.changed.is_connected(_on_bag_changed):
			_watched.changed.disconnect(_on_bag_changed)
		inv.changed.connect(_on_bag_changed)
		_watched = inv
	_counts = _palette_counts()


func _palette_counts() -> Dictionary:
	var out := {}
	var inv = game.character.inventory
	for id in palette():
		out[id] = inv.count(id)
	return out


func _on_bag_changed() -> void:
	var now := _palette_counts()
	# A tool in the hand stays in it (a sickle reaping, the user's rule, 2026-11-15).
	if on and not auto and ToolKinds.use_of(game.controls.held()) != "tool":
		for id: String in now:
			if now[id] > int(_counts.get(id, 0)) and id != game.controls.held():
				game.controls.put_in_hand(id, -1, false)
				changed.emit()
				break
	_counts = now


## Leaves the mode: the hands hold again what they held before it.
func leave() -> void:
	if not on:
		return
	on = false
	auto = false
	var c = game.controls
	c.cancel_stroke()
	_left()
	var inv = game.character.inventory
	for h in 2:
		var id: String = _saved_hands[h]
		c.hands[h] = id if id == "" or inv.count(id) > 0 else ""
	c.active = _saved_active
	game.cursor.show_cells([], true)
	_show(false)
	game.hud.refresh_hands()
	changed.emit()


func set_filter(f: String) -> void:
	if f in _filters():
		filter = f
		changed.emit()


func set_erasing(e: bool) -> void:
	erasing = e
	changed.emit()
