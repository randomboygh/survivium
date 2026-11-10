extends Node3D
## The other players on the screen (plan/architecture/server.md, С3.3): a figure for
## each (the player's own sprite, player.gd, holding what its hands hold and swinging
## the works it does), drawn between the server's snapshots of it (Protocol.PEOPLE, 20
## a second over a socket) DELAY seconds behind them, so it walks smoothly, and its
## name over its head. One the server stops telling of (PERSON_GONE: out of the zone or
## the world) goes; a member of the player's team has the name in the team's colour
## (the entry's last field). A line one says in the chat (HEARD) hangs over the name SAY_TIME
## seconds in a balloon. The name and the balloon are the interface's own letters (like
## the signs' text, SignLabels), on a layer under the rest of it, put at the head's place
## on the screen each frame, whole pixels. `game` is the Main node (its `hands` gives the
## looks of the things held).

const PlayerScript := preload("res://src/client/view/player.gd")
const Figure := preload("res://src/client/view/figure.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Body := preload("res://src/shared/game/body.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")

const CELL := WorldData.CELL
## Seconds behind the server's snapshots the figures are drawn.
const DELAY := 0.1
## Snapshots kept of each: the two round the time drawn, and a couple after.
const KEPT := 4
## The name's height in world pixels (for the gesture's icon over it), and how high over
## the head its bottom stands (world units).
const NAME_SIZE := 8
const NAME_OVER := 0.15
## How near a tap's ray passes a figure to pick it, in world units.
const PICK_REACH := 0.4
## Seconds a line said shows over the head, and how wide its balloon wraps (UI px).
const SAY_TIME := 6.0
const SAY_WIDTH := 150

var game
## The performance statistics (PerfPanel), told how long the figures take a frame.
var perf
## id -> {"figure": PlayerScript, "label": Label (the name), "line": PanelContainer (the
## balloon of what they said, its Label "said", "until" it goes), "head": the point over the
## head (world), "snaps": [[time, entry], …],
## "work_n": the last work count shown, "hands": the hands shown, "left|right|active",
## "gear": what is worn shown}
var people := {}
## The layer the names and the balloons are on: the whole interface, under its other parts.
var _layer: Control


## Takes a PEOPLE event: the entries of those that changed.
func take_people(list: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for e in list:
		if not e is Array or not e.size() in [13, 14, 15, 16, 17, 18] or not e[0] is int or not e[2] is Vector3 or not e[3] is Vector2i \
				or not e[4] is Array or e[4].size() != 2:
			continue
		var id: int = e[0]
		var one: Dictionary = people.get(id, {})
		if one.is_empty():
			one = _make(e[2])
			people[id] = one
		one.snaps.append([now, e])
		while one.snaps.size() > KEPT:
			one.snaps.pop_front()
		if one.label.text != str(e[1]):
			one.label.text = str(e[1])
		one.label.modulate = UiStyle.TEAM if e.size() > 14 and e[14] == true else Color.WHITE


func take_gone(id: int) -> void:
	var one: Dictionary = people.get(id, {})
	if one.is_empty():
		return
	people.erase(id)
	one.figure.queue_free()
	one.label.queue_free()
	one.line.queue_free()


func _exit_tree() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null


## Player `id` said `text` in the chat: it hangs over their head a while.
func speak(id: int, text: String) -> void:
	var one: Dictionary = people.get(id, {})
	if one.is_empty():
		return
	var said: Label = one.said
	said.text = text
	# As wide as the words, wrapped at SAY_WIDTH.
	var wide: float = UiStyle.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE).x
	said.custom_minimum_size.x = minf(ceilf(wide), SAY_WIDTH)
	one.line.visible = true
	one.until = Time.get_ticks_msec() / 1000.0 + SAY_TIME


## The player whose figure the view ray from `origin` along `dir` (world units) passes
## nearest, within PICK_REACH of their body's middle line: [id, name], [] for none.
func person_at(origin: Vector3, dir: Vector3) -> Array:
	var best := PICK_REACH
	var out := []
	var d := dir.normalized()
	for id in people:
		var f = people[id].figure
		var feet: Vector3 = f.position
		# The ray's point nearest the line of the body, the body's point nearest it.
		var best_here := INF
		for k in 5:
			var p := feet + Vector3(0.0, Body.HEIGHT * CELL * k / 4.0, 0.0)
			var t := maxf(0.0, (p - origin).dot(d))
			best_here = minf(best_here, (origin + d * t).distance_to(p))
		if best_here < best:
			best = best_here
			out = [id, people[id].label.text]
	return out


func _make(at: Vector3) -> Dictionary:
	var f = PlayerScript.new()
	f.position = at
	add_child(f)
	# The silhouette behind walls, the stencil and the torch are the player's own.
	f.xray.visible = false
	# The icon of a gesture over the name.
	f.gesture_icon_high = NAME_OVER + float(NAME_SIZE + 4) / PixelView.PIXELS_PER_UNIT
	f.sprite.layers = 1
	# Its light stays dark (Sky lights only the player's): hidden, the renderer skips it.
	f.torch.visible = false
	var label := UiStyle.label()
	# A name as the player wrote it, outlined to read over any ground.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer_made().add_child(label)
	var line := PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var said := UiStyle.label()
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(said)
	line.visible = false
	_layer_made().add_child(line)
	return {"figure": f, "label": label, "line": line, "said": said, "until": 0.0, "head": at,
		"snaps": [], "work_n": -1, "hands": "", "gear": ""}


func _layer_made() -> Control:
	if _layer == null:
		_layer = Control.new()
		_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		if game != null and game.hud != null:
			game.hud.add_child(_layer)
			game.hud.move_child(_layer, 0)
		else:
			add_child(_layer)
	return _layer


## Puts the names and the balloons at the heads' places on the screen.
func _place_labels() -> void:
	if _layer == null or game == null or game.view == null:
		return
	var t := _layer.get_global_transform()
	var now := Time.get_ticks_msec() / 1000.0
	for id in people:
		var one: Dictionary = people[id]
		var label: Label = one.label
		label.reset_size()
		var at: Vector2 = (game.view.screen_of(one.head) - t.origin) / t.get_scale()
		label.position = (at - Vector2(label.size.x * 0.5, label.size.y)).floor()
		var line: PanelContainer = one.line
		if line.visible:
			line.visible = now < one.until
			line.reset_size()
			line.position = (Vector2(at.x - line.size.x * 0.5, label.position.y - line.size.y - 1.0)).floor()


func _process(delta: float) -> void:
	if people.is_empty():
		return
	var t := Time.get_ticks_usec()
	var now := Time.get_ticks_msec() / 1000.0 - DELAY
	for id in people:
		var one: Dictionary = people[id]
		var snaps: Array = one.snaps
		if snaps.is_empty():
			continue
		# The two snapshots round the time drawn; before the first or past the last the
		# figure stands at it.
		var a: Array = snaps[0]
		var b: Array = snaps[-1]
		for i in range(snaps.size() - 1):
			if snaps[i][0] <= now and now <= snaps[i + 1][0]:
				a = snaps[i]
				b = snaps[i + 1]
				break
		if now >= b[0]:
			a = b
		var k := 0.0 if b[0] <= a[0] else clampf((now - a[0]) / (b[0] - a[0]), 0.0, 1.0)
		var at: Vector3 = a[1][2].lerp(b[1][2], k)
		var e: Array = b[1]
		var f = one.figure
		var went := Vector2(at.x - f.position.x, at.z - f.position.z)
		var rose: float = at.y - f.position.y
		f.position = at
		var hands_key := "%s|%s|%s" % [e[4][0], e[4][1], e[5]]
		if hands_key != one.hands:
			one.hands = hands_key
			f.hold(game.hands.look(str(e[4][0])), game.hands.look(str(e[4][1])), "left" if e[5] == 0 else "right")
		# What they wear shows on them.
		if e.size() > 13 and e[13] is Dictionary and str(e[13]) != one.gear:
			one.gear = str(e[13])
			f.dress(Figure.dressed(e[13]))
		# Their fishing line in the water, its float where the server says.
		f.line_at = e[15] if e.size() > 15 and e[15] is Vector3 else Vector3.INF
		# The vessel they sit in, afloat.
		f.riding = str(e[16]) if e.size() > 16 and e[16] is String else ""
		f.rowing = f.riding != "" and game.boats.rower_at(at)
		# The gesture they make, its icon over them.
		f.set_gesture(str(e[17]) if e.size() > 17 and e[17] is String else "")
		if e[11] != one.work_n:
			one.work_n = e[11]
			if str(e[9]) != "":
				f.work(str(e[9]), float(e[10]), e[12] if e[12] is Vector3 else Vector3.INF)
		# The figure walks the way it went, else faces the step told; swims, jumps or
		# stands as the server says.
		f.body.swimming = bool(e[7])
		f.body.on_ground = bool(e[8])
		f.body.velocity_y = 1.0 if rose > 0.0 else -1.0
		var dir := went / CELL / maxf(delta, 0.001)
		if dir.length() < 0.1 and bool(e[6]):
			# Told moving but not yet seen going: faces the step told, walking in place.
			dir = Vector2(e[3]) * 0.2
		elif dir.length() < 0.1:
			f.facing = SpriteSheet.direction_of(Vector2(e[3]))
		f._animate(dir.limit_length(1.0), dir.length(), delta)
		f.place_sprite()
		one.head = at + Vector3(0.0, Body.HEIGHT * CELL + NAME_OVER, 0.0)
	_place_labels()
	if perf != null:
		perf.add("другие", Time.get_ticks_usec() - t)
