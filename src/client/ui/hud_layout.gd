extends "res://src/client/ui/hud_messages.gd"
## The game screen's interface, part three (hud.gd): where everything goes for the
## shape and the size of the screen (fit, _place, _place_top), the hotbar's pages and
## scrolling, the bag's tab, the clock, the key hints, and the hotbar shown anew: the bag's
## first row, the hands and the action button.

const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const FactChips := preload("res://src/client/ui/fact_chips.gd")
const Quality := preload("res://src/shared/game/quality.gd")
## UI height the scale aims for on the shorter side of the screen: on a phone exactly,
## so its windows fit any phone as they do the reference one (1200 px wide at ×3).
const TARGET_SIDE := 400.0
## The interface size setting, «очень мелкий» to «крупный»: on a phone the share of the
## scale picked from the screen, on a computer whole steps around it (UI_STEPS).
const UI_SIZES := [0.67, 0.83, 1.0, 1.33, 1.67]
const UI_STEPS := [-2, -1, 0, 1, 2]
## The size of the joystick and the touch buttons, the same five steps.
const CONTROL_SIZES := [0.7, 0.85, 1.0, 1.2, 1.4]
## The width of the level buttons beside the minimap: one button's; the arrows'
## height and the least of the level's between them.
const LEVEL_WIDTH := 40
const LEVEL_ARROW := 24
const LEVEL_MIDDLE := 34


## Fits the UI into `rect` (screen pixels) and places everything for the screen's
## shape and the input in use. On a computer the scale is a whole number picked from
## the shorter side; on a phone or a tablet (`turning`) it is a fraction of the whole
## `screen`'s shorter side (the whole screen, `rect` by default), so browser toolbars
## coming and going do not change it.
func fit(rect: Rect2, turning := false, screen := Vector2.ZERO) -> void:
	var s: float
	if turning:
		var side := minf(screen.x, screen.y) if screen != Vector2.ZERO else minf(rect.size.x, rect.size.y)
		_screen_scale = side / TARGET_SIDE
		s = maxf(1.0, _screen_scale * UI_SIZES[ui_size])
	else:
		_screen_scale = maxi(1, roundi(minf(rect.size.x, rect.size.y) / TARGET_SIDE))
		s = maxi(1, _screen_scale + UI_STEPS[ui_size])
	scale = Vector2(s, s)
	position = rect.position
	size = (rect.size / s).floor()
	portrait = size.x < size.y
	_place()


## Sizes the minimap (an index into Minimap.SIDES) and shows or hides the level buttons
## and the camera cross, as the interface settings say; lays the HUD out again when
## something changed.
func set_corner(map_size: int, level: bool, camera: bool) -> void:
	if map_size == minimap_size and level == level_buttons and camera == camera_buttons \
			and minimap.side == Minimap.SIDES[map_size]:
		return
	minimap_size = map_size
	level_buttons = level
	camera_buttons = camera
	minimap.set_side(Minimap.SIDES[map_size])
	# Up, the level and down are as tall as the minimap, or as tall as they can be
	# beside a small one.
	_level_label.custom_minimum_size.y = maxf(LEVEL_MIDDLE, minimap.size.y - 2 * LEVEL_ARROW - 4)
	_level.visible = level
	_camera.visible = camera
	if size != Vector2.ZERO:
		_place()


func set_touch(on: bool) -> void:
	if on == touch:
		return
	touch = on
	_place()


