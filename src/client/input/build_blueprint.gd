extends "res://src/client/input/build_need.gd"
## The build mode's strokes of the blueprint (see build_mode.gd): the cells a stroke of a
## line, a plane, a square or a cube takes and shows, a stroke replacing the material, and
## the double tap that turns the ghost of a slope or stairs.

## A stroke of replacing (`replacing`) pressed at `pos`: it begins at the block (or the
## ghost block, when nearer) under the finger and takes the box of the shape drawn from
## there (a plane for «выровнять»); none without a block in hand.
func _replace_stroke(button: int, pos: Vector2) -> Dictionary:
	if Mat.index(Items.get_item(chosen()).get("place", "")) < 0:
		game.character.nag("plan_block", "[choose_a_block_for_the]")
		return {}
	var hit: Dictionary = game.controls.pick(pos)
	var ghost: Variant = game.controls.ghost_at(pos)
	if hit.is_empty() and ghost == null:
		return {}
	var first: Vector3i = ghost if ghost != null else hit.cell
	return {"button": button, "dig": false, "pos": pos, "held": true, "pending": false,
		"plan": "plane" if kind == "flatten" else kind, "first": first, "last": first, "normal": Vector3i.UP, "from": pos}

## The cells stroke `s` of replacing would mark (Plans.replace, as the server finds them):
## the blocks built and the ghost blocks of another material in its box.
func replaced_cells(s: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var item := chosen()
	var block := Mat.index(Items.get_item(item).get("place", ""))
	var p: Vector3 = game.player.position
	for c in Plans.erase_box(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick):
		var was: String = game.plans.cells.get(c, "")
		if was == item or Plans.is_mark(was) or Plans.is_earth(was) or was != "" and not Items.get_item(was).has("place"):
			continue
		if was != "" or game.plans.replaceable(game.actions, c, block):
			out.append(c)
	return out

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

## How far a finger or the mouse goes before a press is a stroke and no longer a tap:
## DRAG_SHARE of the screen's shorter side.
func _slop() -> float:
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	return minf(screen.x, screen.y) * DRAG_SHARE

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
	if erasing or replacing:
		return Plans.erase_box(s.plan, s.first, s.last, height, Vector2(p.x, p.z), thick, levels() and not replacing)
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
	if replacing:
		# The box lit, the blocks to be replaced in it as the figure.
		game.cursor.show_boxes(replaced_cells(s), [], cells)
		return
	if erasing:
		var gone: Array[Vector3i] = []
		var figure := Plans.erase_box(s.plan, s.first, s.last, height, Vector2(game.player.position.x,
			game.player.position.z), thick)
		var ys := Vector2i(figure[0].y, figure[-1].y) if not figure.is_empty() else Vector2i.ZERO
		for c in cells:
			# Over and under the figure only the ghost of its earth goes (Plans.draw).
			if game.plans.cells.has(c) and (c.y >= ys.x and c.y <= ys.y or Plans.is_earth(game.plans.cells[c])):
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
	# The soil a dip under the figure is filled with shows as the figure does.
	for c: Vector3i in sorted.get("fill", []):
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
	if replacing:
		if replaced_cells(s).is_empty():
			game.hud.toast("[nothing_to_replace_here_tap_a]")
		game.net.request(Protocol.PLAN, [s.plan, s.first, s.last, height, thick, false, 0, false, true]).then(_laid)
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
	game.net.request(Protocol.PLAN, [s.plan, s.first, s.last, height, thick, erasing, form_of(s.first, s.last),
		levels()]).then(_laid)

## A figure of the blueprint drawn, taken off or marked (Plans.draw: how many cells), or a
## ghost thing set in it (true): felt as a light tick (Vibration "lay").
func _laid(done: Variant) -> void:
	if done is bool and done or done is int and done > 0:
		Vibration.play(game, "lay")

## Whether a figure drawn levels the uneven ground under it (Plans.earthwork): the setting
## «Земля под фигурой» (Settings `build_level`, levelled unless set to as it is; the user's
## picks, 2026-11-26).
func levels() -> bool:
	return int(game.settings.values.get("build_level", 0)) == 0

## The cells of stroke `s` sorted (Plans.sort) with its earthwork (Plans.earthwork):
## {"fit", "blocked", "hanging", "fill" (the soil under it)}.
func _sorted(s: Dictionary, cells: Array[Vector3i]) -> Dictionary:
	var block := Mat.index(Items.get_item(chosen()).get("place", ""))
	var form := form_of(s.first, s.last)
	var work := {}
	if levels() and block >= 0:
		work = game.plans.earthwork(game.actions, game.character, s.plan, s.first, s.last, cells, form)
	var out: Dictionary = game.plans.sort(game.actions, game.character, s.plan, s.first, cells, block,
		Plans.hangs_by_shape(form), work)
	out.fill = work.get("fill", [])
	return out
