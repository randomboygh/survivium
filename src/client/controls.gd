extends RefCounted
## Input: keys, mouse and touch, and what they do to the world (plan/design/ui.md,
## "Работа с ячейками"). The left hand holds a tool from the bag or nothing (bare hands)
## and digs, chops and gathers with it (Tools) as far as the tool reaches; the right
## hand holds a block of the hotbar and places it with a brush (Tools.BRUSHES: squares
## 1, 2 or 3 cells across, two cells one above the other, a line) within
## Tools.PLACE_REACH. Both keep working while the button or finger is held: digging
## swings again at the cell under it as fast as the tool swings, placing paints the
## brush along the plane the stroke began in (a floor, a wall), every cell on the way. The action button and F work in front of the player with the hand in use (see
## act_in_front). What is dug falls on the ground for Gathering to take up; placing
## takes the block from the bag (Character), unless the playtest switch for free
## building is on. Also opening the bag, moving the cut and the playtest keys. Touch and
## mouse switch the interface layout. `game` is the Main node that owns the scene.

const Mat := preload("res://src/shared/materials.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const Trees := preload("res://src/shared/trees.gd")
const Items := preload("res://src/shared/items.gd")
const Tools := preload("res://src/shared/tools.gd")

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
var selected := 0
var dig_mode := true
var show_help := true
var tip_clock := 0.0
var mouse_pos := Vector2(-1, -1)
var last_touch_ms := -100000
## Touch indices now on the screen.
var fingers := {}
## The item in the left hand: a tool from the bag, or "" for bare hands.
var tool := ""
## The right hand's brush, an index into Tools.BRUSHES.
var brush := 0
## Whether the action button is held.
var action_held := false
## Damage each tree being chopped has taken, by its trunk's column (not saved).
var chops := {}
## A button or finger held on the world: {"button", "dig", "pos", "held", "pending"
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
		# With a mouse each button is a hand: the left one digs, the right one places.
		# A tap on a touch screen uses the hand chosen on the hotbar.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				# A tap or a click near something to gather takes it before digging.
				var target: Dictionary = game.gathering.target_at(event.position)
				if not target.is_empty() and (dig_mode or not touch or target.has("drop")):
					if _cooldown <= 0.0 and game.gathering.gather(target):
						_cooldown = tool_record().swing
				else:
					_start_stroke(MOUSE_BUTTON_LEFT, event.position, dig_mode or not touch)
			MOUSE_BUTTON_RIGHT:
				_start_stroke(MOUSE_BUTTON_RIGHT, event.position, false)
			MOUSE_BUTTON_WHEEL_UP:
				select_block((selected - 1 + n) % n, false)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_block((selected + 1) % n, false)


## Runs the held strokes and the action button for a frame; called while playing.
func update(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_cursor_clock = maxf(0.0, _cursor_clock - delta)
	if tool != "" and game.character.inventory.count(tool) == 0:
		tool = ""
		game.hud.refresh_hands()
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


func set_dig_mode(on: bool) -> void:
	dig_mode = on
	game.hud.refresh_hands()


## Takes block `i` of the hotbar into the right hand; `use` also makes it the hand in use.
func select_block(i: int, use := true) -> void:
	selected = i
	if use:
		dig_mode = false
	game.hud.refresh_hands()


## The record of what the left hand holds (see Tools.of).
func tool_record() -> Dictionary:
	return Tools.of(tool)


## Takes item `id` (a tool in the bag, "" for nothing) into the left hand and uses it.
func hold(id: String) -> void:
	tool = id if Tools.is_tool_item(id) else ""
	dig_mode = true
	game.hud.refresh_hands()
	game.hud.bag.refresh()
	game.hud.toast("В руке: %s" % (Items.title(tool) if tool != "" else "ничего"))


## The next tool in the bag into the left hand, after the last one bare hands again.
func cycle_tool() -> void:
	var ids: Array = [""]
	for s in game.character.inventory.slots:
		if s != null and Tools.is_tool_item(s[0]) and not ids.has(s[0]):
			ids.append(s[0])
	hold(ids[(ids.find(tool) + 1) % ids.size()])


## The next brush for the right hand, which is then the hand in use.
func cycle_brush() -> void:
	brush = (brush + 1) % Tools.BRUSHES.size()
	dig_mode = false
	game.hud.refresh_hands()
	game.hud.toast("Кисть: %s" % brush_record().title)


## The right hand's brush (one of Tools.BRUSHES).
func brush_record() -> Dictionary:
	return Tools.BRUSHES[brush]


## What the action button does with the hand in use, for its label.
func action_name() -> String:
	if not dig_mode:
		return "Ставить"
	match tool_record().tool:
		"axe":
			return "Рубить"
		"sword":
			return "Бить"
	return "Копать"


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


## Digs at `cell`, tapped on its face `normal`, with the tool in the left hand: as many
## cells around it as the tool takes in a swing, or a hit at a tree whose trunk it is.
## True if anything was done.
func dig_at(cell: Vector3i, normal: Vector3i) -> bool:
	var world = game.world
	var m: int = world.get_cell(cell.x, cell.y, cell.z)
	if cell.y == 0 or m == Mat.AIR:
		return false
	if too_far(cell, tool_record().reach):
		game.character.nag("far", "Слишком далеко")
		return false
	if _is_trunk(cell):
		return chop(cell)
	var t := tool_record()
	if not Tools.can_dig(t, m):
		game.character.nag("tool", Tools.why_not(t, m))
		return false
	return _dig(_dig_targets(Tools.area_cells(cell, normal), t), Tools.swing_time(t, m))


## The first cells of `order` the tool `t` can dig, as many as it takes in a swing.
func _dig_targets(order: Array[Vector3i], t: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in order:
		if out.size() >= t.area:
			break
		var m: int = game.world.get_cell(c.x, c.y, c.z)
		if c.y > 0 and m != Mat.AIR and Tools.can_dig(t, m) and not _is_trunk(c) and not too_far(c, t.reach):
			out.append(c)
	return out


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
		var at := _floor_under(c)
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
func _floor_under(cell: Vector3i) -> Vector3:
	var world = game.world
	var y := cell.y
	while y > 1 and y > cell.y - 64 and not world.is_solid(cell.x, y - 1, cell.z):
		y -= 1
	var h: float = world.ground_height(cell.x + 0.5, cell.z + 0.5)
	var at := Vector3(cell.x + 0.5, h if h >= y - 1 and h <= y else float(y), cell.z + 0.5)
	return at * CELL


func _is_trunk(cell: Vector3i) -> bool:
	return game.world.get_cell(cell.x, cell.y, cell.z) == Mat.LOG and game.world.trees.has(Vector2i(cell.x, cell.z))


## A hit with the axe at the tree whose trunk holds `cell`; it falls when the hits add
## up to its species' `hits`. True if the axe swung.
func chop(cell: Vector3i) -> bool:
	var t := tool_record()
	if t.tool != "axe":
		game.character.nag("tool", "Дерево рубят топором")
		return false
	if not game.character.act("chop"):
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


## Places the right hand's block with the brush around `center`, across face `normal`:
## each cell that is free, within reach and next to something solid. Returns how many
## were placed.
func place_at(center: Vector3i, normal: Vector3i) -> int:
	var world = game.world
	var block: int = Mat.PLACEABLE[selected]
	var item: String = Items.placed_by[block]
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


## The action button: works in front of the player with the hand in use. The left hand
## chops a tree in front with an axe, uses itself or the tool on a bush in front (see
## Gathering.gather), else digs the cells in front in the order of Tools.front_cells. The
## right hand fills a hole in front, else places in front at the feet, else above that.
func act_in_front() -> void:
	if not dig_mode:
		_place_in_front()
		return
	var t := tool_record()
	var f := feet()
	var s := step()
	if t.tool == "axe":
		var trunk: Variant = _trunk_in_front(f, s)
		if trunk != null:
			chop(trunk)
			return
	var bush: Variant = _bush_in_front(f, s)
	if bush != null and t.tool != "pickaxe":
		game.gathering.gather({"bush": bush})
		_cooldown = t.swing
		return
	var cells := _dig_targets(_front_order(f, s), t)
	if cells.is_empty():
		game.character.nag("front", "Перед тобой нечего %s" % ("рубить" if t.tool == "axe" else "копать"))
		_cooldown = 0.3
		return
	var c: Vector3i = cells[0]
	_dig(cells, Tools.swing_time(t, game.world.get_cell(c.x, c.y, c.z)))


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


## The cell of a tree's trunk one or two columns in front, or null.
func _trunk_in_front(f: Vector3i, s: Vector2i) -> Variant:
	for d in [1, 2]:
		for dy in [0, 1, -1, 2]:
			var cell := f + Vector3i(s.x * d, dy, s.y * d)
			if _is_trunk(cell):
				return cell
	return null


## The cell of a bush one or two columns in front, or null.
func _bush_in_front(f: Vector3i, s: Vector2i) -> Variant:
	for d in [1, 2]:
		for dy in [0, -1, 1]:
			var cell := f + Vector3i(s.x * d, dy, s.y * d)
			if game.world.bushes.has(cell):
				return cell
	return null


## The cells the action button would work on now, for the cursor frame.
func _front_preview() -> Array[Vector3i]:
	var f := feet()
	var s := step()
	if not dig_mode:
		var front := f + Vector3i(s.x, 0, s.y)
		for cell in [front + Vector3i.DOWN, front, front + Vector3i.UP]:
			if _can_place(cell):
				return [cell]
		return []
	var t := tool_record()
	if t.tool == "axe":
		var trunk: Variant = _trunk_in_front(f, s)
		if trunk != null:
			return [trunk]
	var bush: Variant = _bush_in_front(f, s)
	if bush != null and t.tool != "pickaxe":
		return [bush]
	return _dig_targets(_front_order(f, s), t)


## Frames what a tap at `screen_pos` would work on: the cells to dig or to fill, red
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
		if _is_trunk(cell):
			game.cursor.show_cells([cell], t.tool == "axe" and not too_far(cell, tool_record().reach))
			return
		var cells := _dig_targets(Tools.area_cells(cell, hit.normal), t)
		var ok: bool = Tools.can_dig(t, m) and not too_far(cell, tool_record().reach) and cell.y > 0
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
## frames what the left button would dig.
func update_tip(delta: float) -> void:
	tip_clock += delta
	if touch or tip_clock < TIP_INTERVAL or mouse_pos.x < 0.0:
		return
	tip_clock = 0.0
	_show_preview(mouse_pos, _stroke.is_empty() or _stroke.dig)
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
	var text: String = "%s · уровень %d" % [Mat.NAMES[m], cell.y]
	var t := tool_record()
	if too_far(cell, tool_record().reach):
		text += "\nдалеко"
	elif _is_trunk(cell):
		text += "\nЛКМ рубить" if t.tool == "axe" else "\nрубят топором"
	elif Tools.can_dig(t, m):
		var slow: bool = t.tool == "hand" and Mat.RECORDS[m].dig == "shovel"
		text += "\nЛКМ копать%s · ПКМ поставить" % (" (руками медленно)" if slow else "")
	else:
		text += "\n%s · ПКМ поставить" % Tools.why_not(t, m)
	game.hud.show_tip(mouse_pos, text)
