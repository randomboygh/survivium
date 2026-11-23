extends "res://src/client/input/work_mode.gd"
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
## into the bag: they are taken only here. A thing that moves (Placed.movable: a station,
## a chest, furniture, a sign) is taken up into the air by a finger or the mouse held on
## it, carried to another place and set down there as it is let go; a double tap turns
## it a quarter, and the next of its kind is set down turned so (`kept_turns`) while the
## bag holds one; a single tap takes it once the double tap's time is over. A thing new from the bag is set down
## where tapped, or held hangs in the air the same way and is set down where it is let
## go. Leaving gives the hands back what they held before.
## `game` is the Main node.

const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## The palette's filters: everything, blocks (Tools.use_of "place"), parts of a house
## (Items.is_interior).
const FILTERS := ["all", "blocks", "interior"]
## The shapes the shape button goes round (Plans.KINDS but flattening).
const SHAPES := ["line", "plane", "square", "cube"]
## The heights the shapes begin with.
const DEFAULT_HEIGHTS := {"line": 3, "plane": 1, "square": 3, "cube": 5}
## A second tap on the same thing within this many ms turns it (a double tap); a single
## tap takes it after them.
const DOUBLE_TAP_MS := 180
## A finger or the mouse held this many ms takes a thing up into the air (a thing set
## down, or one new from the bag to set down); let go sooner it was a tap.
const HOLD_MS := 280
## How far a finger or the mouse goes before a thing is taken up sooner than HOLD_MS, a
## share of the screen's shorter side.
const DRAG_SHARE := 0.025

## The shape drawn (one of Plans.KINDS), how high its walls are (levels) and how thick
## (cells). Kept with the player.
var kind := "line"
## The last shape of the four drawn (line, plane, square, cube): the shape button goes
## back to it from flattening.
var shape := "line"
## The height of the shape drawn now: the one kept for its kind in `heights`.
var height := 3
var thick := 1
## The height kept for each shape (levels): a floor one, walls three, a room five (a
## floor, three levels of walls, a ceiling). Kept with the player.
var heights := DEFAULT_HEIGHTS.duplicate()
## The form of the blocks drawn (WorldData.FORM_*: a cube, a ramp, an upturned ramp,
## stairs), and the quarter turns from the way they rise by themselves: away from the
## player, so a ramp or stairs drawn ahead go up from where they stand. Kept with the
## player.
var form := 0
var turns := 0
## A tap on a thing that moves waiting to see whether a second one comes: {"cell", "ms"},
## {} for none (see DOUBLE_TAP_MS).
var _tap_wait := {}
## The turn the player last gave a thing of each kind by a double tap, by item id: the
## next ones are set down turned so while the bag holds one (then it is forgotten).
var kept_turns := {}
## The thing dragged now (see drag), {} for none.
var _dragged := {}


func to_dict() -> Dictionary:
	return {"kind": kind, "heights": heights.duplicate(), "thick": thick, "filter": filter, "form": form, "turns": turns}


func from_dict(d: Dictionary) -> void:
	var k: Variant = d.get("kind")
	kind = k if k is String and k in Plans.KINDS else "line"
	shape = kind if kind in SHAPES else "line"
	# Kept per shape since 2026-11-07 (one "height" before: the shapes begin anew).
	heights = DEFAULT_HEIGHTS.duplicate()
	var hs: Variant = d.get("heights")
	if hs is Dictionary:
		for sh in SHAPES:
			if hs.has(sh):
				heights[sh] = clampi(int(hs[sh]), lowest(sh), Plans.MAX_HEIGHT)
	height = heights[shape]
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


func _filters() -> Array:
	return FILTERS


func _in_palette(id: String) -> bool:
	return passes(id, filter)


func _show(shown: bool) -> void:
	game.hud.show_build(shown)


## A thing dragged is set down, one new from the bag held up goes.
func _left() -> void:
	_take_waiting()
	game.props.drop_new()
	if not _dragged.is_empty():
		game.props.settle(_dragged)
		_dragged = {}


## Enters the mode with item `id` chosen (or chooses it, already in it).
func enter(id: String) -> void:
	if game.farm != null and game.farm.on:
		game.farm.leave()
	_begin()
	choose(id)


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
			height = heights[k]
		changed.emit()


## The lowest height of shape `k`: a room has a floor, walls and a ceiling.
static func lowest(k: String) -> int:
	return Plans.MIN_ROOM if k == "cube" else Plans.MIN_HEIGHT


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


