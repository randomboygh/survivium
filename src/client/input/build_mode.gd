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
## bag holds one; a single tap takes it once the double tap's time is over. A thing new from the bag
## shows at once where the finger or the mouse presses, follows it while held, and is set
## down where it is let go (the user's picks, 2026-11-26), turned as Placed.put_spot finds
## best (a door in the plane of its wall, furniture with its back to one). On a touch
## screen a thing is held FINGER_LIFT over the finger, so the finger does not hide it (no
## line drawn to it: the user's pick, 2026-11-26); a short buzz tells it is taken up
## (Vibration "lift").
## A slope or stairs drawn in one column rise away from the player; a double tap on the
## ghost of one turns it (Plans.turn_form; the panel has no turn button since 2026-11-26,
## the key Y still turns the next ones). Leaving gives the hands back what they held before.
## `game` is the Main node.

const Items := preload("res://src/shared/content/items.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const Props := preload("res://src/client/game/props.gd")

## The palette's filters: everything, blocks (Tools.use_of "place"), parts of a house
## (Items.is_interior).
const FILTERS := ["all", "blocks", "interior"]
## The shapes the shape button goes round (Plans.KINDS but flattening).
const SHAPES := ["line", "plane", "square", "cube"]
## The heights the shapes begin with.
const DEFAULT_HEIGHTS := {"line": 3, "plane": 1, "square": 3, "cube": 5}
## How many forms the form button goes round (form_index).
const FORM_COUNT := 7
## A second tap on the same thing within this many ms turns it (a double tap); a single
## tap takes it after them.
const DOUBLE_TAP_MS := 180
## A finger or the mouse held this many ms takes a thing up into the air (a thing set
## down, or one new from the bag to set down); let go sooner it was a tap.
const HOLD_MS := 280
## How far a finger or the mouse goes before a thing is taken up sooner than HOLD_MS, a
## share of the screen's shorter side.
const DRAG_SHARE := 0.025
## How far over the finger a thing is held on a touch screen, in UI pixels at the size of
## the touch controls (HudLayout.touch_px: a phone's shorter side is 400 of them, so 40 are
## about 0.7 cm; the user's picks, 2026-11-26: a little under 1.3 cm, then less than 1 cm).
## A mouse points at the place itself.
const FINGER_LIFT := 40.0
## A second tap on the ghost of a slope or stairs within this many ms of the first turns
## them (Plans.turn_form); a single tap there draws nothing.
const GHOST_TAP_MS := 400
## How many cells a door or a window held up into a wall is drawn out of it, toward its
## front (out_of_wall): in the wall the blocks it will cut would hide it.
const WALL_OUT := 1.15
## How far round the player the palette counts what the blueprint needs (need): its ghost
## cells and things within reach of drawing (Plans.PLAN_REACH; the user's pick, 2026-11-26),
## counted again when it changes or the player has gone NEED_STEP cells, at most every
## CHECK_TIME.
const NEED_STEP := 4

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
## stairs), kept with the player, and the quarter turns of a one-column stroke from the
## way it rises by itself: away from the player, so a ramp or stairs drawn ahead go up
## from where they stand (the key Y turns them, back to 0 each time the mode is entered;
## a double tap on the ghost turns one drawn). `band`: the slopes and stairs drawn as a
## band one block thick along the flight, not filled down to the ground (Plans.BAND).
var form := 0
var band := false
var turns := 0
## The first tap on the ghost of a slope or stairs waiting for a second one: {"cell",
## "ms"}, {} for none (see GHOST_TAP_MS).
var _ghost_wait := {}
## A tap on a thing that moves waiting to see whether a second one comes: {"cell", "ms"},
## {} for none (see DOUBLE_TAP_MS).
var _tap_wait := {}
## The turn the player last gave a thing of each kind by a double tap, by item id: the
## next ones are set down turned so while the bag holds one (then it is forgotten).
var kept_turns := {}
## The thing dragged now (see drag), {} for none; the ghost thing of the blueprint dragged.
var _dragged := {}
var _dragged_ghost := {}
## What the blueprint near needs, item id -> how many (need), the cell it was counted from,
## whether the blueprint changed since, and the blueprint watched.
var _need := {}
var _need_from := Vector3i.ZERO
var _need_due := true
var _need_clock := 0.0
var _need_of = null


func to_dict() -> Dictionary:
	return {"kind": kind, "heights": heights.duplicate(), "thick": thick, "filter": filter, "form": form, "band": band}


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
	band = form != 0 and bool(d.get("band", false))


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


## What the blueprint near needs (need) first, the most needed first, the bag's ones and
## the ones it has none of (shown dimmed with what is short; the user's pick, 2026-11-26),
## then the rest of the bag's items.
func palette() -> Array[String]:
	var bag := super()
	var needed: Array = []
	for id: String in _need:
		if _in_palette(id):
			needed.append(id)
	needed.sort_custom(func(x: String, y: String) -> bool:
		return _need[x] > _need[y] if _need[x] != _need[y] else x < y)
	var out: Array[String] = []
	for id: String in needed:
		out.append(id)
	for id in bag:
		if not _need.has(id):
			out.append(id)
	return out


func _show(shown: bool) -> void:
	game.hud.show_build(shown)


## A thing dragged is set down, one new from the bag held up goes.
func _left() -> void:
	_take_waiting()
	_ghost_wait = {}
	game.props.drop_new()
	if not _dragged.is_empty():
		game.props.settle(_dragged)
		_dragged = {}


## Enters the mode with item `id` chosen (or chooses it, already in it).
func enter(id: String) -> void:
	if game.farm != null and game.farm.on:
		game.farm.leave()
	if not on:
		turns = 0
	_begin()
	choose(id)


## Item `id` of the palette into the hand in use.
func choose(id: String) -> void:
	if game.character.inventory.count(id) <= 0:
		# Shown only for what the blueprint needs: there is none to take in hand.
		game.character.nag("no_block", Lang.line("[not_in_the_bag]", [Items.title(id)]))
		return
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


## The form button: the next form round (a cube, a ramp, an upturned ramp, stairs, each
## of the three filled and then as a band).
func next_form() -> void:
	var i := (form_index() + 1) % FORM_COUNT
	set_form(0 if i == 0 else (i - 1) % 3 + 1, i > 3)


## The place of the form chosen in the form button's round: a cube 0, the filled ones
## 1..3, the bands 4..6.
func form_index() -> int:
	return 0 if form == 0 else form + (3 if band else 0)


## The form of the blocks drawn (a WorldData.FORM_*), as a band (`as_band`) or filled.
func set_form(f: int, as_band := false) -> void:
	form = clampi(f, 0, 3)
	band = form != 0 and as_band
	changed.emit()


## Turns the slopes and stairs drawn a quarter more.
func turn() -> void:
	turns = (turns + 1) % 4
	changed.emit()


## Whether the shape drawn now takes slopes and stairs (a line, a plane or a square,
## drawn as a flight of them: Plans.flight); a room is of cubes.
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
	return form | ((side + turns) % 4) << 2 | (Plans.BAND if band else 0)


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


## How many changes of the player's blueprint can be undone and redone (the server's
## PlanHistory, Protocol.PLAN_HISTORY): the bar's ↶ ↷ are dimmed at 0.
var undos := 0
var redos := 0


## The server told how many changes can be undone and redone.
func take_history(u: int, r: int) -> void:
	undos = maxi(u, 0)
	redos = maxi(r, 0)
	changed.emit()


## Undoes the last change of the blueprint (↶, Ctrl+Z; PlanHistory.undo).
func undo() -> void:
	if undos > 0:
		game.net.request(Protocol.PLAN_UNDO, [])


## Does the last change undone again (↷, Ctrl+Y or Ctrl+Shift+Z).
func redo() -> void:
	if redos > 0:
		game.net.request(Protocol.PLAN_REDO, [])


## Takes the ghost off near the player.
func clear() -> void:
	game.net.request(Protocol.PLAN_CLEAR, [])
	auto = false
	changed.emit()


## The action button: down builds the blueprint until its last cell, a second press stops.
func toggle_auto() -> void:
	if auto:
		auto = false
	elif game.plans.cells.size() == game.farm.marks() and game.plans.things.is_empty():
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
	if not _dragged_ghost.is_empty() and not is_same(game.controls.dragging().get("ghost_thing"), _dragged_ghost):
		game.cursor.show_boxes([], [])
		game.plan_view.things.settle(_dragged_ghost)
		_dragged_ghost = {}
	if not _dragged.is_empty() and not is_same(game.controls.dragging().get("prop"), _dragged):
		# Held up with no finger or button on it any more (its stroke went another way):
		# it drops back where it stands, never left hanging in the air.
		game.cursor.show_boxes([], [])
		game.props.settle(_dragged)
		_dragged = {}
	_count_need(delta)
	if not on or not auto:
		return
	_check_clock -= delta
	if _check_clock <= 0.0:
		_check_clock = CHECK_TIME
		if game.plans.cells.size() == game.farm.marks() and game.plans.things.is_empty():
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


## What the blueprint within PLAN_REACH of the player needs, item id -> how many: one block
## of its item for each ghost cell (a slope or stairs too; digging out takes none), one
## thing for each ghost thing. The palette shows it beside what the bag has.
func need() -> Dictionary:
	return _need


## Whether the bag holds less of item `id` than the blueprint near needs (`need`): blocks
## are never short when building is free, things always come from the bag.
func short_of(id: String) -> bool:
	if game.rules.free_build and not Items.is_interior(id):
		return false
	return int(_need.get(id, 0)) > game.character.inventory.count(id)


## Counts the blueprint near again (need) when it changed or the player went NEED_STEP
## cells, at most every CHECK_TIME while the mode is on; the bar is told when it differs.
func _count_need(delta: float) -> void:
	if not on:
		return
	if _need_of != game.plans:
		_need_of = game.plans
		_need_of.changed.connect(_on_plans_changed)
		_need_of.thing_changed.connect(_on_plans_changed)
		_need_due = true
	_need_clock -= delta
	if _need_clock > 0.0:
		return
	var at := Vector3i((game.player.position / Plans.CELL).floor())
	if not _need_due and maxi(absi(at.x - _need_from.x), maxi(absi(at.y - _need_from.y), absi(at.z - _need_from.z))) < NEED_STEP:
		return
	_need_clock = CHECK_TIME
	_need_due = false
	_need_from = at
	var now := count_need(game.plans, game.player.position / Plans.CELL)
	if now != _need:
		_need = now
		changed.emit()


func _on_plans_changed(_a = null, _b = null) -> void:
	_need_due = true


## What blueprint `plans` needs within PLAN_REACH of point `p` (in cells), item id -> how
## many (see need).
static func count_need(plans, p: Vector3) -> Dictionary:
	var out := {}
	var r := float(Plans.PLAN_REACH)
	for c: Vector3i in plans.cells:
		var item: String = plans.cells[c]
		if item == Plans.CUT or Plans.is_mark(item):
			continue
		if absf(c.y - p.y) <= r and Vector2(c.x + 0.5 - p.x, c.z + 0.5 - p.z).length() <= r:
			out[item] = int(out.get(item, 0)) + 1
	for t: Dictionary in plans.things:
		var c: Vector3i = t.cell
		if absf(c.y - p.y) <= r and Vector2(c.x + 0.5 - p.x, c.z + 0.5 - p.z).length() <= r:
			out[t.item] = int(out.get(t.item, 0)) + 1
	return out


## Whether the bag holds a block for some ghost cell (or building is free), or a thing for
## a ghost thing (taken from the bag whatever the rules).
func _has_blocks() -> bool:
	var inv = game.character.inventory
	for t: Dictionary in game.plans.things:
		if inv.count(t.item) > 0:
			return true
	if game.rules.free_build:
		return game.plans.cells.size() > game.farm.marks()
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
			"from": pos, "ms": Time.get_ticks_msec(), "up": false, "aim": _beside(near, pos), "face": -1,
			"turn": kept_turns.get(chosen(), game.props.view_turn()), "kept": kept_turns.has(chosen()),
			"spot": null, "shown": null}
	if target.has("prop") and Placed.is_light(target.prop) and not erasing:
		# A light (a torch, a candle) set down is handled as furniture: held, it is carried to
		# another cell with its flame; a double tap turns it; a single tap takes it.
		var lit: Dictionary = target.prop
		if not _tap_wait.is_empty() and _tap_wait.cell == lit.cell:
			_tap_wait = {}
			turn_thing(lit)
			return {}
		_take_waiting()
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "prop": lit,
			"from": pos, "ms": Time.get_ticks_msec(), "moved": false, "to": null, "corner": null,
			"turn": int(lit.get("turn", 0)), "shown": null, "grab": Vector3i.ZERO}
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
			"turn": int(e.get("turn", 0)), "shown": null, "grab": _grab(e, pos), "aim": e.cell, "face": -1}
	var ghost_thing: Dictionary = {} if erasing else game.controls.ghost_thing_at(pos)
	if not ghost_thing.is_empty():
		# A ghost thing of the blueprint is handled as a thing set down: held, it is carried
		# (PLAN_THING_MOVE); a double tap turns it; a single tap takes it off the blueprint.
		if not _tap_wait.is_empty() and _tap_wait.cell == ghost_thing.cell and _tap_wait.get("ghost", false):
			_tap_wait = {}
			turn_ghost(ghost_thing)
			return {}
		_take_waiting()
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "ghost_thing": ghost_thing,
			"from": pos, "ms": Time.get_ticks_msec(), "moved": false, "to": null, "turn": int(ghost_thing.turn),
			"shown": null, "grab": _grab(ghost_thing, pos), "aim": ghost_thing.cell, "face": -1}
	var hit: Dictionary = game.controls.pick(pos)
	if not erasing and not hit.is_empty() and game.world.is_cracked(hit.cell.x, hit.cell.y, hit.cell.z):
		# A cracked block (building decay) tapped is mended, free, with a swing of the tool
		# in the hand (decision 6A); once whole, a tap on it builds on as ever.
		game.controls.mend(hit.cell)
		return {}
	if not Plans.drawn_with(chosen()) and not erasing:
		# A thing shows at once over the place pressed (on a touch screen over the finger,
		# _aimed), follows the finger while held, and is set down where it is let go (drag,
		# release); a tap sets it down there at once. An empty hand (the last one set down)
		# does nothing.
		if item.get("prop", "none") == "none":
			return {}
		var aimed := _aimed(pos, _by_blueprint(chosen()))
		if aimed.is_empty():
			return {}
		return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "put": chosen(),
			"from": pos, "ms": Time.get_ticks_msec(), "up": false, "aim": _aim(aimed, item), "face": face_of(aimed),
			"turn": kept_turns.get(chosen(), game.props.view_turn()), "kept": kept_turns.has(chosen()),
			"spot": null, "shown": null}
	# The ghost under the finger, when it is nearer than the cell tapped: where a stroke that
	# erases begins; the ghost of a slope or stairs tapped twice is turned.
	var ghost: Variant = game.controls.ghost_at(pos)
	var on_slope: bool = not erasing and ghost != null and game.plans.formed_at(ghost)
	if on_slope and _second_ghost_tap(ghost):
		game.net.request(Protocol.PLAN_TURN, [ghost])
		return {}
	if hit.is_empty() and not on_slope:
		return {}
	var first: Vector3i = ghost if erasing and ghost != null or hit.is_empty() else start_cell(hit)
	var s := {"button": button, "dig": false, "pos": pos, "held": true, "pending": false, "plan": kind,
		"first": first, "last": first, "normal": Vector3i.UP, "from": pos}
	if on_slope:
		# Let go where it was pressed, it was a tap on the ghost: nothing is drawn, and a
		# second tap soon turns it (end_stroke).
		s.ghost = ghost
	return s


