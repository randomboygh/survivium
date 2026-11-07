extends RefCounted
## The build mode: building is done here only (thread «Сделать отдельный режим
## строительства», 2026-11-06). It is entered from the bag with a block or a part of a
## house chosen (InventoryWindow's «Строить», or a block's slot on the hotbar), and the
## hotbar turns into the palette of what the bag holds to build with (BuildBar; its
## filters «Всё» / «Материалы» / «Интерьер» are not shown for now). The hand in use holds what is chosen on the
## palette, the other hand keeps what it held (a torch stays lit). A stroke on the world
## draws the blueprint's shape (Plans.KINDS: line, plane, square, cube; walls `height`
## levels high and `thick` cells thick) with the block chosen, or takes the ghost off
## the box of the shape (`erasing`); the action button pressed once (`auto`) builds the
## whole blueprint near the player cell by cell and lets go after the last one (or when
## the bag has no block left for it). A tap on a part of a house set down takes it back
## into the bag: they are taken only here. Leaving gives the hands back what they held
## before. `game` is the Main node.

const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## The palette's filters: everything, blocks (Tools.use_of "place"), parts of a house
## (Items.is_interior).
const FILTERS := ["all", "blocks", "interior"]
## The shapes the shape button goes round (Plans.KINDS but flattening).
const SHAPES := ["line", "plane", "square", "cube"]
## How often the auto build looks whether the bag still holds a block for the
## blueprint, in seconds (the ghost may have thousands of cells).
const CHECK_TIME := 0.25

## The mode's state changed (the bar shows it anew).
signal changed

var game
var on := false
## The shape drawn (one of Plans.KINDS), how high its walls are (levels) and how thick
## (cells). Kept with the player.
var kind := "line"
## The last shape of the four drawn (line, plane, square, cube): the shape button goes
## back to it from flattening.
var shape := "line"
var height := 2
var thick := 1
## The form of the blocks drawn (WorldData.FORM_*: a cube, a ramp, an upturned ramp,
## stairs), and the quarter turns from the way they rise by themselves: away from the
## player, so a ramp or stairs drawn ahead go up from where they stand. Kept with the
## player.
var form := 0
var turns := 0
## Whether a stroke takes the ghost off instead of drawing it.
var erasing := false
## The palette's filter, one of FILTERS. Kept with the player.
var filter := "all"
## The action button is down: the blueprint is built until its last cell.
var auto := false
## What the hands held and which was in use before the mode.
var _saved_hands: Array[String] = ["", ""]
var _saved_active := 0
var _check_clock := 0.0


func _init(g) -> void:
	game = g


func to_dict() -> Dictionary:
	return {"kind": kind, "height": height, "thick": thick, "filter": filter, "form": form, "turns": turns}


func from_dict(d: Dictionary) -> void:
	var k: Variant = d.get("kind")
	kind = k if k is String and k in Plans.KINDS else "line"
	shape = kind if kind in SHAPES else "line"
	height = clampi(int(d.get("height", 2)), Plans.MIN_HEIGHT, Plans.MAX_HEIGHT)
	thick = clampi(int(d.get("thick", 1)), Plans.MIN_THICK, Plans.MAX_THICK)
	var f: Variant = d.get("filter")
	filter = f if f is String and f in FILTERS else "all"
	form = clampi(int(d.get("form", 0)), 0, 3)
	turns = clampi(int(d.get("turns", 0)), 0, 3)


## Whether item `id` is built with in the build mode: a block, or a part of a house.
static func builds_with(id: String) -> bool:
	return id != "" and (Tools.use_of(id) == "place" or Items.is_interior(id))


## Whether item `id` passes palette filter `f`.
static func passes(id: String, f: String) -> bool:
	match f:
		"blocks":
			return Tools.use_of(id) == "place"
		"interior":
			return Items.is_interior(id)
	return builds_with(id)


## The items of the bag to build with that pass the filter, in the bag's order, each once.
func palette() -> Array[String]:
	var out: Array[String] = []
	for s in game.character.inventory.slots:
		if s != null and passes(s[0], filter) and not out.has(s[0]):
			out.append(s[0])
	return out


## What the hands held before the mode, as Controls.to_dict keeps them.
func saved_hands() -> Dictionary:
	return {"hands": _saved_hands.duplicate(), "active": _saved_active}


## Enters the mode with item `id` chosen (or chooses it, already in it).
func enter(id: String) -> void:
	if game.farm != null and game.farm.on:
		game.farm.leave()
	if not on:
		var c = game.controls
		_saved_hands = [c.hands[0], c.hands[1]]
		_saved_active = c.active
		on = true
		erasing = false
		auto = false
		# The bar shows no filters for now: the palette holds everything.
		filter = "all"
		c.cancel_stroke()
		game.hud.show_build(true)
	choose(id)


