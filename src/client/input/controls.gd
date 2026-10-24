extends RefCounted
## Input: keys, mouse and touch, and what they ask of the world (plan/design/ui.md,
## "Работа с ячейками"; plan/design/character.md, "Взаимодействие с миром"). Each hand
## holds any item of the bag or nothing (`hands`), and one of them is in use (`active`);
## a block is placed with the brush (Tools.BRUSHES: squares 1, 2 or 3 cells across, two
## cells one above the other, a line). With a mouse the left button works with the left
## hand and the right button with the right one; a tap on a touch screen, the action
## button and F work with the hand in use. Both keep working while the button or finger
## is held: digging swings again at the cell under it as fast as the tool swings,
## placing paints the brush along the plane the stroke began in (a floor, a wall), every
## cell on the way. What the hands do to the world (dig, chop, mow, gather, place, plant,
## the action button's work in front) is decided by the rules in WorldActions; here the
## swing waits and plays, a workbench or a campfire is set down (Props) and food eaten
## (Character). Also opening the bag, moving the cut and the playtest keys. Touch and
## mouse switch the interface layout. `game` is the Main node that owns the scene.

const Mat := preload("res://src/shared/content/materials.gd")
const VoxelRaycast := preload("res://src/shared/world/voxel_raycast.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")

const CELL := WorldData.CELL
## How often the hint under the mouse pointer is updated, in seconds.
const TIP_INTERVAL := 0.1
## How long the cursor frame stays after a touch, in seconds.
const CURSOR_TIME := 0.6
## How long the debug hint stays after a tap on a touch screen, in seconds.
const TOUCH_TIP_TIME := 4.0
## The share of a swing at which the tool strikes: the bits fly then (Effects.burst).
const STRIKE := 0.5

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
## A button or finger held on the world: {"button", "hand", "dig", "pos", "held", "pending"
## (not worked yet), "normal", "first", "last" (the plane and the first and last cells
## of a placing stroke) and "axis" (the way a line goes, -1 until it has moved)}.
var _stroke := {}
## Seconds until the hands can swing again.
var _cooldown := 0.0
var _cursor_clock := 0.0
var _touch_tip_clock := 0.0


func _init(g) -> void:
	game = g
	touch = DisplayServer.is_touchscreen_available()
	show_help = not touch


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
		if key >= KEY_1 and key < KEY_1 + Inventory.HOTBAR:
			select_slot(key - KEY_1)
		match key:
			KEY_Q, KEY_PAGEDOWN:
				game.chunks.shift_cut(-1)
			KEY_E, KEY_PAGEUP:
				game.chunks.shift_cut(1)
			KEY_R:
				game.chunks.reset_view_level()
			KEY_BRACKETLEFT:
				game.view.turn_by(1)
			KEY_BRACKETRIGHT:
				game.view.turn_by(-1)
			KEY_MINUS:
				game.view.tilt_by(-1)
			KEY_EQUAL:
				game.view.tilt_by(1)
			KEY_BACKSLASH:
				game.view.reset_turn()
			KEY_I, KEY_TAB:
				game.hud.toggle_bag()
			KEY_V:
				cycle_tool()
			KEY_C:
				cycle_brush()
			KEY_Z:
				game.clock.next_season()
			KEY_X:
				game.settings.set_raining(not game.clock.raining)
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
		var n := Inventory.HOTBAR
		# With a mouse each button is a hand; a tap on a touch screen uses the hand in use.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				tap(active if touch else 0, event.position, MOUSE_BUTTON_LEFT)
			MOUSE_BUTTON_RIGHT:
				tap(1, event.position, MOUSE_BUTTON_RIGHT)
			MOUSE_BUTTON_WHEEL_UP:
				select_slot((_slot_index() - 1 + n) % n)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_slot((_slot_index() + 1) % n)