func _place() -> void:
	var w := size.x
	var h := size.y
	_place_top()

	stick.visible = touch
	_action.visible = touch
	_jump.visible = touch
	_keys.visible = not touch and game.controls.show_help and not bag.visible
	var bottom := h - MARGIN
	# The controls' own size setting, whatever the interface's: undo the latter.
	var k: float = CONTROL_SIZES[control_size] * _screen_scale / scale.x
	for c: Control in [stick, _action, _jump]:
		c.scale = Vector2(k, k)
	var stick_size: Vector2 = stick.size * k
	stick.position = Vector2(MARGIN + 4, bottom - stick_size.y)
	_action.size = _action.custom_minimum_size
	_action.position = Vector2(w - MARGIN - _action.size.x * k, bottom - _action.size.y * k)
	_jump.size = _jump.custom_minimum_size
	_jump.position = Vector2(_action.position.x - 6 - _jump.size.x * k, bottom - _jump.size.y * k)

	# All the slots when they fit across the screen beside the hands and the separator,
	# else as many as fit between the two arrows, four at most in portrait.
	var fixed := 2 * SLOT + 12 + 3 * GAP + 8
	var room := w - 2 * MARGIN - fixed
	if floori(room / (SLOT + GAP)) >= _slots.size():
		_visible_slots = _slots.size()
	else:
		_visible_slots = clampi(floori((room - 2 * (28 + GAP)) / (SLOT + GAP)), 1, 4 if portrait else _slots.size())
	_first = clampi(_first, 0, _slots.size() - _visible_slots)
	_show_page()
	# The build or the farming mode's bar in the hotbar's place: as wide as the room for it.
	var bar: Control = _shown_bar()
	var mode_bar: BuildBar = bar if bar != _bar else null
	if mode_bar != null:
		# Between the stick and the buttons when six columns fit there, else across the
		# screen over them.
		var across := w - 2 * MARGIN
		if touch and not portrait:
			var between: float = (_jump.position.x - 8) - (stick.position.x + stick_size.x + 8)
			if between >= mode_bar.width_for(6):
				across = between
			else:
				# Over the buttons: short of the minimap's column on the right.
				across = minf(across, _right_column() - 8 - MARGIN)
		mode_bar.fit(across, portrait)
	bar.reset_size()
	var bw := bar.size.x
	var bh := bar.size.y
	var x := floorf((w - bw) * 0.5)
	var y := bottom - bh
	if touch:
		var free_left: float = stick.position.x + stick_size.x + 8
		var free_right := _jump.position.x - 8
		if free_right - free_left >= bw:
			x = clampf(x, free_left, free_right - bw)
		else:
			y = minf(stick.position.y, _jump.position.y) - 8 - bh
			if mode_bar != null and not portrait:
				x = maxf(MARGIN, minf(x, _right_column() - 8 - bw))
	# The clock under the hotbar's right end, overlapping its outline.
	_clock_panel.reset_size()
	var clock_room := _clock_panel.size.y - 2
	y -= clock_room
	bar.position = Vector2(x, y)
	_clock_panel.position.y = y + bh - 2
	_align_clock()
	# The tab sits on the hotbar's frame at its right end, overlapping its outline; the
	# build mode's palette counts the blocks itself.
	_bag_meter.position = Vector2(x + bw - _bag_meter.size.x, y - _bag_meter.size.y + 2)
	_bag_meter.visible = mode_bar == null

	_keys.reset_size()
	_keys.position = Vector2(w - MARGIN - _keys.size.x, bottom - _keys.size.y)
	if _keys.position.x < x + bw + 8:
		_keys.position.y = y - 8 - _keys.size.y
	# Off the camera cross under the minimap, on the left of a short window.
	if _camera.visible and Rect2(_keys.position, _keys.size).intersects(Rect2(_camera.position, _camera.size).grow(4)):
		_keys.position.x = MARGIN
	# The chat in the bottom left corner: over the stick, over the hotbar where they
	# share the left of the screen.
	var chat_bottom: float = stick.position.y - 6 if touch else bottom
	if x < MARGIN + ChatBox.WIDTH + 8:
		chat_bottom = minf(chat_bottom, _bag_meter.position.y - 4)
	chat.place(Vector2(MARGIN, chat_bottom), w - 2 * MARGIN)
	_loading.reset_size()
	_loading.position = ((size - _loading.size) * 0.5).floor()
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()
	if _settings != null:
		_settings.fit(size)
	bag.fit(size)
	map_view.fit(size, touch)
	refresh_counts()


func _show_page() -> void:
	for i in _slots.size():
		_slots[i].visible = i >= _first and i < _first + _visible_slots
	_next_button.visible = _visible_slots < _slots.size()
	_prev_button.visible = _next_button.visible
	# The arrows stop at the ends: the slots do not go round.
	_prev_button.disabled = _first <= 0
	_next_button.disabled = _first >= _slots.size() - _visible_slots


## The next slot (as a finger dragging the slots one along); none past the last.
func _next_page() -> void:
	_scroll(1)


## The slot before; none before the first.
func _prev_page() -> void:
	_scroll(-1)


## Moves the shown slots `by` slots along.
func _scroll(by: int) -> void:
	_first = clampi(_first + by, 0, _slots.size() - _visible_slots)
	_show_page()


## A finger dragged along the hotbar slots moves them a slot for each slot it passes;
## the tap it began with picks nothing.
func _input(event: InputEvent) -> void:
	if _bar == null or not _prev_button.visible or not _bar.is_visible_in_tree():
		_swipe = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe < 0 and _in_slots(event.position):
			_swipe = event.index
			_swipe_x = _bar_x(event.position)
			_swiped = false
		elif not event.pressed and event.index == _swipe:
			_swipe = -1
	elif event is InputEventScreenDrag and event.index == _swipe:
		var x := _bar_x(event.position)
		if not _swiped and absf(x - _swipe_x) > 6.0:
			_swiped = true
			for s in _slots:
				s.cancel_tap()
		if _swiped:
			var step := SLOT + GAP
			while _swipe_x - x >= step:
				_scroll(1)
				_swipe_x -= step
			while x - _swipe_x >= step:
				_scroll(-1)
				_swipe_x += step


