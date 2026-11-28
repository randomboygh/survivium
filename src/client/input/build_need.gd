extends "res://src/client/input/build_palette.gd"
## The build mode's count of what the blueprint near the player needs (see build_mode.gd):
## what the palette shows short (the ghosts drawn red), and the action button that builds
## the blueprint by itself (`auto`).

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
	return int(_need.get(id, 0)) > int(_have.get(id, game.character.inventory.count(id)))

## The world materials of the ghost blocks the bag has too little of (short_of), for
## PlanBlocks to tint; none out of the mode.
func short_blocks() -> Array[int]:
	var out: Array[int] = []
	if not on:
		return out
	for id: String in _need:
		var m := Mat.index(Items.get_item(id).get("place", ""))
		if m > 0 and short_of(id):
			out.append(m)
	return out

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
	if _need_bag != game.character.inventory:
		_need_bag = game.character.inventory
		_need_bag.changed.connect(_on_plans_changed)
		_need_due = true
	_need_clock -= delta
	_need_settle -= delta
	if _need_clock > 0.0 or _need_due and _need_settle > 0.0:
		return
	var at := Vector3i((game.player.position / Plans.CELL).floor())
	if not _need_due and maxi(absi(at.x - _need_from.x), maxi(absi(at.y - _need_from.y), absi(at.z - _need_from.z))) < NEED_STEP:
		return
	_need_clock = CHECK_TIME
	_need_due = false
	_need_from = at
	var now := count_need(game.plans, game.player.position / Plans.CELL)
	var have := {}
	for id: String in now:
		have[id] = game.character.inventory.count(id)
	if now != _need or have != _have:
		_need = now
		_have = have
		changed.emit()

## The blueprint or the bag changed: counted again once nothing more came for NEED_SETTLE.
func _on_plans_changed(_a = null, _b = null) -> void:
	_need_due = true
	_need_settle = NEED_SETTLE

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