## Whether a tap on the ghost column at `cell` is the second of a double tap on it (the
## first waits in `_ghost_wait`, GHOST_TAP_MS); the wait is over either way.
func _second_ghost_tap(cell: Vector3i) -> bool:
	if _ghost_wait.is_empty():
		return false
	var second: bool = Time.get_ticks_msec() - int(_ghost_wait.ms) <= GHOST_TAP_MS \
		and game.plans.column_of(cell).has(_ghost_wait.cell)
	_ghost_wait = {}
	return second


## Whether stroke `s` is still a tap on the ghost of a slope or stairs (start_stroke): it
## began on one and the finger has not gone a little way (its first and last cells may
## still differ by one: the cell tapped and the one on the plane under it are found
## apart, Controls._run_stroke).
func _ghost_tap(s: Dictionary) -> bool:
	return s.has("ghost") and s.pos.distance_to(s.get("from", s.pos)) < _slop()


## What a thing new from the bag is aimed at for a finger or the mouse at screen point
## `pos` (VoxelRaycast.cast's hit): on a touch screen the place FINGER_LIFT over the finger
## (_lifted), so the finger does not hide the thing, or the place under it where there the
## ray finds nothing; under the mouse. With `planned` the blueprint's ghost blocks are met
## as blocks (Controls.pick_planned: a ghost thing goes onto, against or into them).
func _aimed(pos: Vector2, planned := false) -> Dictionary:
	var at := _lifted(pos)
	var hit: Dictionary = game.controls.pick_planned(at) if planned else game.controls.pick(at)
	if hit.is_empty() and at != pos:
		hit = game.controls.pick_planned(pos) if planned else game.controls.pick(pos)
	return hit


