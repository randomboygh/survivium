extends RefCounted
## Input: keys, mouse and touch, and what they do to the world (gather, dig, place,
## pick a block, open the bag, move the cut, the playtest keys). Digging puts what
## the cell gives into the bag and placing takes the block from it (Character), unless
## the playtest switch for free building is on. Touch and mouse switch the interface
## layout. `game` is the Main node that owns the scene.

const Mat := preload("res://src/shared/materials.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Trees := preload("res://src/shared/trees.gd")
const Items := preload("res://src/shared/items.gd")

const CELL := WorldData.CELL
## How far from the player a cell can be dug or placed, in world units.
const REACH := 7.0
## How often the hint under the mouse pointer is updated, in seconds.
const TIP_INTERVAL := 0.1

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
	elif event is InputEventMouseButton and event.pressed:
		var n: int = Mat.PLACEABLE.size()
		# With a mouse each button is a hand: the left one digs, the right one places.
		# A tap on a touch screen uses the hand chosen on the hotbar.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				# A tap or a click near something to gather takes it before digging.
				var target: Dictionary = game.gathering.target_at(event.position)
				if not target.is_empty():
					game.gathering.gather(target)
				else:
					_edit(event.position, dig_mode or not touch)
			MOUSE_BUTTON_RIGHT:
				_edit(event.position, false)
			MOUSE_BUTTON_WHEEL_UP:
				select_block((selected - 1 + n) % n, false)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_block((selected + 1) % n, false)


func set_touch(on: bool) -> void:
	if on != touch:
		touch = on
		game.hud.set_touch(on)
		if on:
			game.hud.show_tip(Vector2.ZERO, "")


func set_dig_mode(on: bool) -> void:
	dig_mode = on
	game.hud.refresh_hands()


## Takes block `i` of the hotbar into the right hand; `use` also makes it the hand in use.
func select_block(i: int, use := true) -> void:
	selected = i
	if use:
		dig_mode = false
	game.hud.refresh_hands()


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


## The cell under a screen point, as VoxelRaycast.cast returns it (empty if none).
func pick(screen_pos: Vector2) -> Dictionary:
	if not game.ready_to_play:
		return {}
	var view = game.view
	var vp_pos: Vector2 = (screen_pos - view.container.global_position) / float(view.container.stretch_shrink)
	var center: Vector2 = Vector2(view.camera.global_position.x, view.camera.global_position.z)
	var world = game.world
	var ray: Array = PixelView.view_ray(center, vp_pos - Vector2(view.image_size) * 0.5, world.size_y * CELL + 1.0)
	var max_level: int = mini(game.chunks.cut_level, world.size_y - 1)
	return VoxelRaycast.cast(world, ray[0] / CELL, ray[1], 500.0, max_level)


func _edit(screen_pos: Vector2, dig: bool) -> void:
	var hit := pick(screen_pos)
	if hit.is_empty():
		return
	var world = game.world
	var cell: Vector3i = hit.cell
	if dig:
		if cell.y == 0 or too_far(cell):
			return
		var was: int = world.get_cell(cell.x, cell.y, cell.z)
		if was == Mat.LOG and world.trees.has(Vector2i(cell.x, cell.z)):
			if game.character.act("fell"):
				_fell(cell)
			return
		if not game.character.act("dig"):
			return
		world.set_cell(cell.x, cell.y, cell.z, Mat.AIR)
		if not game.settings.free_build and Items.dug[was] != "":
			game.character.give(Items.dug[was], 1)
	else:
		var normal: Vector3i = hit.normal
		cell += normal
		if not world.in_bounds(cell.x, cell.y, cell.z) or too_far(cell):
			return
		var cur: int = world.get_cell(cell.x, cell.y, cell.z)
		if cur != Mat.AIR and cur != Mat.WATER or game.player.overlaps_cell(cell):
			return
		var block: int = Mat.PLACEABLE[selected]
		var item: String = Items.placed_by[block]
		if not game.settings.free_build and game.character.inventory.count(item) == 0:
			game.character.nag("no_block", "В сумке нет: %s" % Items.title(item))
			return
		if not game.character.act("place"):
			return
		if not game.settings.free_build:
			game.character.inventory.remove(item, 1)
		world.set_cell(cell.x, cell.y, cell.z, block)
	game.chunks.on_cell_changed(cell)


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


func too_far(cell: Vector3i) -> bool:
	var center := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	return center.distance_to(game.player.position + Vector3(0.0, 0.5, 0.0)) > REACH


## With a mouse, names the cell under the pointer and what the buttons do with it.
func update_tip(delta: float) -> void:
	tip_clock += delta
	if touch or tip_clock < TIP_INTERVAL or mouse_pos.x < 0.0:
		return
	tip_clock = 0.0
	var target: Dictionary = game.gathering.target_at(mouse_pos)
	if not target.is_empty():
		game.hud.show_tip(mouse_pos, game.gathering.describe(target))
		return
	var hit := pick(mouse_pos)
	if hit.is_empty():
		game.hud.show_tip(mouse_pos, "")
		return
	var cell: Vector3i = hit.cell
	var text: String = "%s · уровень %d" % [Mat.NAMES[game.world.get_cell(cell.x, cell.y, cell.z)], cell.y]
	if too_far(cell):
		text += "\nдалеко"
	else:
		text += "\nЛКМ копать · ПКМ поставить"
	game.hud.show_tip(mouse_pos, text)
