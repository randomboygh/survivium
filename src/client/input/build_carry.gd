extends "res://src/client/input/build_aim.gd"
## The build mode's things carried (see build_mode.gd): a thing new from the bag, one set
## down, the ghost thing of the blueprint and a door or a window followed by the finger,
## turned by a second finger, shown only where it fits (doors only in walls), and set
## down where they are let go.

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
		game.props.hold_at(e, cell, s.turn)
		game.cursor.show_boxes([cell] if s.to != null else [], [] if s.to != null else [cell])
		return
	s.to = game.placed.move_spot(game.character, e, corner, turn)
	if s.to == null and shown_where_fits(e.item):
		_hold_home(s)
		return
	var at: Vector3i = s.to if s.to != null else corner
	game.props.hold_at(e, at, turn)
	_frame(e.item, at, turn, s.to != null)

## A touch or a drag of a finger while stroke `s` carries a thing (Controls.input): a
## second finger pressed over the world and let go soon where it went down turns the thing
## a quarter clockwise; the two fingers twisted turn it a quarter each TWIST_STEP, clockwise
## or back as they turn. Where the thing takes its turn by itself (a door or a window in a
## wall, a chair's back to a wall: Placed.put_spot) that turn wins: the finger turns it only
## in the open (the user's pick, 2026-11-26).
func second_finger(event: InputEvent, s: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		if event.pressed and event.index != 0 and _second.is_empty() and not game.hud.covers(event.position):
			var at := {0: s.pos, event.index: event.position}
			_second = {"index": event.index, "from": event.position, "ms": now, "at": at,
				"angle": (event.position - s.pos).angle(), "twisted": false}
		elif not event.pressed and not _second.is_empty() and event.index == _second.index:
			if not _second.twisted and now - int(_second.ms) <= SECOND_TAP_MS \
					and event.position.distance_to(_second.from) < _slop() * 2.0:
				turn_carried(s, 1)
			_second = {}
		return
	if _second.is_empty() or not (event.index == 0 or event.index == _second.index):
		return
	_second.at[event.index] = event.position
	var angle: float = (_second.at[_second.index] - _second.at[0]).angle()
	var d := wrapf(angle - float(_second.angle), -PI, PI)
	# The screen's y goes down: a growing angle turns clockwise as seen, as a quarter does seen
	# from above (Placed: `turn` clockwise).
	if absf(d) >= TWIST_STEP:
		var way := 1 if d > 0.0 else -1
		_second.angle = wrapf(float(_second.angle) + way * TWIST_STEP, -PI, PI)
		_second.twisted = true
		turn_carried(s, way)

## Turns the thing stroke `s` carries `way` quarters (1 clockwise seen from above), as the
## next of its kind is set down (kept_turns); a light tick tells it.
func turn_carried(s: Dictionary, way: int) -> void:
	if s.has("prop") and not s.moved or s.has("ghost_thing") and not s.moved or s.has("put") and not s.up:
		return
	s.turn = (int(s.turn) + way + 4) % 4
	var item: String = s.put if s.has("put") else (s.prop.item if s.has("prop") else s.ghost_thing.item)
	if s.has("put"):
		s.kept = true
	kept_turns[item] = s.turn
	Vibration.play(game, "lift")

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
	var found := _spot_new(s, ghost)
	s.spot = found[0]
	if s.spot == null and shown_where_fits(s.put):
		# A door or a window is not shown where it cannot go (user 2026-11-27).
		game.props.drop_new()
		game.plan_view.things.hold_hole([])
		game.cursor.show_boxes([], [])
		return
	var at: Vector3i = s.spot if s.spot != null else s.aim
	game.props.hold_new(s.put, at, found[1], game.plan_view.things.material() if ghost else null)
	game.plan_view.things.hold_hole(cut_cells(s.put, at, found[1]) if s.spot != null else [])
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
		var on_it: Variant = game.controls.on_plane(s.pos, t.cell, Vector3i.UP)
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
	s.to = found[0] if Plans.within_reach(game.character, at) else null
	s.found_turn = found[1]
	if s.to == null and shown_where_fits(t.item):
		_hold_home(s)
		return
	var spot: Vector3i = s.to if s.to != null else at
	game.plan_view.things.hold(t, spot, found[1])
	game.plan_view.things.hold_hole(cut_cells(t.item, spot, found[1]) if s.to != null else [], t)
	_frame(t.item, spot, found[1], s.to != null)

## A door, a window or a hatch held up (stroke `s` of opening `e`): it follows the wall
## under the finger (over it on a touch screen, _aimed) as a new one from the bag does,
## turned into the wall's plane (Placed.opening_spot, as the server will look for it), and
## stands in the opening it would cut (cut_cells); let go, it moves there and its old
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
	s.to = found[0] if Placed.in_reach(game.character, aim) else null
	s.turn = found[1]
	if s.to == null:
		_hold_home(s)
		return
	var at: Vector3i = s.to
	game.props.hold_at(e, at, s.turn)
	game.plan_view.things.hold_hole(cut_cells(e.item, at, s.turn))
	game.cursor.show_boxes([], [])

## The blocks door or window `id` at north-west cell `at` turned `turn` will cut out of a
## wall: it stands there, in the middle of the wall where it will be, and they are drawn
## cut while it is shown (PlanThings.hold_hole, holes; user 2026-11-26), else they would
## hide it. None for another thing or a hatch.
func cut_cells(id: String, at: Vector3i, turn: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var item := Items.get_item(id)
	if not (item.get("door", false) or item.get("window", false)) or item.get("hatch", false):
		return out
	for c: Vector3i in game.placed.volume_of(id, at, turn):
		if game.world.is_solid(c.x, c.y, c.z):
			out.append(c)
	return out

## Where thing `s.put` new from the bag held by stroke `s` goes, as the server will look for
## it: into the blueprint (`ghost`, Placed.ghost_spot, within Plans.within_reach) or set down
## at once (Placed.put_spot, within Placed.in_reach). [north-west cell, null where it cannot
## go; turn].
func _spot_new(s: Dictionary, ghost: bool) -> Array:
	var found: Array
	if ghost:
		found = game.placed.ghost_spot(game.character, game.plans, s.put, s.aim, s.turn, s.kept, s.get("face", -1))
		if not Plans.within_reach(game.character, s.aim):
			found[0] = null
	else:
		found = game.placed.put_spot(game.character, s.put, s.aim, game.world.size_y, s.turn, s.kept, s.get("face", -1))
		if not Placed.in_reach(game.character, s.aim):
			found[0] = null
	return found

## Whether thing `id` held up is shown only where it can go (user 2026-11-27: no door shown
## where none can stand; let go there, nothing happens and nothing is said): a door, a window
## or a hatch, a wicket or a gate. Another thing shows its cells red there (_frame).
static func shown_where_fits(id: String) -> bool:
	var item := Items.get_item(id)
	return item.get("door", false) or item.get("window", false)

## The thing stroke `s` carries (a door, a window: shown_where_fits) held over no place it can
## go: shown held up in its own place, as it will stay when let go there (release).
func _hold_home(s: Dictionary) -> void:
	game.cursor.show_boxes([], [])
	if s.has("ghost_thing"):
		var t: Dictionary = s.ghost_thing
		game.plan_view.things.hold(t, t.cell, int(t.turn))
		game.plan_view.things.hold_hole(cut_cells(t.item, t.cell, int(t.turn)), t)
		return
	var e: Dictionary = s.prop
	game.props.hold_at(e, e.cell, int(e.get("turn", 0)))
	game.plan_view.things.hold_hole([])

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
	_second = {}
	if s.has("put"):
		var was_up: bool = s.up
		s.up = false
		game.props.drop_new()
		game.cursor.show_boxes([], [])
		var ghost := _by_blueprint(s.put)
		# Where it cannot go (no room, out of reach) nothing is asked and nothing said (user
		# 2026-11-27: no [no_room_here]); a tap let go before it was looked for is looked for now.
		var spot: Variant = s.spot if s.shown != null else _spot_new(s, ghost)[0]
		if spot != null and ghost:
			# Into the blueprint, built after its blocks (the user's picks, 2026-11-26, 2А: a tap too).
			game.net.request(Protocol.PLAN_THING, [s.put, s.aim, s.turn, s.kept, int(s.get("face", -1))]).then(_laid)
		elif spot != null:
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