## Whether thing `id` new from the bag goes into the blueprint as a ghost thing, built after
## its blocks (Plans.put_thing): the setting «Вещи из сумки» (Settings `build_things`, by the
## blueprint unless set to at once; the user's picks, 2026-11-26, 1А, 2А), for a thing with a
## model of its own (Props.ghostly; a campfire is set down at once).
func _by_blueprint(id: String) -> bool:
	return int(game.settings.values.get("build_things", 0)) == 0 and Props.ghostly(id)


## Screen point `pos` of a finger moved FINGER_LIFT up (not past the screen's top) on a
## touch screen, `pos` itself for the mouse.
func _lifted(pos: Vector2) -> Vector2:
	if not game.controls.touch:
		return pos
	return Vector2(pos.x, maxf(0.0, pos.y - game.hud.touch_px(FINGER_LIFT)))


## The side (Placed.SIDES index) the face of hit `hit` (VoxelRaycast.cast) looks toward: a
## wall's face, which a door or a window set into it lies along (Placed.plane_turn); -1 for
## a top or a bottom.
static func face_of(hit: Dictionary) -> int:
	var n: Vector3i = hit.get("normal", Vector3i.UP)
	return Placed.SIDES.find(n) if n.y == 0 else -1


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


## Ghost thing `t` of the blueprint turned where it stands (a double tap on it): a quarter,
## a door, a window or a hatch the other way round (Plans.move_thing).
func turn_ghost(t: Dictionary) -> void:
	var turned := (int(t.turn) + (2 if Placed.is_opening(t.item) else 1)) % 4
	if not Placed.is_opening(t.item):
		kept_turns[t.item] = turned
	game.net.request(Protocol.PLAN_THING_MOVE, [t.cell, t.cell, turned, -1])