## Leaves the mode: the hands hold again what they held before it.
func leave() -> void:
	if not on:
		return
	on = false
	auto = false
	var c = game.controls
	c.cancel_stroke()
	var inv = game.character.inventory
	for h in 2:
		var id: String = _saved_hands[h]
		c.hands[h] = id if id == "" or inv.count(id) > 0 else ""
	c.active = _saved_active
	game.cursor.show_cells([], true)
	game.hud.show_build(false)
	game.hud.refresh_hands()
	changed.emit()


## Item `id` of the palette into the hand in use.
func choose(id: String) -> void:
	game.controls.put_in_hand(id, -1, false)
	changed.emit()


## The item chosen on the palette (in the hand in use).
func chosen() -> String:
	return game.controls.held()


func set_kind(k: String) -> void:
	if k in Plans.KINDS:
		kind = k
		if k in SHAPES:
			shape = k
		changed.emit()


## The shape button: the next of the four shapes round, or back to the last one from
## flattening.
func next_kind() -> void:
	set_kind(shape if kind not in SHAPES else SHAPES[(SHAPES.find(kind) + 1) % SHAPES.size()])


## The form button: the next form round (a cube, a ramp, an upturned ramp, stairs).
func next_form() -> void:
	set_form((form + 1) % 4)


## The form of the blocks drawn (a WorldData.FORM_*).
func set_form(f: int) -> void:
	form = clampi(f, 0, 3)
	changed.emit()


## Turns the slopes and stairs drawn a quarter more.
func turn() -> void:
	turns = (turns + 1) % 4
	changed.emit()


## The form of the blocks of a stroke from `first` (WorldData.forms): the form chosen,
## rising toward the side of the shape away from the player, turned `turns` more.
func form_of(first: Vector3i, last: Vector3i) -> int:
	if form == 0:
		return 0
	var p: Vector3 = game.player.position / Plans.CELL
	var mid := (Vector2(first.x, first.z) + Vector2(last.x, last.z)) * 0.5 + Vector2(0.5, 0.5)
	var d := mid - Vector2(p.x, p.z)
	# North (-z) 0, east 1, south 2, west 3.
	var side := (1 if d.x > 0.0 else 3) if absf(d.x) > absf(d.y) else (2 if d.y > 0.0 else 0)
	return form | ((side + turns) % 4) << 2


func set_filter(f: String) -> void:
	if f in FILTERS:
		filter = f
		changed.emit()


## The walls one level higher, round from the highest to the lowest.
func next_height() -> void:
	height = Plans.MIN_HEIGHT + (height - Plans.MIN_HEIGHT + 1) % (Plans.MAX_HEIGHT - Plans.MIN_HEIGHT + 1)
	changed.emit()


## The walls one cell thicker, round from the thickest to the thinnest.
func next_thick() -> void:
	thick = Plans.MIN_THICK + (thick - Plans.MIN_THICK + 1) % (Plans.MAX_THICK - Plans.MIN_THICK + 1)
	changed.emit()


func set_erasing(e: bool) -> void:
	erasing = e
	changed.emit()


## Takes the ghost off near the player.
func clear() -> void:
	game.net.request(Protocol.PLAN_CLEAR, [])
	auto = false
	changed.emit()


## The action button: down builds the blueprint until its last cell, a second press stops.
func toggle_auto() -> void:
	if auto:
		auto = false
	elif game.plans.cells.is_empty() or game.plans.cells.size() == game.farm.marks():
		game.character.nag("plan_none", "Нет чертежа: нарисуйте его на земле")
	elif not _has_blocks():
		game.character.nag("no_block", "В сумке нет блоков для чертежа")
	else:
		auto = true
		_check_clock = CHECK_TIME
	changed.emit()


## Runs the auto build for a frame; called while playing.
func update(delta: float) -> void:
	if not on or not auto:
		return
	_check_clock -= delta
	if _check_clock <= 0.0:
		_check_clock = CHECK_TIME
		if game.plans.cells.size() == game.farm.marks():
			auto = false
			game.hud.toast("Чертёж построен")
			changed.emit()
			return
		if not _has_blocks():
			auto = false
			game.character.nag("no_block", "В сумке нет блоков для чертежа")
			changed.emit()
			return
	game.controls.build_step()