## Whether the shape drawn now takes slopes and stairs (a line or a square, drawn as a
## flight of them: Plans.flight); a plane and a room are of cubes.
func forms_drawn() -> bool:
	return kind in Plans.FLIGHTS


## The form of the blocks of a stroke from `first` (WorldData.forms): the form chosen, 0
## for a shape of cubes (forms_drawn). A flight rises along the stroke (Plans.flight);
## the side kept here is for a stroke of one column: away from the player, turned
## `turns` more.
func form_of(first: Vector3i, last: Vector3i) -> int:
	if form == 0 or not forms_drawn():
		return 0
	var p: Vector3 = game.player.position / Plans.CELL
	var mid := (Vector2(first.x, first.z) + Vector2(last.x, last.z)) * 0.5 + Vector2(0.5, 0.5)
	var d := mid - Vector2(p.x, p.z)
	# North (-z) 0, east 1, south 2, west 3.
	var side := (1 if d.x > 0.0 else 3) if absf(d.x) > absf(d.y) else (2 if d.y > 0.0 else 0)
	return form | ((side + turns) % 4) << 2


## The shape one level higher, round from the highest to the lowest; kept for the shape.
func next_height() -> void:
	var low := lowest(shape)
	set_height(low + (height - low + 1) % (Plans.MAX_HEIGHT - low + 1))


func set_height(h: int) -> void:
	height = clampi(h, lowest(shape), Plans.MAX_HEIGHT)
	heights[shape] = height
	changed.emit()


## The walls one cell thicker, round from the thickest to the thinnest.
func next_thick() -> void:
	thick = Plans.MIN_THICK + (thick - Plans.MIN_THICK + 1) % (Plans.MAX_THICK - Plans.MIN_THICK + 1)
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
		game.character.nag("plan_none", "[no_blueprint_draw_one_on]")
	elif not _has_blocks():
		game.character.nag("no_block", "[no_blocks_in_the_bag]")
	else:
		auto = true
		_check_clock = CHECK_TIME
	changed.emit()