## Thing `e` turned a quarter where it stands (a double tap on it), and the next of its
## kind set down turned so while the bag holds one (kept_turns); a door, a window or a
## hatch turned the other way round in its wall, its front to the other side.
func turn_thing(e: Dictionary) -> void:
	if Placed.is_opening(e.item):
		game.net.request(Protocol.PROP_MOVE, [e.cell, e.cell, (int(e.get("turn", 0)) + 2) % 4])
		return
	var turned := (int(e.get("turn", 0)) + 1) % 4
	kept_turns[e.item] = turned
	game.net.request(Protocol.PROP_MOVE, [e.cell, e.cell, turned])


## The tap on a thing waiting for a second one takes the thing now (see DOUBLE_TAP_MS); on
## a ghost thing, takes it off the blueprint.
func _take_waiting() -> void:
	if _tap_wait.is_empty():
		return
	var cell: Vector3i = _tap_wait.cell
	var ghost: bool = _tap_wait.get("ghost", false)
	_tap_wait = {}
	if ghost:
		if not game.plans.thing_at(cell).is_empty():
			game.net.request(Protocol.PLAN_THING_TAKE, [cell])
	elif not game.placed.at(cell).is_empty():
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
	return Time.get_ticks_msec() - int(s.ms) >= HOLD_MS or s.pos.distance_to(s.from) >= _slop()