## Whether the bag holds a block for some ghost cell (or building is free).
func _has_blocks() -> bool:
	if game.rules.free_build:
		return true
	var inv = game.character.inventory
	var seen := {}
	for c: Vector3i in game.plans.cells:
		var item: String = game.plans.cells[c]
		if item == Plans.CUT:
			return true
		if Plans.is_mark(item):
			continue
		if not seen.has(item):
			seen[item] = true
			if inv.count(item) > 0:
				return true
	return false


# --- Strokes -----------------------------------------------------------------------


## A tap at screen point `pos` (mouse `button`): a part of a house there is taken back
## into the bag; else a stroke of the blueprint begins (the dictionary Controls keeps
## while it is held, {} for none): from the ground cell tapped for a plane or a box (a
## floor takes the place of the top ground cell), from the cell over it for the walls.
func start_stroke(button: int, pos: Vector2) -> Dictionary:
	var target: Dictionary = game.gathering.target_at(pos)
	if target.has("prop") and not Placed.is_light(target.prop) and Items.is_interior(target.prop.item):
		game.net.request(Protocol.PROP_TAKE, [target.prop.cell])
		return {}
	var hit: Dictionary = game.controls.pick(pos)
	if hit.is_empty():
		return {}
	if Tools.use_of(chosen()) != "place" and not erasing:
		# A thing is set down at once where tapped (a door or a window into the side of a
		# wall tapped; on the top of a floor it stands on it, never cut into it).
		var item := Items.get_item(chosen())
		var cell: Vector3i = hit.cell
		var into_wall: bool = (item.get("door", false) or item.get("window", false)) \
			and hit.normal.y == 0 and not game.world.is_natural(cell.x, cell.y, cell.z)
		game.net.request(Protocol.PROP_PUT_AT, [chosen(), cell if into_wall else cell + hit.normal])
		return {}
	var first := start_cell(hit)
	if erasing:
		# The ghost under the finger, when it is nearer than the cell tapped.
		var ghost: Variant = game.controls.ghost_at(pos)
		if ghost != null:
			first = ghost
	return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "plan": kind,
		"first": first, "last": first, "normal": Vector3i.UP}


## The cell a stroke begins at on the cell `hit` (VoxelRaycast.cast): the ground cell for a
## plane or a box, the cell over it for the walls and for taking the ghost off.
func start_cell(hit: Dictionary) -> Vector3i:
	if kind in ["plane", "cube", "flatten"] and not erasing:
		return hit.cell
	return hit.cell + hit.normal


## The cells stroke `s` covers now: the shape, or the box the ghost goes off.
func stroke_cells(s: Dictionary) -> Array[Vector3i]:
	var p: Vector3 = game.player.position
	if erasing:
		return Plans.erase_box(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick)
	return Plans.shape(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick)


## Shows what stroke `s` would do: the cells the ghost goes on light, those it cannot and
## those over a dip red; the ghost to be taken off red.
func show_stroke(s: Dictionary) -> void:
	var cells := stroke_cells(s)
	if cells.is_empty():
		# Too big a shape: its corners red.
		game.cursor.show_boxes([], [s.first, s.last])
		return
	if erasing:
		var gone: Array[Vector3i] = []
		for c in cells:
			if game.plans.cells.has(c):
				gone.append(c)
		game.cursor.show_boxes([], gone, cells)
		return
	if kind == "flatten":
		# The level the ground is brought to.
		game.cursor.show_boxes(cells, [])
		return
	var sorted := _sorted(s, cells)
	var bad: Array[Vector3i] = []
	bad.assign(sorted.blocked + sorted.hanging)
	var good: Array[Vector3i] = []
	for c: Vector3i in sorted.fit:
		if not sorted.hanging.has(c):
			good.append(c)
	game.cursor.show_boxes(good, bad)


## The stroke ended: the server draws its ghost or takes it off; uneven ground is told.
func end_stroke(s: Dictionary) -> void:
	game.cursor.show_cells([], true)
	if not erasing and s.plan != "flatten":
		var cells := stroke_cells(s)
		if cells.is_empty():
			game.character.nag("plan_big", "Слишком большой чертёж")
			return
		var sorted := _sorted(s, cells)
		if not sorted.blocked.is_empty():
			game.hud.toast("Внутри блоков чертёж не рисуется")
		elif not sorted.hanging.is_empty():
			game.hud.toast("Неровная поверхность: под красными клетками пусто")
	game.net.request(Protocol.PLAN, [s.plan, s.first, s.last, height, thick, erasing, form_of(s.first, s.last)])


func _sorted(s: Dictionary, cells: Array[Vector3i]) -> Dictionary:
	var block := Mat.index(Items.get_item(chosen()).get("place", ""))
	return game.plans.sort(game.actions, game.character, s.plan, s.first, cells, block)
