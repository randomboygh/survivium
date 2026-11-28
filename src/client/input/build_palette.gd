extends "res://src/client/input/work_mode.gd"
## The first part of the build mode (build_mode.gd is the last; callers load that one): its
## constants and the state the later parts share, the palette and what is chosen on it, the
## eyedropper, the shape, form, height and thickness drawn, undo and redo.

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
## A second tap on the ghost of a slope or stairs within this many ms of the first turns
## them (Plans.turn_form); a single tap there draws nothing.
const GHOST_TAP_MS := 400
## A thing carried is turned by a second finger (second_finger, the user's picks 2026-11-27,
## 7В): a tap of it shorter than this many ms turns it a quarter clockwise, and a twist of
## the two fingers a quarter each TWIST_STEP of the angle between them, its way.
const SECOND_TAP_MS := 300
const TWIST_STEP := PI / 4.0
## How far round the player the palette counts what the blueprint needs (need): its ghost
## cells and things within reach of drawing (Plans.PLAN_REACH; the user's pick, 2026-11-26),
## counted again when it changes or the player has gone NEED_STEP cells, at most every
## CHECK_TIME.
const NEED_STEP := 4
## How long the blueprint and the bag must stay as they are before they are counted (the news
## of a block built come apart: the cell, the bag).
const NEED_SETTLE := 0.15

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
## The second finger on the screen while a thing is carried (second_finger): its index,
## where it went down ("from") and when ("ms"), the two fingers' places ("at" by index), the
## angle between them a turn was last made at, and whether a twist has turned the thing.
var _second := {}
## The turn the player last gave a thing of each kind by a double tap, by item id: the
## next ones are set down turned so while the bag holds one (then it is forgotten).
var kept_turns := {}
## The eyedropper is on (set_picking): the next tap on the world takes what is there into
## the hand (pick_at) instead of drawing, then it goes off by itself.
var picking := false
## Strokes replace the material (next_mode, the third state of the panel's draw/erase
## button; the user's idea 6, 2026-11-26): the blocks built in the box of the shape are
## marked to be rebuilt of the block in hand (Plans.replace).
var replacing := false
## The thing dragged now (see drag), {} for none; the ghost thing of the blueprint dragged.
var _dragged := {}
var _dragged_ghost := {}
## What the blueprint near needs, item id -> how many (need), what the bag held of them then
## (short_of compares the two counted together: a block built takes one from the bag and one
## from the blueprint, and the ghosts must not blink red between the two news, user
## 2026-11-26), the cell it was counted from, whether the blueprint or the bag changed since
## (and how long ago: counted once both have settled), the blueprint and the bag watched.
var _need := {}
var _have := {}
var _need_from := Vector3i.ZERO
var _need_due := true
var _need_clock := 0.0
var _need_settle := 0.0
var _need_of = null
var _need_bag = null

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

## The panel's draw/erase/replace button: drawing → erasing → replacing → drawing.
func next_mode() -> void:
	if replacing:
		replacing = false
	elif erasing:
		erasing = false
		replacing = true
	else:
		erasing = true
	changed.emit()

func set_erasing(e: bool) -> void:
	replacing = false
	super(e)

## Turns the eyedropper on or off (the panel's button).
func set_picking(p: bool) -> void:
	picking = p
	changed.emit()

## The eyedropper (the user's picks, 2026-11-26): what the world shows at screen point `pos`
## into the hand in use, as if chosen on the palette: a thing set down or a ghost thing (and
## its turn kept for the next), else the ghost block of the blueprint nearest, else the
## block there (natural ones too, by the item that builds that material). Once something is
## taken the eyedropper goes off, and the eraser too; with nothing there to take, or none of
## it in the bag (choose's nag), it stays on for the next tap (the user's pick, 6Б).
func pick_at(pos: Vector2) -> void:
	var got := picked_at(pos)
	var id: String = got.get("item", "")
	if id == "" or not builds_with(id):
		return
	if game.character.inventory.count(id) <= 0:
		choose(id)
		return
	if got.has("turn") and not Plans.drawn_with(id):
		kept_turns[id] = int(got.turn)
	picking = false
	erasing = false
	choose(id)
	changed.emit()

## What the eyedropper finds at screen point `pos`: {"item", and "turn" for a thing}, {} for
## nothing to take.
func picked_at(pos: Vector2) -> Dictionary:
	var target: Dictionary = game.controls.placed_at(pos)
	if target.has("prop"):
		return {"item": target.prop.item, "turn": int(target.prop.get("turn", 0))}
	var thing: Dictionary = game.controls.ghost_thing_at(pos)
	if not thing.is_empty():
		return {"item": thing.item, "turn": int(thing.turn)}
	var ghost: Variant = game.controls.ghost_at(pos)
	if ghost != null:
		var planned: String = game.plans.cells.get(ghost, "")
		if planned != Plans.CUT and not Plans.is_mark(planned):
			return {"item": planned}
	var hit: Dictionary = game.controls.pick(pos)
	if hit.is_empty():
		return {}
	return {"item": block_item(game.world.get_cell(hit.cell.x, hit.cell.y, hit.cell.z))}

## The item that builds material `m`: the one placing it, else the one it gives dug (grass
## gives earth) when that builds; "" for none.
static func block_item(m: int) -> String:
	if m <= Mat.AIR or m >= Items.placed_by.size():
		return ""
	var id: String = Items.placed_by[m]
	if id == "":
		id = Items.dug[m]
	return id if builds_with(id) else ""

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