## How far a finger or the mouse goes before a press is a stroke and no longer a tap:
## DRAG_SHARE of the screen's shorter side.
func _slop() -> float:
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	return minf(screen.x, screen.y) * DRAG_SHARE


## A finger or the mouse held on a thing that moves, or on the ground with a thing new
## from the bag (stroke `s` of start_stroke): once held long enough (_lift_due) the thing
## hangs in the air over the free place nearest under the finger (Placed.move_spot,
## Placed.put_spot, as the server will look for it), its cells framed (red where it does
## not fit). Called every frame while held (Controls.update).
func drag(s: Dictionary) -> void:
	if s.has("put"):
		_drag_new(s)
		return
	if s.has("ghost_thing"):
		_drag_ghost(s)
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
		# A short buzz: it is taken up (the user's pick, 2026-11-26).
		Vibration.play(game, "lift")
		changed.emit()
	if Placed.is_opening(e.item):
		_drag_opening(s, e)
		return
	var on_it: Variant = game.controls.on_plane(_lifted(s.pos), e.cell, Vector3i.UP)
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
		game.props.hold_at(e, cell, s.turn)
		game.cursor.show_boxes([cell] if s.to != null else [], [] if s.to != null else [cell])
		return
	s.to = game.placed.move_spot(game.character, e, corner, turn)
	var at: Vector3i = s.to if s.to != null else corner
	game.props.hold_at(e, at, turn)
	_frame(e.item, at, turn, s.to != null)


