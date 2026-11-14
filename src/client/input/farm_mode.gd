extends "res://src/client/input/work_mode.gd"
## The farming mode (thread «Сделать режим земледелия», 2026-11-06), made like the build
## mode (BuildMode): it is entered from the bag with seeds, a bush, a hoe, a watering can
## with water or a sickle chosen (InventoryWindow's «Огород»), or a slot of seeds or a
## bush on the hotbar, and the hotbar turns into the palette of what the bag holds to
## sow and plant (FarmBar; its filters «Всё» / «Семена» / «Кусты» are not shown for now). The bar picks the
## work (Plans.WORKS: till, sow, water, reap) and the shape of a stroke (a line, or a
## filled square); a stroke on the ground marks the work on the top ground cell of each
## column (Plans.mark), or takes the marks off (`erasing`). The action button pressed
## once (`auto`) does the marked work near the player cell by cell with the tools of the
## bag (Plans.farm: the best hoe, a can with water, a sickle or the hands, the seeds of
## each mark) and lets go when nothing near can be done now. The hand in use holds what
## the work is done with; leaving gives the hands back what they held before. `game` is
## the Main node.

const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## The palette's filters: everything, seeds (sown: a crop, grass), bushes (planted).
const FILTERS := ["all", "seeds", "bushes"]
## The shapes of a stroke: a line, a filled square.
const SHAPES := ["line", "square"]

## The work marked (one of Plans.WORKS) and the shape of a stroke. Kept with the player.
var work := "sow"
var shape := "line"
## What is sown when the work is to sow (the palette's choice).
var seed := ""


func to_dict() -> Dictionary:
	return {"work": work, "shape": shape, "filter": filter}


func from_dict(d: Dictionary) -> void:
	var w: Variant = d.get("work")
	work = w if w is String and w in Plans.WORKS else "sow"
	var s: Variant = d.get("shape")
	shape = s if s is String and s in SHAPES else "line"
	var f: Variant = d.get("filter")
	filter = f if f is String and f in FILTERS else "all"


## Whether item `id` is sown or planted (on the palette).
static func sows(id: String) -> bool:
	return id != "" and Tools.use_of(id) in ["plant", "sow"]


## The work tool item `id` does in the mode ("till", "water", "reap"), "" for none.
static func work_of(id: String) -> String:
	if id == "":
		return ""
	var t := Tools.of(id)
	if Tools.can_till(t):
		return "till"
	if Tools.can_water(t):
		return "water"
	if t.tool == "sickle":
		return "reap"
	return ""


## Whether item `id` enters the mode from the bag: seeds, a bush, a farming tool.
static func farms_with(id: String) -> bool:
	return sows(id) or work_of(id) != ""


## Whether item `id` passes palette filter `f`.
static func passes(id: String, f: String) -> bool:
	match f:
		"seeds":
			return Tools.use_of(id) == "sow"
		"bushes":
			return Tools.use_of(id) == "plant"
	return sows(id)


func _filters() -> Array:
	return FILTERS


func _in_palette(id: String) -> bool:
	return passes(id, filter)


func _show(shown: bool) -> void:
	game.hud.show_farm(shown)


## Enters the mode with item `id` chosen: seeds to sow, a tool for its work.
func enter(id: String) -> void:
	if game.build.on:
		game.build.leave()
	_begin()
	if sows(id):
		choose(id)
	elif work_of(id) != "":
		set_work(work_of(id))
	else:
		set_work(work)


## Item `id` of the palette is sown: into the hand in use.
func choose(id: String) -> void:
	seed = id
	work = "sow"
	_hold()
	changed.emit()


## The work marked and done: the hand in use takes what it is done with (the seeds
## chosen, the best hoe, a can with water, a sickle; bare hands to reap without one).
func set_work(w: String) -> void:
	if w not in Plans.WORKS:
		return
	work = w
	_hold()
	changed.emit()


## The work button: the next work round.
func next_work() -> void:
	set_work(Plans.WORKS[(Plans.WORKS.find(work) + 1) % Plans.WORKS.size()])


func _hold() -> void:
	var id := ""
	match work:
		"sow":
			if seed == "" or game.character.inventory.count(seed) == 0:
				var p := palette()
				seed = p[0] if not p.is_empty() else ""
			id = seed
		"till":
			id = _best(func(t: Dictionary) -> bool: return Tools.can_till(t))
		"water":
			id = _best(func(t: Dictionary) -> bool: return Tools.can_water(t))
		"reap":
			id = _best(func(t: Dictionary) -> bool: return t.tool == "sickle")
	game.controls.put_in_hand(id, -1, false)


