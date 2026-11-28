extends "res://src/client/input/build_carry.gd"
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
## best (a door in the plane of its wall, furniture with its back to one). It is aimed
## right under the finger, raised only a little over the surface (Props.LIFT; the lift over
## the finger was taken off, user 2026-11-26); a short buzz tells it is taken up
## (Vibration "lift").
## A slope or stairs drawn in one column rise away from the player; a double tap on the
## ghost of one turns it (Plans.turn_form; the panel has no turn button since 2026-11-26,
## the key Y still turns the next ones). Leaving gives the hands back what they held before.
## `game` is the Main node.
##
## The code is a chain of parts, each calling only itself and the parts before it:
## build_palette.gd (constants, shared state, the palette, shapes and forms, undo) ←
## build_need.gd (what the blueprint needs, `auto`) ← build_blueprint.gd (the strokes of
## the blueprint) ← build_aim.gd (where a thing is aimed, taps on things) ←
## build_carry.gd (things carried, turned by a second finger, set down) ← this file
## (leaving, update, the start of a stroke). Callers preload this file.


## A thing dragged is set down, one new from the bag held up goes.
func _left() -> void:
	picking = false
	replacing = false
	_take_waiting()
	_ghost_wait = {}
	game.props.drop_new()
	if not _dragged.is_empty():
		game.props.settle(_dragged)
		_dragged = {}

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

## A tap at screen point `pos` (mouse `button`): a part of a house there is taken back
## into the bag; else a stroke of the blueprint begins (the dictionary Controls keeps
## while it is held, {} for none): from the ground cell tapped for a plane or a box (a
## floor takes the place of the top ground cell), from the cell over it for the walls.
func start_stroke(button: int, pos: Vector2) -> Dictionary:
	if picking:
		pick_at(pos)
		return {}
	if replacing:
		return _replace_stroke(button, pos)
	var target: Dictionary = game.controls.placed_at(pos)
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
