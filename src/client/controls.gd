extends RefCounted
## Input: keys, mouse and touch, and what they do to the world (plan/design/ui.md,
## "Работа с ячейками"; plan/design/character.md, "Взаимодействие с миром"). Each hand
## holds any item of the bag or nothing (`hands`), and one of them is in use (`active`):
## a tool digs, chops, mows and gathers (Tools) as far as it reaches, bare hands (or
## anything that is no tool) cut grass, dig soft ground slowly and gather, a block is
## placed with the brush (Tools.BRUSHES: squares 1, 2 or 3 cells across, two cells one
## above the other, a line) within Tools.PLACE_REACH, seeds and bushes are planted, a
## workbench or a campfire is set down, food is eaten. With a mouse the left button
## works with the left hand and the right button with the right one; a tap on a touch
## screen, the action button and F work with the hand in use. Both keep working while
## the button or finger is held: digging swings again at the cell under it as fast as
## the tool swings, placing paints the brush along the plane the stroke began in (a
## floor, a wall), every cell on the way. The action button works in front of the
## player (see act_in_front). What is dug or cut falls on the ground for Gathering to
## take up; placing takes the block from the bag (Character), unless the playtest
## switch for free building is on. Also opening the bag, moving the cut and the
## playtest keys. Touch and mouse switch the interface layout. `game` is the Main node
## that owns the scene.