## A thing new from the bag pressed (stroke `s` with "put"): it shows at once (the user's
## pick, 2026-11-26), over the place pressed till the finger goes a little way (_slop), then
## over the place under the finger (over it on a touch screen, _aimed) while that is on the
## screen; held HOLD_MS or carried, a short buzz tells it is taken up. See drag.
func _drag_new(s: Dictionary) -> void:
	if not s.up:
		s.up = true
		changed.emit()
	if not s.get("lifted", false) and _lift_due(s):
		s.lifted = true
		Vibration.play(game, "lift")
	if not s.get("led", false) and s.pos.distance_to(s.from) >= _slop():
		s.led = true
	# Into the blueprint (_by_blueprint) it is seen and looked for as a ghost thing.
	var ghost := _by_blueprint(s.put)
	var hit: Dictionary = _aimed(s.pos, ghost) if s.get("led", false) and game.get_viewport().get_visible_rect().has_point(s.pos) else {}
	if not hit.is_empty():
		s.aim = _aim(hit, Items.get_item(s.put))
		s.face = face_of(hit)
	var shown := [s.aim, s.turn, s.get("face", -1), ghost]
	if s.shown == shown:
		return
	s.shown = shown
	var found: Array
	if ghost:
		found = game.placed.ghost_spot(game.character, game.plans, s.put, s.aim, s.turn, s.kept, s.get("face", -1))
	else:
		found = game.placed.put_spot(game.character, s.put, s.aim, game.world.size_y, s.turn, s.kept, s.get("face", -1))
	s.spot = found[0]
	var at: Vector3i = s.spot if s.spot != null else s.aim
	game.props.hold_new(s.put, at, found[1], out_of_wall(s.put, at, found[1]) if s.spot != null else Vector3.ZERO,
		game.plan_view.things.material() if ghost else null)
	_frame(s.put, at, found[1], s.spot != null)