## Runs the auto build for a frame; called while playing.
func update(delta: float) -> void:
	if not _tap_wait.is_empty() and Time.get_ticks_msec() - int(_tap_wait.ms) > DOUBLE_TAP_MS:
		_take_waiting()
	for id: String in kept_turns.keys():
		if game.character.inventory.count(id) <= 0:
			kept_turns.erase(id)
	if game.props.holding_new() and not game.controls.dragging().has("put"):
		# A thing new from the bag held up with no stroke on it any more goes.
		game.cursor.show_boxes([], [])
		game.props.drop_new()
	if not _dragged.is_empty() and not is_same(game.controls.dragging().get("prop"), _dragged):
		# Held up with no finger or button on it any more (its stroke went another way):
		# it drops back where it stands, never left hanging in the air.
		game.cursor.show_boxes([], [])
		game.props.settle(_dragged)
		_dragged = {}
	if not on or not auto:
		return
	_check_clock -= delta
	if _check_clock <= 0.0:
		_check_clock = CHECK_TIME
		if game.plans.cells.size() == game.farm.marks():
			auto = false
			game.hud.toast("[blueprint_built]")
			changed.emit()
			return
		if not _has_blocks():
			auto = false
			game.character.nag("no_block", "[no_blocks_in_the_bag]")
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
	var item := Items.get_item(chosen())
	if target.has("prop") and not erasing and item.get("ladder", false) and Placed.is_ladder(target.prop):
		# A ladder tapped with a ladder goes on up from its top.
		var top: Vector3i = target.prop.cell
		while game.world.ladders.has(top + Vector3i.UP):
			top += Vector3i.UP
		game.net.request(Protocol.PROP_PUT_AT, [chosen(), top + Vector3i.UP])
		return {}
	if target.has("prop") and not erasing and item.get("door", false) and item.get("fence", false) \
			and Placed.is_fence(target.prop):
		# A wicket or a gate tapped onto a fence takes the place of its segments.
		game.net.request(Protocol.PROP_PUT_AT, [chosen(), target.prop.cell])
		return {}
	if target.has("prop") and not Placed.is_light(target.prop) and Items.is_interior(target.prop.item) \
			and not erasing and _beside_kind(target.prop):
		# A thing one cell big tapped with one of its kind in the hand: the next is set down
		# beside it (held, it hangs in the air there), not the one standing taken; once the
		# bag holds none of them a tap takes them back.
		var near: Dictionary = target.prop
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "put": chosen(),
			"from": pos, "ms": Time.get_ticks_msec(), "up": false, "aim": _beside(near, pos),
			"turn": kept_turns.get(chosen(), game.props.view_turn()), "kept": kept_turns.has(chosen()),
			"spot": null, "shown": null}
	if target.has("prop") and Placed.is_light(target.prop) and not erasing:
		# A light (a torch, a candle) set down: held, it is carried to another cell with its
		# flame; only tapped, it goes back into the bag.
		_take_waiting()
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "prop": target.prop,
			"from": pos, "ms": Time.get_ticks_msec(), "moved": false, "to": null, "corner": null,
			"turn": 0, "shown": null, "grab": Vector3i.ZERO}
	if target.has("prop") and not Placed.is_light(target.prop) and Items.is_interior(target.prop.item):
		var e: Dictionary = target.prop
		if not Placed.movable(e):
			_take(e.cell)
			return {}
		if not _tap_wait.is_empty() and _tap_wait.cell == e.cell:
			# The second tap of a double tap.
			_tap_wait = {}
			turn_thing(e)
			return {}
		_take_waiting()
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "prop": e,
			"from": pos, "ms": Time.get_ticks_msec(), "moved": false, "to": null, "corner": null,
			"turn": int(e.get("turn", 0)), "shown": null, "grab": _grab(e, pos)}
	var hit: Dictionary = game.controls.pick(pos)
	if hit.is_empty():
		return {}
	if not erasing and game.world.is_cracked(hit.cell.x, hit.cell.y, hit.cell.z):
		# A cracked block (building decay) tapped is mended, free, with a swing of the tool
		# in the hand (decision 6A); once whole, a tap on it builds on as ever.
		game.controls.mend(hit.cell)
		return {}
	if not Plans.drawn_with(chosen()) and not erasing:
		# A thing is set down where tapped as the finger lifts; held, it hangs in the air over
		# the place under the finger until it is let go (drag, release).
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "put": chosen(),
			"from": pos, "ms": Time.get_ticks_msec(), "up": false, "aim": _aim(hit, item),
			"turn": kept_turns.get(chosen(), game.props.view_turn()), "kept": kept_turns.has(chosen()),
			"spot": null, "shown": null}
	var first := start_cell(hit)
	if erasing:
		# The ghost under the finger, when it is nearer than the cell tapped.
		var ghost: Variant = game.controls.ghost_at(pos)
		if ghost != null:
			first = ghost
	return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "plan": kind,
		"first": first, "last": first, "normal": Vector3i.UP}


## The cell of thing `e` under screen point `pos`, from its north-west cell (the thing
## dragged keeps it under the finger).
func _grab(e: Dictionary, pos: Vector2) -> Vector3i:
	var n := Placed.size_of(e.item)
	var on_it: Variant = game.controls.on_plane(pos, e.cell, Vector3i.UP)
	if on_it == null:
		return Vector3i.ZERO
	var d: Vector3i = on_it - e.cell
	return Vector3i(clampi(d.x, 0, n - 1), 0, clampi(d.z, 0, n - 1))


## The cell a thing new from the bag is set down at on the cell `hit` (VoxelRaycast.cast)
## of item record `item`: a door or a window into the side of a wall tapped; on the top of
## a floor it stands on it, never cut into it; a hatch into the floor or the ceiling of
## blocks tapped; else the cell over the face tapped.
func _aim(hit: Dictionary, item: Dictionary) -> Vector3i:
	var cell: Vector3i = hit.cell
	var built: bool = not game.world.is_natural(cell.x, cell.y, cell.z)
	var into_wall: bool = (item.get("door", false) or item.get("window", false)) and not item.get("hatch", false) \
		and hit.normal.y == 0 and built
	var into_floor: bool = item.get("hatch", false) and hit.normal.y != 0 and built
	return cell if into_wall or into_floor else cell + hit.normal


## Thing `e` turned a quarter where it stands (a double tap on it), and the next of its
## kind set down turned so while the bag holds one (kept_turns).
func turn_thing(e: Dictionary) -> void:
	var turned := (int(e.get("turn", 0)) + 1) % 4
	kept_turns[e.item] = turned
	game.net.request(Protocol.PROP_MOVE, [e.cell, e.cell, turned])