const Mat := preload("res://src/shared/materials.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const Trees := preload("res://src/shared/trees.gd")
const Items := preload("res://src/shared/items.gd")
const Tools := preload("res://src/shared/tools.gd")
const Foliage := preload("res://src/client/foliage.gd")

const CELL := WorldData.CELL
## How often the hint under the mouse pointer is updated, in seconds.
const TIP_INTERVAL := 0.1
## Seconds between two placings of a stroke, and of the action button (slower, so a
## bridge grows a cell at a time while walking).
const PLACE_SWING := 0.1
const FRONT_PLACE_SWING := 0.25
## How long the cursor frame stays after a touch, in seconds.
const CURSOR_TIME := 0.6

var game
var touch := false
var jump_held := false
var show_help := true
var tip_clock := 0.0
var mouse_pos := Vector2(-1, -1)
var last_touch_ms := -100000
## Touch indices now on the screen.
var fingers := {}
## What the left and the right hand hold: item ids ("" for nothing, a block by its
## item), and the hand in use (0 left, 1 right). Saved with the player.
var hands: Array[String] = ["", ""]
var active := 0
## The right hand's brush, an index into Tools.BRUSHES.
var brush := 0
## Whether the action button is held.
var action_held := false
## Damage each tree being chopped has taken, by its trunk's column (not saved).
var chops := {}
## A button or finger held on the world: {"button", "hand", "dig", "pos", "held", "pending"
## (not worked yet), "normal", "first", "last" (the plane and the first and last cells
## of a placing stroke) and "axis" (the way a line goes, -1 until it has moved)}.
var _stroke := {}
## Seconds until the hands can swing again.
var _cooldown := 0.0
var _cursor_clock := 0.0


func _init(g) -> void:
	game = g
	touch = DisplayServer.is_touchscreen_available()
	show_help = not touch
	hands[1] = Items.placed_by[Mat.PLACEABLE[0]]


func to_dict() -> Dictionary:
	return {"hands": hands.duplicate(), "active": active, "brush": brush}


func from_dict(d: Dictionary) -> void:
	var held_ids: Variant = d.get("hands")
	if held_ids is Array and held_ids.size() == 2:
		for h in 2:
			var id: Variant = held_ids[h]
			hands[h] = id if id is String and (id == "" or Items.has(id)) else ""
	active = clampi(int(d.get("active", 0)), 0, 1)
	brush = clampi(int(d.get("brush", 0)), 0, Tools.BRUSHES.size() - 1)


## Touch and mouse switch the layout: the joystick and action buttons show after a
## touch, key hints and the pointer hint after the mouse moves. Browsers report a
## moving finger as mouse motion too, so motion counts as a mouse only while no finger
## is down and a while after the last touch.
func input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
		set_touch(true)
		last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventScreenDrag:
		set_touch(true)
		last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if fingers.is_empty() and Time.get_ticks_msec() - last_touch_ms > 1000:
			set_touch(false)
		mouse_pos = event.position
	# A stroke goes on wherever the button is let go, over the interface too.
	if event is InputEventMouseButton and not event.pressed and not _stroke.is_empty() \
			and event.button_index == _stroke.button:
		_stroke.held = false


func unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key >= KEY_1 and key < KEY_1 + Mat.PLACEABLE.size():
			select_block(key - KEY_1)
		match key:
			KEY_Q, KEY_PAGEDOWN:
				game.chunks.shift_cut(-1)
			KEY_E, KEY_PAGEUP:
				game.chunks.shift_cut(1)
			KEY_R:
				game.chunks.reset_view_level()
			KEY_I, KEY_TAB:
				game.hud.toggle_bag()
			KEY_V:
				cycle_tool()
			KEY_C:
				cycle_brush()
			KEY_Z:
				game.sky.next_season()
			KEY_X:
				game.settings.set_raining(not game.sky.raining)
			KEY_T:
				var s = game.settings
				s.set_time_boost(1.0 if s.time_boost > 1.0 else s.FAST_FORWARD)
			KEY_G:
				game.settings.set_value("shadows", not game.settings.values.shadows)
			KEY_H:
				game.settings.set_value("show_help", not show_help)
	elif event is InputEventMouseMotion:
		if not _stroke.is_empty():
			_stroke.pos = event.position
	elif event is InputEventMouseButton and event.pressed:
		var n: int = Mat.PLACEABLE.size()
		# With a mouse each button is a hand; a tap on a touch screen uses the hand in use.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				tap(active if touch else 0, event.position, MOUSE_BUTTON_LEFT)
			MOUSE_BUTTON_RIGHT:
				tap(1, event.position, MOUSE_BUTTON_RIGHT)
			MOUSE_BUTTON_WHEEL_UP:
				select_block((_block_index() - 1 + n) % n)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_block((_block_index() + 1) % n)


## A tap or a click at `pos` with hand `hand` (pressed with mouse `button`, which may
## stay held): something to gather or open there first (a thing on the ground or set
## on it with any hand, a bush with a tool or bare hands), else what the hand's item is
## for (see Tools.use_of).
func tap(hand: int, pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	if hand != active:
		set_active(hand)
	var use := use_of()
	var target: Dictionary = game.gathering.target_at(pos)
	if not target.is_empty() and (use in ["tool", "hand"] or not target.has("bush")):
		if _cooldown <= 0.0 and game.gathering.gather(target):
			_cooldown = tool_record().swing
		return
	match use:
		"place":
			_start_stroke(button, pos, false)
		"plant", "sow":
			var hit := pick(pos)
			if not hit.is_empty() and _cooldown <= 0.0 and game.gathering.plant_at(held(), hit.cell):
				_cooldown = FRONT_PLACE_SWING
		"prop":
			game.props.put_from_bag(held())
		"eat":
			_eat_held()
		_:
			_start_stroke(button, pos, true)


## Runs the held strokes and the action button for a frame; called while playing.
func update(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_cursor_clock = maxf(0.0, _cursor_clock - delta)
	_check_hands()
	if not _stroke.is_empty():
		if _stroke.held and not Input.is_mouse_button_pressed(_stroke.button):
			_stroke.held = false
		if _cooldown <= 0.0 and (_stroke.held or _stroke.pending):
			_run_stroke()
		if touch:
			_show_preview(_stroke.pos, _stroke.dig)
			_cursor_clock = CURSOR_TIME
		if not _stroke.held and not _stroke.pending:
			_stroke = {}
	elif action_held or Input.is_physical_key_pressed(KEY_F):
		if _cooldown <= 0.0:
			act_in_front()
		game.cursor.show_cells(_front_preview(), true)
		_cursor_clock = CURSOR_TIME
	if touch and _cursor_clock <= 0.0:
		game.cursor.show_cells([], true)


func set_touch(on: bool) -> void:
	if on != touch:
		touch = on
		game.hud.set_touch(on)
		if on:
			game.hud.show_tip(Vector2.ZERO, "")
			if game.cursor != null:
				game.cursor.show_cells([], true)


## Makes hand `hand` (0 left, 1 right) the hand in use.
func set_active(hand: int) -> void:
	active = hand
	game.hud.refresh_hands()


## The item in hand `hand` (the hand in use for -1), "" for nothing.
func held(hand := -1) -> String:
	return hands[active if hand < 0 else hand]


## The record of what hand `hand` holds as a tool (see Tools.of): bare hands for
## anything that is no tool.
func tool_record(hand := -1) -> Dictionary:
	return Tools.of(held(hand))


## What the item in hand `hand` is used for (see Tools.use_of).
func use_of(hand := -1) -> String:
	return Tools.use_of(held(hand))


## Puts item `id` ("" for nothing) into hand `hand` (the hand in use for -1), which is
## then the hand in use; a tool the bag holds one of leaves the other hand.
func put_in_hand(id: String, hand := -1, say := true) -> void:
	var h := active if hand < 0 else hand
	if id != "" and hands[1 - h] == id and Tools.is_tool_item(id) and game.character.inventory.count(id) < 2:
		hands[1 - h] = ""
	hands[h] = id
	active = h
	game.hud.refresh_hands()
	game.hud.bag.refresh()
	if say:
		game.hud.toast("%s: %s" % ["Левая рука" if h == 0 else "Правая рука", Items.title(id) if id != "" else "пусто"])


## Takes item `id` from the bag into the hand in use (the bag's «В руку»).
func hold(id: String) -> void:
	put_in_hand(id)


## Takes block `i` of the hotbar into the hand in use.
func select_block(i: int) -> void:
	put_in_hand(Items.placed_by[Mat.PLACEABLE[i]], -1, false)


## The hotbar block held in the hand in use, else in the other hand; -1 for none.
func _block_index(hand := -1) -> int:
	var h := active if hand < 0 else hand
	for id in [hands[h], hands[1 - h]]:
		var m := Mat.index(Items.get_item(id).get("place", "")) if id != "" else -1
		if m >= 0 and Mat.PLACEABLE.has(m):
			return Mat.PLACEABLE.find(m)
	return -1


## A tool that has left the bag (thrown away, broken) leaves the hand; a tool the bag
## holds one of is in one hand only.
func _check_hands() -> void:
	var inv = game.character.inventory
	var changed := false
	for h in 2:
		if hands[h] != "" and Tools.is_tool_item(hands[h]) and inv.count(hands[h]) == 0:
			hands[h] = ""
			changed = true
	if hands[0] != "" and hands[0] == hands[1] and Tools.is_tool_item(hands[0]) and inv.count(hands[0]) < 2:
		hands[1 - active] = ""
		changed = true
	if changed:
		game.hud.refresh_hands()


## The next tool in the bag into the hand in use, after the last one nothing again.
func cycle_tool() -> void:
	var ids: Array = [""]
	for s in game.character.inventory.slots:
		if s != null and Tools.is_tool_item(s[0]) and not ids.has(s[0]):
			ids.append(s[0])
	var at := ids.find(held())
	put_in_hand(ids[(at + 1) % ids.size()])


## The next brush for placing blocks.
func cycle_brush() -> void:
	brush = (brush + 1) % Tools.BRUSHES.size()
	game.hud.refresh_hands()
	game.hud.toast("Кисть: %s" % brush_record().title)


## The brush blocks are placed with (one of Tools.BRUSHES).
func brush_record() -> Dictionary:
	return Tools.BRUSHES[brush]


## What the action button does with the hand in use, for its label.
func action_name() -> String:
	match use_of():
		"place":
			return "Ставить"
		"plant", "sow":
			return "Сажать"
		"prop":
			return "Поставить"
		"eat":
			return "Съесть"
		"hand":
			return "Собрать"
	match tool_record().tool:
		"axe":
			return "Рубить"
		"sword":
			return "Бить"
		"scythe":
			return "Косить"
	return "Копать"


## Eats one of the food in the hand in use from the bag.
func _eat_held() -> void:
	if _cooldown > 0.0:
		return
	var slots: Array = game.character.inventory.slots
	for i in slots.size():
		if slots[i] != null and slots[i][0] == held():
			game.character.eat(i)
			_cooldown = 0.5
			return
	game.character.nag("no_food", "В сумке нет: %s" % Items.title(held()))


## Whether the jump key or the jump button is held.
func jump() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) or jump_held


func read_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if touch:
		v += game.hud.stick.value
	return v


## The cell the player's feet are in.
func feet() -> Vector3i:
	var p: Vector3 = game.player.position
	return Vector3i(floori(p.x / CELL), game.player.level(), floori(p.z / CELL))


## The column step the player faces (one of 8 ways).
func step() -> Vector2i:
	var turn: float = SpriteSheet.COMPASS.find(game.player.facing) / 8.0 * TAU
	return Tools.step_of(Vector2(-sin(turn), cos(turn)))


## The view ray through a screen point, in cells: [origin, direction].
func _ray(screen_pos: Vector2) -> Array:
	var view = game.view
	var vp_pos: Vector2 = (screen_pos - view.container.global_position) / float(view.container.stretch_shrink)
	var center: Vector2 = Vector2(view.camera.global_position.x, view.camera.global_position.z)
	var ray: Array = PixelView.view_ray(center, vp_pos - Vector2(view.image_size) * 0.5, game.world.size_y * CELL + 1.0)
	return [ray[0] / CELL, ray[1]]


## The cell under a screen point, as VoxelRaycast.cast returns it (empty if none).
func pick(screen_pos: Vector2) -> Dictionary:
	if not game.ready_to_play:
		return {}
	var ray := _ray(screen_pos)
	var max_level: int = mini(game.chunks.cut_level, game.world.size_y - 1)
	return VoxelRaycast.cast(game.world, ray[0], ray[1], 500.0, max_level)


## The cell under a screen point in the layer of cells across `normal` that holds
## `ref`, or null when the view does not cross it.
func _on_plane(screen_pos: Vector2, ref: Vector3i, normal: Vector3i) -> Variant:
	var ray := _ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	var axis := 0 if normal.x != 0 else (1 if normal.y != 0 else 2)
	if absf(d[axis]) < 0.001:
		return null
	var p := o + d * ((ref[axis] + 0.5 - o[axis]) / d[axis])
	var cell := Vector3i(p.floor())
	cell[axis] = ref[axis]
	return cell


func _start_stroke(button: int, pos: Vector2, dig: bool) -> void:
	_stroke = {"button": button, "dig": dig, "pos": pos, "held": true, "pending": true, "normal": null,
		"first": Vector3i.ZERO, "last": Vector3i.ZERO, "axis": -1}
	if _cooldown <= 0.0:
		_run_stroke()


func _run_stroke() -> void:
	_stroke.pending = false
	if _stroke.dig:
		var hit := pick(_stroke.pos)
		if not hit.is_empty():
			dig_at(hit.cell, hit.normal)
		return
	if _stroke.normal == null:
		var hit := pick(_stroke.pos)
		if hit.is_empty():
			return
		var normal: Vector3i = hit.normal
		var cell: Vector3i = hit.cell + normal
		_stroke.normal = normal
		_stroke.first = cell
		_stroke.last = cell
		place_at(cell, normal)
		return
	var on: Variant = _on_plane(_stroke.pos, _stroke.last, _stroke.normal)
	if on == null:
		return
	var to: Vector3i = _on_line(on)
	# A finger moves faster than a cell a frame: every cell on the way gets the brush.
	var from: Vector3i = _stroke.last
	var steps: int = maxi(maxi(absi(to.x - from.x), absi(to.y - from.y)), absi(to.z - from.z))
	for i in range(1, steps + 1):
		var cell := Vector3i((Vector3(from) + Vector3(to - from) * (float(i) / steps)).round())
		_stroke.last = cell
		place_at(cell, _stroke.normal)


## A placing stroke with the line brush keeps to the way it first moved from its first
## cell; other brushes go anywhere in the plane.
func _on_line(cell: Vector3i) -> Vector3i:
	if not brush_record().get("line", false):
		return cell
	var d: Vector3i = cell - _stroke.first
	if _stroke.axis < 0:
		if d == Vector3i.ZERO:
			return cell
		var a := Vector3(absi(d.x), absi(d.y), absi(d.z))
		_stroke.axis = 0 if a.x >= a.y and a.x >= a.z else (1 if a.y >= a.z else 2)
	var out: Vector3i = _stroke.first
	out[_stroke.axis] = cell[_stroke.axis]
	return out


## Works at `cell`, tapped on its face `normal`, with the hand in use: an axe chops the
## tree whose trunk or crown it is, bare hands gather from that tree, hands, a sword or a
## scythe cut the grass on top of it, else the tool digs as many cells around it as it
## takes in a swing. True if anything was done.
func dig_at(cell: Vector3i, normal: Vector3i) -> bool:
	var world = game.world
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if cell.y == 0 or m == Mat.AIR:
		return false
	var t := tool_record()
	if too_far(cell, t.reach):
		game.character.nag("far", "Слишком далеко")
		return false
	var tree: Variant = tree_of(cell)
	if tree != null:
		if t.tool == "axe":
			return chop(trunk_cell(tree))
		if t.tool == "hand":
			if game.gathering.gather({"tree": tree}):
				_cooldown = t.swing
				return true
			return false
		if m == Mat.LOG:
			game.character.nag("tool", "Дерево рубят топором")
			return false
	if Tools.mows(t) and can_mow(cell):
		return _mow(_mow_targets([cell], t))
	if not Tools.can_dig(t, m):
		game.character.nag("tool", Tools.why_not(t, m))
		return false
	return _dig(_dig_targets(Tools.area_cells(cell, normal), t), Tools.swing_time(t, m))


## The first cells of `order` the tool `t` can dig, as many as it takes in a swing
## (`n` when given).
func _dig_targets(order: Array[Vector3i], t: Dictionary, n := -1) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in order:
		if out.size() >= (t.area if n < 0 else n):
			break
		var m: int = game.world.get_cell(c.x, c.y, c.z)
		if c.y > 0 and m != Mat.AIR and Tools.can_dig(t, m) and tree_of(c) == null and not too_far(c, t.reach):
			out.append(c)
	return out


## Whether the grass on top of `cell` can be cut: a material with a top to cut (see
## Tools.mown), open to the air above, with no bush on it.
func can_mow(cell: Vector3i) -> bool:
	var world = game.world
	var up := cell + Vector3i.UP
	return Tools.mown(world.get_cell(cell.x, cell.y, cell.z)) >= 0 and world.get_cell(up.x, up.y, up.z) == Mat.AIR \
		and not world.bushes.has(up)


## The cells tool `t` cuts the grass of when it swings at the first of `order` it can
## cut: that one, and for a scythe the ones beside it in an arc in front of the body.
func _mow_targets(order: Array[Vector3i], t: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in order:
		if can_mow(c) and not too_far(c, t.reach):
			for s in (Tools.sweep(c, step()) if t.area > 1 else [c]):
				if out.size() < t.area and can_mow(s) and not too_far(s, t.reach):
					out.append(s)
			break
	return out


## Cuts the grass on top of `cells` in one swing of the tool in use (see Gathering.mow).
func _mow(cells: Array[Vector3i]) -> bool:
	if cells.is_empty() or not game.gathering.mow(cells):
		return false
	_cooldown = tool_record().swing
	game.workshop.use_tool()
	return true


## Digs `cells` in one swing of `swing` seconds; what they give (their item, now and
## then their bonus) falls under them.
func _dig(cells: Array[Vector3i], swing: float) -> bool:
	if cells.is_empty() or not game.character.act("dig"):
		return false
	var world = game.world
	var keys := {}
	for c in cells:
		var was: int = world.get_cell(c.x, c.y, c.z)
		world.set_cell(c.x, c.y, c.z, Mat.AIR)
		game.chunks.on_cell_changed(c)
		if game.settings.free_build:
			continue
		var at := floor_under(c)
		var rec: Dictionary = Mat.RECORDS[was]
		for id in [Items.dug[was], rec.bonus if randf() < rec.bonus_chance else ""]:
			if id != "":
				world.heap_drop(id, at, 1, randf() * TAU)
				keys[WorldData.chunk_key(c.x, c.z)] = true
	for key in keys:
		game.props.show_drops(key)
	_cooldown = swing
	game.workshop.use_tool()
	return true


## Where a thing let go in `cell` comes to lie: on the ground under it, in world units.
func floor_under(cell: Vector3i) -> Vector3:
	var world = game.world
	var y := cell.y
	while y > 1 and y > cell.y - 64 and not world.is_solid(cell.x, y - 1, cell.z):
		y -= 1
	var h: float = world.ground_height(cell.x + 0.5, cell.z + 0.5)
	var at := Vector3(cell.x + 0.5, h if h >= y - 1 and h <= y else float(y), cell.z + 0.5)
	return at * CELL


func _is_trunk(cell: Vector3i) -> bool:
	return game.world.get_cell(cell.x, cell.y, cell.z) == Mat.LOG and game.world.trees.has(Vector2i(cell.x, cell.z))


## The trunk's column of the tree that `cell` is part of: a log of its trunk, or leaves
## of its crown (whose nearest trunk it is); null for anything else.
func tree_of(cell: Vector3i) -> Variant:
	var world = game.world
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if m == Mat.LOG:
		return Vector2i(cell.x, cell.z) if world.trees.has(Vector2i(cell.x, cell.z)) else null
	if m != Mat.LEAVES:
		return null
	var best: Variant = null
	var best_d := Trees.TREE_REACH * Trees.TREE_REACH * 2 + 1
	var r := Trees.TREE_REACH
	for tz in range(cell.z - r, cell.z + r + 1):
		for tx in range(cell.x - r, cell.x + r + 1):
			var at := Vector2i(tx, tz)
			var d := (at - Vector2i(cell.x, cell.z)).length_squared()
			if d < best_d and world.trees.has(at) and world.log_col(tx, tz) != 0:
				best_d = d
				best = at
	return best


## The cell of tree `col`'s trunk an axe hits: the lowest log at the player's level or
## above, else the lowest.
func trunk_cell(col: Vector2i) -> Vector3i:
	var logs: int = game.world.log_col(col.x, col.y)
	var from := maxi(0, feet().y - 1)
	var above := logs & ~((1 << from) - 1)
	var bits := above if above != 0 else logs
	return Vector3i(col.x, WorldData.level_of(bits & -bits), col.y)


## A hit with the axe at the tree whose trunk holds `cell`; it falls when the hits add
## up to its species' `hits`. True if the axe swung.
func chop(cell: Vector3i) -> bool:
	var t := tool_record()
	if t.tool != "axe":
		game.character.nag("tool", "Дерево рубят топором")
		return false
	if not _is_trunk(cell) or not game.character.act("chop"):
		return false
	game.workshop.use_tool()
	var col := Vector2i(cell.x, cell.z)
	var s: Dictionary = Trees.SPECIES[game.world.trees[col]]
	chops[col] = chops.get(col, 0) + maxi(1, t.power)
	_cooldown = Tools.swing_time(t, Mat.LOG)
	if chops[col] < s.hits:
		game.hud.toast("%s: осталось ударов %d" % [s.title, ceili((s.hits - chops[col]) / float(maxi(1, t.power)))])
		return true
	chops.erase(col)
	_fell(cell)
	return true


## Places the block in the hand in use with the brush around `center`, across face
## `normal`: each cell that is free, within reach and next to something solid. Returns
## how many were placed.
func place_at(center: Vector3i, normal: Vector3i) -> int:
	var world = game.world
	var item := held()
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		return 0
	var free: bool = game.settings.free_build
	var placed := 0
	var far := false
	for cell in Tools.brush_shape(center, normal, brush_record()):
		if not _can_place(cell):
			far = far or too_far(cell, Tools.PLACE_REACH)
			continue
		if not free and game.character.inventory.count(item) == 0:
			game.character.nag("no_block", "В сумке нет: %s" % Items.title(item))
			break
		if not game.character.act("place"):
			break
		if not free:
			game.character.inventory.remove(item, 1)
		world.set_cell(cell.x, cell.y, cell.z, block)
		game.chunks.on_cell_changed(cell)
		placed += 1
	if placed > 0:
		_cooldown = PLACE_SWING
	elif far:
		game.character.nag("far", "Слишком далеко")
	return placed


func _can_place(cell: Vector3i) -> bool:
	var world = game.world
	if not world.in_bounds(cell.x, cell.y, cell.z) or cell.y > game.chunks.cut_level or too_far(cell, Tools.PLACE_REACH):
		return false
	var cur: int = world.get_cell(cell.x, cell.y, cell.z)
	if cur != Mat.AIR and cur != Mat.WATER or game.player.overlaps_cell(cell):
		return false
	for d in [Vector3i.DOWN, Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var n: Vector3i = cell + d
		if world.is_solid(n.x, n.y, n.z):
			return true
	return false


## The action button: works in front of the player with the hand in use. A block is
## placed in front (filling a hole first), seeds and bushes planted, a workbench or a
## campfire set down, food eaten. A tool or bare hands first work the nearest tree or
## bush in front that they can do something to (see Gathering.useful: an axe chops,
## hands gather, a sword knocks berries off, a shovel digs a bush out), then cut the
## grass in front (hands, sword, scythe), then dig one cell, in the order of
## Tools.front_cells.
func act_in_front() -> void:
	match use_of():
		"place":
			_place_in_front()
			return
		"plant", "sow":
			_cooldown = FRONT_PLACE_SWING if game.gathering.plant(held()) else 0.3
			return
		"prop":
			game.props.put_from_bag(held())
			_cooldown = 0.5
			return
		"eat":
			_eat_held()
			return
	var t := tool_record()
	var target := _plant_in_front()
	if not target.is_empty():
		if target.has("trunk"):
			chop(target.trunk)
		elif game.gathering.gather(target):
			_cooldown = t.swing
		else:
			_cooldown = 0.3
		return
	var work := _front_work(t)
	if work.has("mow"):
		_mow(work.mow)
		return
	if work.has("dig"):
		var c: Vector3i = work.dig[0]
		_dig(work.dig, Tools.swing_time(t, game.world.get_cell(c.x, c.y, c.z)))
		return
	var what := "рубить" if t.tool == "axe" else ("косить" if t.tool == "scythe" else "копать")
	game.character.nag("front", "Перед тобой нечего %s" % what)
	_cooldown = 0.3


## What a swing of tool `t` in front would do: {"mow": cells} (the grass first, for
## the tools that cut it), {"dig": [cell]} (one cell), or {}.
func _front_work(t: Dictionary) -> Dictionary:
	var order := _front_order(feet(), step())
	if Tools.mows(t):
		var cells := _mow_targets(order, t)
		if not cells.is_empty():
			return {"mow": cells}
	var cells := _dig_targets(order, t, 1)
	return {"dig": cells} if not cells.is_empty() else {}


func _place_in_front() -> void:
	var f := feet()
	var s := step()
	var front := f + Vector3i(s.x, 0, s.y)
	for cell in [front + Vector3i.DOWN, front, front + Vector3i.UP]:
		if _can_place(cell):
			place_at(cell, Vector3i(s.x, 0, s.y if s.x == 0 else 0))
			_cooldown = FRONT_PLACE_SWING
			return
	game.character.nag("front", "Перед тобой некуда ставить")
	_cooldown = 0.3


## The cells the action button digs, in order (Tools.front_cells); the one under the
## feet only while the player stands still, so walking does not drop them into a pit.
func _front_order(f: Vector3i, s: Vector2i) -> Array[Vector3i]:
	var cells := Tools.front_cells(f, s)
	if game.player.move_input.length() > 0.1:
		cells.pop_back()
	return cells


## The nearest tree or bush in front (Tools.sector) that the hand in use can do
## something to: {"trunk": cell} for an axe at a tree, {"tree": column} for bare hands,
## {"bush": cell}; {} for none.
func _plant_in_front() -> Dictionary:
	var world = game.world
	var f := feet()
	var t := tool_record()
	for o in Tools.sector(step()):
		var col := Vector2i(f.x + o.x, f.z + o.y)
		if world.trees.has(col) and t.tool in ["axe", "hand"]:
			var trunk := trunk_cell(col)
			if world.log_col(col.x, col.y) != 0 and absi(trunk.y - f.y) <= 2:
				if t.tool == "axe":
					return {"trunk": trunk}
				if game.gathering.useful({"tree": col}):
					return {"tree": col}
		for dy in [0, -1, 1]:
			var cell := Vector3i(col.x, f.y + dy, col.y)
			if world.bushes.has(cell) and game.gathering.useful({"bush": cell}):
				return {"bush": cell}
	return {}


## The cells the action button would work on now, for the cursor frame.
func _front_preview() -> Array[Vector3i]:
	var f := feet()
	var s := step()
	match use_of():
		"place":
			var front := f + Vector3i(s.x, 0, s.y)
			for cell in [front + Vector3i.DOWN, front, front + Vector3i.UP]:
				if _can_place(cell):
					return [cell]
			return []
		"plant", "sow":
			var spot: Variant = game.gathering.plant_spot(held())
			var cells: Array[Vector3i] = []
			if spot != null:
				cells.append(spot)
			return cells
		"prop", "eat":
			return []
	var target := _plant_in_front()
	if target.has("trunk"):
		return [target.trunk]
	if target.has("bush"):
		return [target.bush]
	if target.has("tree"):
		return [trunk_cell(target.tree)]
	var work := _front_work(tool_record())
	var out: Array[Vector3i] = []
	out.assign(work.get("mow", work.get("dig", [])))
	return out


## Frames what a tap at `screen_pos` would work on: the cells to dig, cut or fill, red
## when nothing can be done there.
func _show_preview(screen_pos: Vector2, dig: bool) -> void:
	var hit := pick(screen_pos)
	if hit.is_empty():
		game.cursor.show_cells([], true)
		return
	var cell: Vector3i = hit.cell
	if dig:
		var t := tool_record()
		var m: int = game.world.get_cell(cell.x, cell.y, cell.z)
		var near := not too_far(cell, t.reach)
		var tree: Variant = tree_of(cell)
		if tree != null and (t.tool in ["axe", "hand"] or m == Mat.LOG):
			var trunk := trunk_cell(tree)
			var ok: bool = near and (t.tool == "axe" or t.tool == "hand" and game.gathering.useful({"tree": tree}))
			game.cursor.show_cells([trunk if t.tool == "axe" else cell], ok)
			return
		if Tools.mows(t) and can_mow(cell):
			var mown := _mow_targets([cell], t)
			game.cursor.show_cells(mown if not mown.is_empty() else [cell], not mown.is_empty())
			return
		var cells := _dig_targets(Tools.area_cells(cell, hit.normal), t)
		var ok: bool = Tools.can_dig(t, m) and near and cell.y > 0
		game.cursor.show_cells(cells if ok else [cell], ok)
		return
	var normal: Vector3i = hit.normal
	if not _stroke.is_empty() and _stroke.normal != null:
		normal = _stroke.normal
		var on: Variant = _on_plane(screen_pos, _stroke.last, normal)
		if on == null:
			return
		cell = on
	else:
		cell += normal
	var cells: Array[Vector3i] = []
	for c in Tools.brush_shape(cell, normal, brush_record()):
		if _can_place(c):
			cells.append(c)
	game.cursor.show_cells(cells if not cells.is_empty() else [cell], not cells.is_empty())


## Fells the tree whose trunk holds `cell`, away from the player; false if it is no
## trunk of a tree.
func _fell(cell: Vector3i) -> bool:
	var world = game.world
	var away := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL - Vector2(game.player.position.x, game.player.position.z)
	var before := {}
	for key in world.drops:
		before[key] = world.drops[key].size()
	var gone: Array[Vector3i] = Trees.fell(world, cell, away)
	if gone.is_empty():
		return false
	# Each column once, at its lowest changed cell, is enough for the chunks, the roof
	# map and the minimap.
	var cols := {}
	for c in gone:
		var col := Vector2i(c.x, c.z)
		if not cols.has(col) or c.y < cols[col].y:
			cols[col] = c
	for col in cols:
		game.chunks.on_cell_changed(cols[col])
	for key in world.drops:
		if world.drops[key].size() != before.get(key, 0):
			game.props.show_drops(key)
	return true


## Whether `cell` is farther than `reach` cells from the player.
func too_far(cell: Vector3i, reach: int) -> bool:
	var center := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	return center.distance_to(game.player.position + Vector3(0.0, 0.5, 0.0)) > reach * CELL


## With a mouse, names the cell under the pointer and what the buttons do with it, and
## frames what the hand in use would work on.
func update_tip(delta: float) -> void:
	tip_clock += delta
	if touch or tip_clock < TIP_INTERVAL or mouse_pos.x < 0.0:
		return
	tip_clock = 0.0
	_show_preview(mouse_pos, _stroke.dig if not _stroke.is_empty() else use_of() != "place")
	var target: Dictionary = game.gathering.target_at(mouse_pos)
	if not target.is_empty():
		game.hud.show_tip(mouse_pos, game.gathering.describe(target))
		return
	var hit := pick(mouse_pos)
	if hit.is_empty():
		game.hud.show_tip(mouse_pos, "")
		return
	var cell: Vector3i = hit.cell
	var m: int = game.world.get_cell(cell.x, cell.y, cell.z)
	var lines := ["%s · уровень %d" % [Mat.NAMES[m], cell.y]]
	for h in 2:
		lines.append("%s %s" % ["ЛКМ" if h == 0 else "ПКМ", _hint(h, cell, m)])
	game.hud.show_tip(mouse_pos, "\n".join(lines))


## What hand `hand` would do at `cell` of material `m`, for the hint.
func _hint(hand: int, cell: Vector3i, m: int) -> String:
	var use := use_of(hand)
	match use:
		"place":
			return "поставить"
		"plant", "sow":
			return "посадить"
		"prop":
			return "поставить перед собой"
		"eat":
			return "съесть"
	var t := tool_record(hand)
	if too_far(cell, t.reach):
		return "далеко"
	var tree: Variant = tree_of(cell)
	if tree != null and t.tool == "axe":
		return "рубить"
	if tree != null and t.tool == "hand":
		return "наломать веток"
	if m == Mat.LOG and tree != null:
		return "рубят топором"
	if Tools.mows(t) and can_mow(cell):
		return "косить" if t.tool == "scythe" else "сорвать траву"
	if Tools.can_dig(t, m):
		var slow: bool = t.tool == "hand" and Mat.RECORDS[m].dig == "shovel"
		return "копать%s" % (" (руками медленно)" if slow else "")
	return Tools.why_not(t, m).to_lower()