## Screen point `pos` in UI pixels of the hotbar row.
func _bar_point(pos: Vector2) -> Vector2:
	return _bar_row.get_global_transform_with_canvas().affine_inverse() * pos


func _bar_x(pos: Vector2) -> float:
	return _bar_point(pos).x


## Whether screen point `pos` is on the slots between the arrows.
func _in_slots(pos: Vector2) -> bool:
	var p := _bar_point(pos)
	return p.y >= 0.0 and p.y <= _bar_row.size.y and p.x >= _prev_button.position.x \
		and p.x <= _next_button.position.x + _next_button.size.x


# --- Per-frame state -------------------------------------------------------------


## Gives the item pictures the terrain atlas, for blocks without a picture of their own.
func set_block_icons(atlas: Texture2D, tile: int, tiles: int) -> void:
	ItemIcons.use_atlas(atlas, tile, tiles)
	refresh_counts()


## The character's state changed: the hotbar is shown anew at the end of the frame,
## once however many events of the server changed it (a craft finished tells the bag,
## the queue and a line at once).
func _counts_later() -> void:
	if not _counts_due:
		_counts_due = true
		refresh_counts.call_deferred()


## Shows the bag's first row on the hotbar: each item with how many there are and its
## number (its key with a keyboard, as in the bag); then the hands and the bag button.
func refresh_counts() -> void:
	_counts_due = false
	var slots: Array = game.character.inventory.slots
	for i in _slots.size():
		var s = slots[i]
		_slots[i].texture = ItemIcons.of_item(s[0]) if s != null else null
		_slots[i].number = "×%d" % s[1] if s != null and s[1] > 1 else ""
		_slots[i].fill = game.character.inventory.freshness(i)
		_slots[i].grade = Quality.grade(game.character.inventory.quality_at(i)) if s != null else -1
		# A weapon with nothing in the bag to shoot shows inactive.
		_slots[i].inactive = s != null and FactChips.unarmed(game.character.inventory, s[0])
		_slots[i].key = str(i + 1)
	_update_hands()
	_fit_bag_meter()
	_bag_meter.queue_redraw()


## Makes the bag's tab as wide as its divisions, a division of BAG_DIVISION pixels and
## a pixel between a slot (at least the room of its line of the weight), so a bigger bag
## has more of the same divisions and a longer tab; laid out again when that changes the
## width.
func _fit_bag_meter() -> void:
	var inv = game.character.inventory
	var n: int = maxi(inv.slots.size(), 1)
	var w := float(maxi(n * (BAG_DIVISION + 1) - 1, UiStyle.weight_width(inv.weight_limit) + 6) + 10)
	if _bag_meter.custom_minimum_size.x == w:
		return
	_bag_meter.custom_minimum_size.x = w
	_bag_meter.size.x = w
	_place()


## The top of the interface: the statistics over it when shown, under them the state
## on the left, the buttons on the right, the minimap under the buttons with the level
## buttons on its left and the camera cross under it (under both when the map is small,
## kept on the screen). The statistics take the room
## left of the buttons when PerfPanel.WIDTH fits there (a wide screen); else they go
## across the whole top and everything moves down under them (a phone held upright).
## Their width stays as it is while their numbers change.
## The left edge of the column of the minimap, its level buttons and the camera cross.
func _right_column() -> float:
	var x: float = minimap.position.x
	if _level.visible:
		x = minf(x, _level.position.x)
	if _camera.visible:
		x = minf(x, _camera.position.x)
	return x


func _place_top() -> void:
	var w := size.x
	_top.reset_size()
	var column := _top.size.x
	_level.reset_size()
	var level := _level.size.x + 6 if _level.visible else 0.0
	column = maxf(column, minimap.size.x + level)
	var top := MARGIN
	var left := MARGIN
	if perf.visible:
		var beside := w - 3 * MARGIN - column
		perf.width = perf.WIDTH if perf.WIDTH <= beside else w - 2 * MARGIN
		perf.position = Vector2(MARGIN, MARGIN)
		perf.size = Vector2(perf.width, 0)
		left += perf.size.y + 6
		if perf.width > beside:
			top = left
	_left.position = Vector2(MARGIN, left)
	_top.position = Vector2(w - MARGIN - _top.size.x, top)
	minimap.position = Vector2(w - MARGIN - minimap.size.x, _top.position.y + _top.size.y + 6)
	_level.position = Vector2(minimap.position.x - 6 - _level.size.x, minimap.position.y)
	_camera.reset_size()
	var cx := minf(minimap.position.x + floorf((minimap.size.x - _camera.size.x) * 0.5), w - MARGIN - _camera.size.x)
	var below := minimap.position.y + minimap.size.y
	if _level.visible and cx < _level.position.x + _level.size.x:
		below = maxf(below, _level.position.y + _level.size.y)
	_camera.position = Vector2(cx, below + 6)
	var room := minf(_top.position.x, minimap.position.x - level) - 6 - MARGIN
	if room != _toast_room:
		_toast_room = room
		for h: Control in _toasts.get_children():
			_fit_toast(h.get_child(0))