## The tap on a thing waiting for a second one takes the thing now (see DOUBLE_TAP_MS).
func _take_waiting() -> void:
	if _tap_wait.is_empty():
		return
	var cell: Vector3i = _tap_wait.cell
	_tap_wait = {}
	if not game.placed.at(cell).is_empty():
		_take(cell)


## The thing at `cell` back into the bag (Protocol.PROP_TAKE); taken, its slot is chosen
## on the palette (WorkMode._on_bag_changed).
func _take(cell: Vector3i) -> void:
	game.net.request(Protocol.PROP_TAKE, [cell])


## Whether a tap on thing `e` sets the next of its kind down beside it: it is one cell big
## and the hand holds one of its kind.
func _beside_kind(e: Dictionary) -> bool:
	return e.item == chosen() and Placed.size_of(e.item) == 1 and game.character.inventory.count(e.item) > 0


## The cell beside thing `e` (one cell big) the finger at `pos` points to: the cell under the
## finger when it is not the thing's own, else the cell past the face of the thing the
## finger's ray goes in by.
func _beside(e: Dictionary, pos: Vector2) -> Vector3i:
	var hit: Dictionary = game.controls.pick(pos)
	if not hit.is_empty():
		var aim := _aim(hit, Items.get_item(chosen()))
		if aim != e.cell and game.placed.at(aim).is_empty():
			return aim
	var ray: Array = game.controls._ray(pos)
	return e.cell + face_in(Vector3(e.cell), ray[0], ray[1])


## The face of the unit cube at `corner` a ray from `from` along `dir` goes in by, as the
## step out of it (up when it misses).
static func face_in(corner: Vector3, from: Vector3, dir: Vector3) -> Vector3i:
	var enter := -INF
	var face := Vector3i.UP
	for axis in 3:
		if absf(dir[axis]) < 0.000001:
			continue
		var t0 := (corner[axis] - from[axis]) / dir[axis]
		var t1 := (corner[axis] + 1.0 - from[axis]) / dir[axis]
		var near := minf(t0, t1)
		if near > enter:
			enter = near
			var step := Vector3i.ZERO
			step[axis] = -1 if dir[axis] > 0.0 else 1
			face = step
	return face


## Whether stroke `s` takes its thing up into the air now: held HOLD_MS, or gone DRAG_SHARE
## of the screen.
func _lift_due(s: Dictionary) -> bool:
	if Time.get_ticks_msec() - int(s.ms) >= HOLD_MS:
		return true
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	return s.pos.distance_to(s.from) >= minf(screen.x, screen.y) * DRAG_SHARE


## A finger or the mouse held on a thing that moves, or on the ground with a thing new
## from the bag (stroke `s` of start_stroke): once held long enough (_lift_due) the thing
## hangs in the air over the free place nearest under the finger (Placed.move_spot,
## Placed.put_spot, as the server will look for it), its cells framed (red where it does
## not fit). Called every frame while held (Controls.update).
func drag(s: Dictionary) -> void:
	if s.has("put"):
		_drag_new(s)
		return
	var e: Dictionary = s.prop
	if not is_same(game.placed.at(e.cell), e):
		# Gone or changed under the finger: what was held up drops back (update).
		return
	if not s.moved:
		if not _lift_due(s):
			return
		s.moved = true
		_dragged = e
		changed.emit()
	var on_it: Variant = game.controls.on_plane(s.pos, e.cell, Vector3i.UP)
	if on_it == null:
		return
	var corner: Vector3i = on_it - s.grab
	var shown := [corner, s.turn]
	if s.shown == shown:
		return
	s.shown = shown
	var turn: int = s.turn
	if Placed.is_light(e):
		s.to = game.placed.light_move_spot(game.character, e, corner)
		var cell: Vector3i = s.to if s.to != null else corner
		game.props.hold_at(e, cell)
		game.cursor.show_boxes([cell] if s.to != null else [], [] if s.to != null else [cell])
		return
	s.to = game.placed.move_spot(game.character, e, corner, turn)
	var at: Vector3i = s.to if s.to != null else corner
	game.props.hold_at(e, at, turn)
	_frame(e.item, at, turn, s.to != null)


