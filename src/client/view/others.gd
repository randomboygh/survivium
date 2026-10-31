extends Node3D
## The other players on the screen (plan/architecture/server.md, С3.3): a figure for
## each (the player's own sprite, player.gd, holding what its hands hold and swinging
## the works it does), drawn between the server's snapshots of it (Protocol.PEOPLE, 20
## a second over a socket) DELAY seconds behind them, so it walks smoothly, and its
## name over its head. One the server stops telling of (PERSON_GONE: out of the zone or
## the world) goes. A line one says in the chat (HEARD) hangs over the name SAY_TIME
## seconds. `game` is the Main node (its `hands` gives the looks of the things
## held).

const PlayerScript := preload("res://src/client/view/player.gd")
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
## The name's letters in world pixels, and how high over the head it hangs (world units).
const NAME_SIZE := 8
const NAME_OVER := 0.4
## Seconds a line said shows over the head, and how wide it wraps (world pixels).
const SAY_TIME := 6.0
const SAY_WIDTH := 110

var game
## The performance statistics (PerfPanel), told how long the figures take a frame.
var perf
## id -> {"figure": PlayerScript, "label": Label3D, "line": Label3D (what they said, "until"
## it goes), "snaps": [[time, entry], …],
## "work_n": the last work count shown, "hands": the hands shown, "left|right|active"}
var people := {}


## Takes a PEOPLE event: the entries of those that changed.
func take_people(list: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for e in list:
		if not e is Array or e.size() != 13 or not e[0] is int or not e[2] is Vector3 or not e[3] is Vector2i \
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


func take_gone(id: int) -> void:
	var one: Dictionary = people.get(id, {})
	if one.is_empty():
		return
	people.erase(id)
	one.figure.queue_free()
	one.label.queue_free()
	one.line.queue_free()


## Player `id` said `text` in the chat: it hangs over their head a while.
func speak(id: int, text: String) -> void:
	var one: Dictionary = people.get(id, {})
	if one.is_empty():
		return
	one.line.text = text
	one.line.visible = true
	one.until = Time.get_ticks_msec() / 1000.0 + SAY_TIME


func _make(at: Vector3) -> Dictionary:
	var f = PlayerScript.new()
	f.position = at
	add_child(f)
	# The silhouette behind walls, the stencil and the torch are the player's own.
	f.xray.visible = false
	f.sprite.layers = 1
	var label := _label()
	var line := _label()
	line.modulate = UiStyle.INK
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.width = SAY_WIDTH
	line.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line.visible = false
	return {"figure": f, "label": label, "line": line, "until": 0.0, "snaps": [], "work_n": -1, "hands": ""}


func _label() -> Label3D:
	var label := Label3D.new()
	label.font = UiStyle.font()
	label.font_size = NAME_SIZE
	label.outline_size = 4
	label.pixel_size = 1.0 / PixelView.PIXELS_PER_UNIT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 2
	label.top_level = true
	add_child(label)
	return label


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
		one.label.position = PixelView.shear(at + Vector3(0.0, Body.HEIGHT * CELL + NAME_OVER, 0.0))
		if one.line.visible:
			one.line.visible = Time.get_ticks_msec() / 1000.0 < one.until
			one.line.position = one.label.position + Vector3(0.0, float(NAME_SIZE + 2) / PixelView.PIXELS_PER_UNIT, 0.0)
	if perf != null:
		perf.add("другие", Time.get_ticks_usec() - t)