## Keeps the clock's right edge on the hotbar's as its text and icons change width.
func _align_clock() -> void:
	var wide := _clock_panel.get_combined_minimum_size().x
	if not is_equal_approx(_clock_panel.size.x, wide):
		_clock_panel.size.x = wide
	var bar: Control = _shown_bar()
	# A mode's bar: under its palette's right end, where the hotbar's would be.
	var right: float = bar.size.x if bar == _bar else (bar as BuildBar).right_edge()
	_clock_panel.position.x = bar.position.x + right - wide
	_sleep_button.size = Vector2(SLEEP_SIZE.x, _clock_panel.size.y)
	_sleep_button.position = _clock_panel.position + Vector2(_clock_panel.size.x - SLEEP_SIZE.x, 0)


## The bar shown at the bottom: the hotbar, or the build or the farming mode's bar.
func _shown_bar() -> Control:
	if build_bar != null and build_bar.visible:
		return build_bar
	if farm_bar != null and farm_bar.visible:
		return farm_bar
	return _bar


## The build mode came or went: its bar in the hotbar's place, or the hotbar back.
func show_build(on: bool) -> void:
	build_bar.visible = on
	_bar.visible = not on and not farm_bar.visible
	if on:
		build_bar.refresh()
	_place()
	_update_hands()


## The farming mode came or went: its bar in the hotbar's place, or the hotbar back.
func show_farm(on: bool) -> void:
	farm_bar.visible = on
	_bar.visible = not on and not build_bar.visible
	if on:
		farm_bar.refresh()
	_place()
	_update_hands()


## Shows what each hand holds and marks the hand in use and the blocks in the hands;
## called when any of it changes.
func _update_hands() -> void:
	var c = game.controls
	var free: bool = game.rules.free_build
	for h in 2:
		var slot = _hand_left if h == 0 else _hand_right
		var id: String = c.hands[h]
		slot.selected = c.active == h
		slot.texture = ItemIcons.of_item(id) if id != "" else ItemIcons.picture("hand")
		var n: int = game.character.inventory.count(id) if id != "" else 0
		slot.modulate = Color(1, 1, 1, 0.5) if id != "" and n == 0 and not (free and c.use_of(h) == "place") else Color.WHITE
		slot.number = "×%d" % n if n > 1 else ""
		# A light burns down in the hand: the second hand holds the second one lit.
		var k := 1 if h == 1 and c.hands[0] == id and n > 1 else 0
		slot.inactive = FactChips.unarmed(game.character.inventory, id)
		slot.fill = game.character.burn_left(id, k) if id != "" and n > 0 and Items.burns(id) > 0.0 else -1.0
	var slots: Array = game.character.inventory.slots
	for i in _slots.size():
		var item: String = slots[i][0] if slots[i] != null else ""
		_slots[i].selected = item != "" and c.held() == item
		_slots[i].tag = "" if item == "" else ("Л" if c.hands[0] == item else ("П" if c.hands[1] == item else
			("Н" if game.character.inventory.worn_on(i) != "" else "")))
	_action.text = c.action_name()
	# Pressed down while the fishing line is in the water, or while the build mode builds.
	_action.latch(_action_latched())
	# The picture of what the hand in use holds, bare hands for nothing.
	var held: String = c.held()
	var pic: Texture2D = ItemIcons.of_item(held) if held != "" else null
	_action.icon = pic if pic != null else ItemIcons.picture("hand")


## Whether the action button stays pressed down: the fishing line is in the water, or
## the build or the farming mode works.
func _action_latched() -> bool:
	return game.character.line.is_finite() or game.build.auto or game.farm.auto


func refresh_hands() -> void:
	_update_hands()


## The action button's label anew for what is in front of the player now
## (Controls.action_name).
func refresh_action() -> void:
	var text: String = game.controls.action_name()
	if _action.text != text:
		_action.text = text


## A tap on hand `hand` of the hotbar.
func tap_hand(hand: int) -> void:
	var c = game.controls
	if c.active != hand:
		c.set_active(hand)
	else:
		c.cycle_tool()


func _select_slot(i: int) -> void:
	game.controls.select_slot(i)


func show_keys(on: bool) -> void:
	_place()
	_keys.visible = on and not touch and not bag.visible


# --- Statistics and menu ---------------------------------------------------------