## A tap or a click at `pos` with hand `hand` (pressed with mouse `button`, which may
## stay held): something to gather or open there first (a thing on the ground or set
## on it with any hand, a bush with a tool or bare hands), else what the hand's item is
## for (see Tools.use_of).
func tap(hand: int, pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	if hand != active:
		set_active(hand)
	if touch and game.settings.debug_tips:
		game.hud.show_tip(pos, _tip_text(pos), true)
		_touch_tip_clock = TOUCH_TIP_TIME
	var use := use_of()
	var target: Dictionary = game.gathering.target_at(pos)
	if not target.is_empty() and (use in ["tool", "hand"] or not target.has("bush")):
		if _cooldown <= 0.0 and game.gathering.gather(target):
			_cooldown = tool_record().swing
			game.player.work("", _cooldown, target.at)
			if target.has("bush") or target.has("tree"):
				game.effects.burst(target.at, Mat.LEAVES, _cooldown * STRIKE)
			game.sound.play_later(0.0 if target.has("drop") else _cooldown * STRIKE, _gather_sound(target), target.at)
		return
	match use:
		"place":
			_start_stroke(button, pos, false)
		"plant", "sow":
			var hit := pick(pos)
			if not hit.is_empty() and _cooldown <= 0.0 and game.actions.plant_at(game.character, held(), hit.cell):
				_cooldown = WorldActions.FRONT_PLACE_SWING
				game.player.work("reach", WorldActions.FRONT_PLACE_SWING, (Vector3(hit.cell) + Vector3(0.5, 1.0, 0.5)) * CELL)
		"prop":
			game.props.put_from_bag(held())
		"eat", "heal":
			_eat_held()
		_:
			_start_stroke(button, pos, true)


## What gathering `target` sounds like: a thing taken off the ground, an axe into a
## bush, hands or a blade through leaves.
func _gather_sound(target: Dictionary) -> String:
	if target.has("drop"):
		return "core:pickup"
	return "core:chop" if tool_record().tool == "axe" and target.has("bush") else "core:rustle"


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


## Takes what lies in slot `i` of the hotbar (the bag's first row) into the hand in
## use; an empty slot empties the hand.
func select_slot(i: int) -> void:
	var s = game.character.inventory.slots[i]
	put_in_hand(s[0] if s != null else "", -1, false)


## The hotbar slot holding what the hand in use holds, -1 for none.
func _slot_index() -> int:
	var slots: Array = game.character.inventory.slots
	for i in Inventory.HOTBAR:
		if slots[i] != null and slots[i][0] == held():
			return i
	return -1


## What has left the bag (the last block placed, the last seed sown, a tool thrown
## away or broken) leaves the hand, which is bare then; a tool the bag holds one of is
## in one hand only.
func _check_hands() -> void:
	var inv = game.character.inventory
	var changed := false
	for h in 2:
		if hands[h] != "" and inv.count(hands[h]) == 0:
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
		"heal":
			return "Перевязать"
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


## Eats one of the food in the hand in use from the bag, or puts on a bandage.
func _eat_held() -> void:
	if _cooldown > 0.0:
		return
	var slots: Array = game.character.inventory.slots
	for i in slots.size():
		if slots[i] != null and slots[i][0] == held():
			if game.character.eat(i):
				game.sound.play("core:eat", game.player.position)
			_cooldown = 0.5
			game.player.work("", _cooldown)
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
	# The keys and the stick push the way they point on the screen, however the
	# camera is turned.
	return PixelView.world_dir(v)


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
	var vp_pos: Vector2 = (screen_pos - view.container.global_position) / view.view_scale
	var center: Vector2 = PixelView.plane_of(Vector2(view.camera.global_position.x, view.camera.global_position.z))
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


## Takes on what a rule of WorldActions did with the hands: the wait until they swing
## again and the work the body plays. True if it did anything.
func _did(done: Dictionary) -> bool:
	if done.is_empty():
		return false
	_cooldown = done.swing
	if done.has("work"):
		game.player.work(done.work, done.time, done.at)
		game.sound.work(done, game.player.work_kind, STRIKE)
		if done.stuff >= 0 and done.at.is_finite():
			game.effects.burst(done.at, done.stuff, done.time * STRIKE)
	return true


## Works at `cell`, tapped on its face `normal`, with the hand in use (see
## WorldActions.dig_at). True if anything was done.
func dig_at(cell: Vector3i, normal: Vector3i) -> bool:
	return _did(game.actions.dig_at(game.character, cell, normal))


## Places the block in the hand in use with the brush around `center`, across face
## `normal`, below the cut (see WorldActions.place_at). Returns how many were placed.
func place_at(center: Vector3i, normal: Vector3i) -> int:
	var done: Dictionary = game.actions.place_at(game.character, center, normal, game.chunks.cut_level)
	_did(done)
	return done.get("placed", 0)


func _can_place(cell: Vector3i) -> bool:
	return game.actions.can_place(game.character, cell, game.chunks.cut_level)


## The action button: works in front of the player with the hand in use (see
## WorldActions.act_in_front); a workbench or a campfire is set down, food eaten.
func act_in_front() -> void:
	match use_of():
		"prop":
			game.props.put_from_bag(held())
			_cooldown = 0.5
			return
		"eat", "heal":
			_eat_held()
			return
	_did(game.actions.act_in_front(game.character, game.chunks.cut_level))


## The cells the action button would work on now, for the cursor frame.
func _front_preview() -> Array[Vector3i]:
	var actions = game.actions
	var who = game.character
	match use_of():
		"place":
			for cell: Vector3i in actions.front_place_cells(who):
				if _can_place(cell):
					return [cell]
			return []
		"plant", "sow":
			var spot: Variant = actions.plant_spot(who, held())
			var cells: Array[Vector3i] = []
			if spot != null:
				cells.append(spot)
			return cells
		"prop", "eat", "heal":
			return []
	var target: Dictionary = actions.front_target(who)
	if target.has("trunk"):
		return [target.trunk]
	if target.has("bush"):
		return [target.bush]
	if target.has("tree"):
		return [actions.trunk_cell(who, target.tree)]
	var work: Dictionary = actions.front_work(who, tool_record())
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
	var actions = game.actions
	var who = game.character
	var cell: Vector3i = hit.cell
	if dig:
		var t := tool_record()
		var m: int = game.world.get_cell(cell.x, cell.y, cell.z)
		var near: bool = not actions.too_far(who, cell, t.reach)
		var tree: Variant = actions.tree_of(cell)
		if tree != null and (t.tool in ["axe", "hand"] or m == Mat.LOG):
			var trunk: Vector3i = actions.trunk_cell(who, tree)
			var ok: bool = near and (t.tool == "axe" or t.tool == "hand" and actions.useful(who, {"tree": tree}))
			game.cursor.show_cells([trunk if t.tool == "axe" else cell], ok)
			return
		if Tools.mows(t) and actions.can_mow(cell, t):
			var mown: Array[Vector3i] = actions.mow_targets(who, [cell], t)
			game.cursor.show_cells(mown if not mown.is_empty() else [cell], not mown.is_empty())
			return
		var cells: Array[Vector3i] = actions.dig_targets(who, Tools.area_cells(cell, hit.normal), t)
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


## With a mouse, names the cell under the pointer and what the buttons do with it, and
## frames what the hand in use would work on. On a touch screen the debug hint of a tap
## (see tap) goes away after a while.
func update_tip(delta: float) -> void:
	tip_clock += delta
	if touch:
		if _touch_tip_clock > 0.0:
			_touch_tip_clock -= delta
			if _touch_tip_clock <= 0.0 or not game.settings.debug_tips:
				_touch_tip_clock = 0.0
				game.hud.show_tip(Vector2.ZERO, "")
		return
	if tip_clock < TIP_INTERVAL or mouse_pos.x < 0.0:
		return
	tip_clock = 0.0
	_show_preview(mouse_pos, _stroke.dig if not _stroke.is_empty() else use_of() != "place")
	game.hud.show_tip(mouse_pos, _tip_text(mouse_pos))


## The hint for screen point `pos`: the thing to gather there, else the cell and what the
## hands do with it, with the debug lines when the playtest switch is on.
func _tip_text(pos: Vector2) -> String:
	var target: Dictionary = game.gathering.target_at(pos)
	var hit := pick(pos)
	var lines := []
	if not target.is_empty():
		lines.append(game.gathering.describe(target))
	elif not hit.is_empty():
		var cell: Vector3i = hit.cell
		var m: int = game.world.get_cell(cell.x, cell.y, cell.z)
		lines.append("%s · уровень %d" % [Mat.NAMES[m], cell.y])
		for h in 2:
			lines.append("%s %s" % ["ЛКМ" if h == 0 else "ПКМ", _hint(h, cell, m)])
	if game.settings.debug_tips:
		if not target.is_empty():
			lines.append("цель: %s" % ", ".join(target.keys()))
		if not hit.is_empty():
			lines.append_array(_debug_lines(hit.cell, hit.normal))
	return "\n".join(lines)


## What the rules see at `cell` (tapped on face `normal`) for the hand in use, for the
## debug hint: the cell, what grows on it, and each check WorldActions.dig_at goes through.
func _debug_lines(cell: Vector3i, normal: Vector3i) -> Array:
	var w = game.world
	var actions = game.actions
	var who = game.character
	var m: int = w.get_cell(cell.x, cell.y, cell.z)
	var up: int = w.get_cell(cell.x, cell.y + 1, cell.z)
	var out := ["%v грань %v" % [cell, normal], "%s, над ней %s" % [Mat.RECORDS[m].id, Mat.RECORDS[up].id]]
	var plants: Array = actions.Grass.plants_on(w, cell.x, cell.y, cell.z)
	if not plants.is_empty():
		out.append("растёт: %s" % ", ".join(plants))
	var turf: Variant = w.turf_at(cell)
	if turf != null:
		out.append("дёрн: %s" % ("скошен" if turf == "" else turf))
	var tree: Variant = actions.tree_of(cell)
	if tree != null:
		out.append("дерево %v" % tree)
	var t := tool_record()
	var mow: bool = Tools.mows(t) and actions.can_mow(cell, t)
	out.append("%s: далеко %s · срезать %s (%d) · копать %s (%d)" % [t.id if t.has("id") else t.tool,
		"да" if actions.too_far(who, cell, t.reach) else "нет", "да" if mow else "нет",
		actions.mow_targets(who, [cell] as Array[Vector3i], t).size() if mow else 0,
		"да" if Tools.can_dig(t, m) else "нет", actions.dig_targets(who, Tools.area_cells(cell, normal), t).size()])
	return out


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
		"heal":
			return "перевязать"
	var t := tool_record(hand)
	if game.actions.too_far(game.character, cell, t.reach):
		return "далеко"
	var tree: Variant = game.actions.tree_of(cell)
	if tree != null and t.tool == "axe":
		return "рубить"
	if tree != null and t.tool == "hand":
		return "наломать веток"
	if m == Mat.LOG and tree != null:
		return "рубят топором"
	if Tools.mows(t) and game.actions.can_mow(cell, t):
		var picked: String = game.actions.picking(cell)
		if t.tool == "hand" and picked != "":
			return "собрать: %s" % picked.to_lower()
		return "косить" if t.tool == "scythe" else ("срезать траву" if t.tool == "sword" else "сорвать траву")
	if Tools.can_dig(t, m):
		var slow: bool = t.tool == "hand" and Mat.RECORDS[m].dig == "shovel"
		return "копать%s" % (" (руками медленно)" if slow else "")
	return Tools.why_not(t, m).to_lower()