## A ghost thing of the blueprint held (stroke `s` with "ghost_thing"): once held long enough
## (_lift_due) it follows the finger as a thing set down does (drag), its place looked for in
## the world as the blueprint will stand (Placed.ghost_move_spot); a door, a window or a hatch
## along the wall under the finger, ghost walls too. Let go, it moves there (release).
func _drag_ghost(s: Dictionary) -> void:
	var t: Dictionary = s.ghost_thing
	if not is_same(game.plans.thing_at(t.cell), t):
		return
	if not s.moved:
		if not _lift_due(s):
			return
		s.moved = true
		_dragged_ghost = t
		Vibration.play(game, "lift")
		changed.emit()
	var at: Vector3i
	var face := -1
	if Placed.is_opening(t.item):
		var hit: Dictionary = _aimed(s.pos, true) if game.get_viewport().get_visible_rect().has_point(s.pos) else {}
		if hit.is_empty():
			return
		at = _aim(hit, Items.get_item(t.item))
		face = face_of(hit)
	else:
		var on_it: Variant = game.controls.on_plane(_lifted(s.pos), t.cell, Vector3i.UP)
		if on_it == null:
			return
		at = on_it - s.grab
	var shown := [at, s.turn, face]
	if s.shown == shown:
		return
	s.shown = shown
	s.aim = at
	s.face = face
	var found: Array = game.placed.ghost_move_spot(game.character, game.plans, t, at, s.turn, face)
	s.to = found[0]
	s.found_turn = found[1]
	var spot: Vector3i = s.to if s.to != null else at
	game.plan_view.things.hold(t, spot, found[1], out_of_wall(t.item, spot, found[1]) if s.to != null else Vector3.ZERO)
	_frame(t.item, spot, found[1], s.to != null)


## A door, a window or a hatch held up (stroke `s` of opening `e`): it follows the wall
## under the finger (over it on a touch screen, _aimed) as a new one from the bag does,
## turned into the wall's plane (Placed.opening_spot, as the server will look for it), and
## hangs before the blocks it would cut (out_of_wall); let go, it moves there and its old
## place is walled up again (release, Placed.move).
func _drag_opening(s: Dictionary, e: Dictionary) -> void:
	var hit: Dictionary = _aimed(s.pos) if game.get_viewport().get_visible_rect().has_point(s.pos) else {}
	if hit.is_empty():
		return
	var aim := _aim(hit, Items.get_item(e.item))
	var face := face_of(hit)
	var shown := [aim, face]
	if s.shown == shown:
		return
	s.shown = shown
	s.aim = aim
	s.face = face
	var found: Array = game.placed.opening_spot(game.character, e, aim, face)
	s.to = found[0]
	s.turn = found[1]
	var at: Vector3i = s.to if s.to != null else aim
	game.props.hold_at(e, at, s.turn, out_of_wall(e.item, at, s.turn) if s.to != null else Vector3.ZERO)
	_frame(e.item, at, s.turn, s.to != null)