## A thing new from the bag held (stroke `s` with "put"): see drag.
func _drag_new(s: Dictionary) -> void:
	if not s.up:
		if not _lift_due(s):
			return
		s.up = true
		changed.emit()
	# The place under the finger, while it is on the screen.
	var hit: Dictionary = game.controls.pick(s.pos) if game.get_viewport().get_visible_rect().has_point(s.pos) else {}
	if not hit.is_empty():
		s.aim = _aim(hit, Items.get_item(s.put))
	var shown := [s.aim, s.turn]
	if s.shown == shown:
		return
	s.shown = shown
	var found: Array = game.placed.put_spot(game.character, s.put, s.aim, game.world.size_y, s.turn, s.kept)
	s.spot = found[0]
	var at: Vector3i = s.spot if s.spot != null else s.aim
	game.props.hold_new(s.put, at, found[1])
	_frame(s.put, at, found[1], s.spot != null)


## Frames the cells thing `id` turned `turn` takes from the north-west cell `at`: light
## where it fits, red where not.
func _frame(id: String, at: Vector3i, turn: int, fits: bool) -> void:
	var cells: Array = []
	for o: Vector3i in game.placed.cells_of({"item": id, "cell": Vector3i.ZERO, "turn": turn}):
		cells.append(at + o)
	if fits:
		game.cursor.show_boxes(cells, [])
	else:
		game.cursor.show_boxes([], cells)


## The finger or the mouse let go (stroke `s`). A thing new from the bag is set down where
## it hung, or where tapped (Protocol.PROP_PUT_AT). A thing set down and held up is moved
## where it hung (Protocol.PROP_MOVE; it drops back when it cannot go there); only tapped,
## it waits for a second tap (DOUBLE_TAP_MS) and then goes back into the bag.
func release(s: Dictionary) -> void:
	s.held = false
	if s.has("put"):
		var was_up: bool = s.up
		s.up = false
		game.props.drop_new()
		game.cursor.show_boxes([], [])
		game.land.expect_post(s.put)
		game.net.request(Protocol.PROP_PUT_AT, [s.put, s.aim, s.turn, true] if s.kept else [s.put, s.aim, s.turn])
		if was_up:
			changed.emit()
		return
	var e: Dictionary = s.prop
	_dragged = {}
	if not s.moved:
		if Placed.is_light(e):
			_take(e.cell)
			return
		_tap_wait = {"cell": e.cell, "ms": Time.get_ticks_msec()}
		return
	changed.emit()
	game.cursor.show_boxes([], [])
	if not is_same(game.placed.at(e.cell), e):
		# Changed while it was held (written, filled): its model drops back.
		game.props.settle(e)
		return
	var turn: int = s.turn
	if s.to == null or s.to == e.cell and turn == int(e.get("turn", 0)):
		game.props.settle(e)
		return
	game.net.request(Protocol.PROP_MOVE, [e.cell, s.to, turn]).then(func(moved: Variant) -> void:
		if not (moved is bool and moved) and game.placed.at(e.cell) == e:
			game.props.settle(e))


## The cell a stroke begins at on the cell `hit` (VoxelRaycast.cast): the cell over the
## surface tapped (walls, floors and rooms stand on it, as the ghost taken off), the
## ground cell itself for flattening.
func start_cell(hit: Dictionary) -> Vector3i:
	if kind == "flatten" and not erasing:
		return hit.cell
	return hit.cell + hit.normal


## The cells stroke `s` covers now: the shape, or the box the ghost goes off.
func stroke_cells(s: Dictionary) -> Array[Vector3i]:
	var p: Vector3 = game.player.position
	if erasing:
		return Plans.erase_box(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick)
	if Plans.is_fence(chosen()):
		# A fence: one segment high and thick (Plans.draw).
		return Plans.shape(s.plan, s.first, s.last, 1, Vector2(p.x, p.z), 1) if s.plan in ["line", "square"] else []
	return Plans.shape(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick, form_of(s.first, s.last))


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
			game.character.nag("plan_big", "[the_blueprint_is_too_big]")
			return
		var sorted := _sorted(s, cells)
		if not sorted.blocked.is_empty():
			game.hud.toast("[a_blueprint_cant_be_drawn]")
		elif not sorted.hanging.is_empty():
			game.hud.toast("[uneven_ground_nothing_under_the]")
	game.net.request(Protocol.PLAN, [s.plan, s.first, s.last, height, thick, erasing, form_of(s.first, s.last)])


func _sorted(s: Dictionary, cells: Array[Vector3i]) -> Dictionary:
	var block := Mat.index(Items.get_item(chosen()).get("place", ""))
	return game.plans.sort(game.actions, game.character, s.plan, s.first, cells, block,
		form_of(s.first, s.last) & 3 == WorldData.FORM_UPPER)