## The tool of the bag that passes `fits` and works the most cells a swing, "" for none.
func _best(fits: Callable) -> String:
	var best := ""
	var area := -1
	for s in game.character.inventory.slots:
		if s == null or not Tools.is_tool_item(s[0]):
			continue
		var t := Tools.of(s[0])
		if fits.call(t) and int(t.get("area", 1)) > area:
			best = s[0]
			area = int(t.get("area", 1))
	return best


## The item in the hand in use.
func chosen() -> String:
	return game.controls.held()


func next_shape() -> void:
	shape = SHAPES[(SHAPES.find(shape) + 1) % SHAPES.size()]
	changed.emit()


## Not used: nothing to turn (Controls' Y key in the build mode).
func turn() -> void:
	pass


## Takes the marks off near the player.
func clear() -> void:
	game.net.request(Protocol.FARM_CLEAR, [])
	auto = false
	changed.emit()


## The marks of the farming mode in the client's copy of the plans.
func marks() -> int:
	var n := 0
	for c: Vector3i in game.plans.cells:
		if Plans.is_mark(game.plans.cells[c]):
			n += 1
	return n


## The action button: down works the marks near until none can be, a second press stops.
func toggle_auto() -> void:
	if auto:
		auto = false
	elif marks() == 0:
		game.character.nag("farm_none", "[no_marking_draw_it_on]")
	else:
		auto = true
		_check_clock = CHECK_TIME
	changed.emit()


## The auto work stops (nothing near can be done now: the server said why).
func stop() -> void:
	if auto:
		auto = false
		changed.emit()


## Runs the auto work for a frame; called while playing.
func update(delta: float) -> void:
	if not on or not auto:
		return
	_check_clock -= delta
	if _check_clock <= 0.0:
		_check_clock = CHECK_TIME
		if marks() == 0:
			auto = false
			game.hud.toast("[all_marked_work_is_done]")
			changed.emit()
			return
	game.controls.farm_step()


# --- Strokes -----------------------------------------------------------------------


## A tap at screen point `pos` (mouse `button`): a stroke of marks begins on the ground
## cell tapped (the dictionary Controls keeps while it is held, {} for none).
func start_stroke(button: int, pos: Vector2) -> Dictionary:
	var hit: Dictionary = game.controls.pick(pos)
	if hit.is_empty():
		return {}
	var first := start_cell(hit)
	return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "plan": "farm",
		"first": first, "last": first, "normal": Vector3i.UP}


## The cell a stroke begins at on the cell `hit` (VoxelRaycast.cast): the cell tapped
## (the server finds the ground of each column near its level, Plans.surface).
func start_cell(hit: Dictionary) -> Vector3i:
	return hit.cell


## Shows what stroke `s` would do: the ground the marks go on light, where they cannot
## red; the marks to be taken off red.
func show_stroke(s: Dictionary) -> void:
	if Plans.farm_columns(shape == "square", s.first, s.last).is_empty():
		game.cursor.show_boxes([], [s.first, s.last])
		return
	if erasing:
		var gone: Array[Vector3i] = []
		for col in Plans.farm_columns(shape == "square", s.first, s.last):
			for y in range(s.first.y - Plans.FARM_DOWN, s.first.y + Plans.FARM_UP + 1):
				var c := Vector3i(col.x, y, col.y)
				if game.plans.cells.has(c) and Plans.is_mark(game.plans.cells[c]):
					gone.append(c)
		game.cursor.show_boxes([], gone)
		return
	var sorted := _sorted(s)
	var good: Array[Vector3i] = []
	good.assign(sorted.fit)
	var bad: Array[Vector3i] = []
	bad.assign(sorted.blocked)
	game.cursor.show_boxes(good, bad)


## The stroke ended: the server marks the work or takes the marks off.
func end_stroke(s: Dictionary) -> void:
	game.cursor.show_cells([], true)
	if not erasing:
		if Plans.farm_columns(shape == "square", s.first, s.last).is_empty():
			game.character.nag("plan_big", "[the_marking_is_too_big]")
			return
		if work == "sow" and not sows(chosen()):
			game.character.nag("no_seed", "[nothing_to_plant_no_seeds_n2]")
			return
	game.net.request(Protocol.FARM, [work, s.first, s.last, shape == "square", erasing])


func _sorted(s: Dictionary) -> Dictionary:
	return game.plans.farm_sort(game.actions, game.character, work, chosen(), shape == "square", s.first, s.last)