## Where a door or a window `id` held up at north-west cell `at` turned `turn` is drawn
## from there, in cells: where it goes into blocks (an opening to cut into a wall) they
## would hide it, so it hangs WALL_OUT before them, toward its front (Placed.front_of: the
## side it was pressed from); else where it goes (Props.hold_new).
func out_of_wall(id: String, at: Vector3i, turn: int) -> Vector3:
	var item := Items.get_item(id)
	if not (item.get("door", false) or item.get("window", false)) or item.get("hatch", false):
		return Vector3.ZERO
	for o: Vector3i in game.placed.cells_of({"item": id, "cell": Vector3i.ZERO, "turn": turn}):
		var c: Vector3i = at + o
		if game.world.is_solid(c.x, c.y, c.z):
			var f := Placed.front_of({"turn": turn})
			return Vector3(f.x, 0.0, f.y) * WALL_OUT
	return Vector3.ZERO


## Shows where thing `id` turned `turn` would go from the north-west cell `at`: where it
## fits only its own model held there (user 2026-11-23: no see-through body over a
## thing, it is set down as it is), where not its cells red.
func _frame(id: String, at: Vector3i, turn: int, fits: bool) -> void:
	if fits:
		game.cursor.show_boxes([], [])
		return
	var cells: Array = []
	for o: Vector3i in game.placed.cells_of({"item": id, "cell": Vector3i.ZERO, "turn": turn}):
		cells.append(at + o)
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
		if _by_blueprint(s.put):
			# Into the blueprint, built after its blocks (the user's picks, 2026-11-26, 2А: a tap too).
			game.net.request(Protocol.PLAN_THING, [s.put, s.aim, s.turn, s.kept, int(s.get("face", -1))])
		else:
			game.land.expect_post(s.put)
			game.net.request(Protocol.PROP_PUT_AT, [s.put, s.aim, s.turn, s.kept, int(s.get("face", -1))])
		if was_up:
			changed.emit()
		return
	if s.has("ghost_thing"):
		_release_ghost(s)
		return
	var e: Dictionary = s.prop
	_dragged = {}
	if not s.moved:
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
	# A door, a window or a hatch goes by the wall's cell it was held over (_drag_opening).
	var args := [e.cell, s.aim, turn, int(s.face)] if Placed.is_opening(e.item) else [e.cell, s.to, turn]
	game.net.request(Protocol.PROP_MOVE, args).then(func(moved: Variant) -> void:
		if not (moved is bool and moved) and game.placed.at(e.cell) == e:
			game.props.settle(e))


## A ghost thing of the blueprint let go (stroke `s`, see _drag_ghost): carried, it is moved
## where it hung (Protocol.PLAN_THING_MOVE; it drops back when it cannot go there); only
## tapped, it waits for a second tap (DOUBLE_TAP_MS) and then is taken off the blueprint.
func _release_ghost(s: Dictionary) -> void:
	var t: Dictionary = s.ghost_thing
	_dragged_ghost = {}
	if not s.moved:
		_tap_wait = {"cell": t.cell, "ms": Time.get_ticks_msec(), "ghost": true}
		return
	changed.emit()
	game.cursor.show_boxes([], [])
	game.plan_view.things.settle(t)
	if s.to == null or not is_same(game.plans.thing_at(t.cell), t):
		return
	var turn: int = s.get("found_turn", s.turn)
	if s.to == t.cell and turn == int(t.turn):
		return
	# A door, a window or a hatch goes by the wall's cell it was held over, as a placed one.
	var to: Vector3i = s.aim if Placed.is_opening(t.item) else s.to
	game.net.request(Protocol.PLAN_THING_MOVE, [t.cell, to, turn, int(s.face)])


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
	if _ghost_tap(s):
		# Pressed on the ghost of a slope or stairs: a tap there draws nothing.
		game.cursor.show_boxes([], [])
		return
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
	if _ghost_tap(s):
		# A tap on the ghost of a slope or stairs: nothing drawn; a second tap soon turns it.
		game.cursor.show_boxes([], [])
		_ghost_wait = {"cell": s.ghost, "ms": Time.get_ticks_msec()}
		return
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
		Plans.hangs_by_shape(form_of(s.first, s.last)))
