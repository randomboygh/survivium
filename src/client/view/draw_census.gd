extends Node
## Counts the draw calls of the frame by what is drawn, on the device itself: each group
## (the parts of the chunks, the animals, the effects, the player, every piece of the
## interface...) is hidden for a few frames in turn, and what the frame lost is put down.
## Started from the playtest page («Отладка»), with the game running; the list shows over
## the screen, the most costly first, until it is tapped. A tool for the developer: the
## picture blinks while it counts.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Frames a group stays hidden; the calls are read in the last of them.
const HIDDEN_FRAMES := 4
## Frames the renderer is given to settle before the first count.
const SETTLE_FRAMES := 30
## Lines in the list at most.
const LINES := 16

var game
var _panel: PanelContainer


func _init(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS


## Counts and shows the list; does nothing while a count runs.
func start() -> void:
	if get_meta("running", false):
		return
	set_meta("running", true)
	if _panel != null:
		_panel.queue_free()
		_panel = null
	await _frames(SETTLE_FRAMES)
	var all := await _count()
	var rows := []
	for g: Array in _groups():
		var nodes: Array = g[1]
		var shown := []
		for n in nodes:
			if is_instance_valid(n) and n.visible:
				shown.append(n)
		if shown.is_empty():
			continue
		for n in shown:
			n.visible = false
		var less := await _count()
		for n in shown:
			if is_instance_valid(n):
				n.visible = true
		rows.append([g[0], all.x - less.x, all.y - less.y])
	# The lights: the sun's or the moon's shadow, and the fires' and the torch's.
	var sun: DirectionalLight3D = game.sky.sun
	if sun.shadow_enabled:
		sun.shadow_enabled = false
		var no_sun := await _count()
		sun.shadow_enabled = true
		rows.append(["тень солнца и луны", all.x - no_sun.x, 0])
	var lights := []
	for l: OmniLight3D in game.world_root.find_children("*", "OmniLight3D", true, false):
		if l.visible:
			lights.append(l)
	if not lights.is_empty():
		for l in lights:
			l.visible = false
		var dark := await _count()
		for l in lights:
			l.visible = true
		rows.append(["свет огней (%d)" % lights.size(), all.x - dark.x, 0])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var lines := ["Вызовы %d · объекты %d" % [all.x, all.y]]
	for r in rows.slice(0, LINES):
		if r[1] >= 1 or r[2] >= 10:
			lines.append("%s: %d · %d" % [r[0], r[1], r[2]])
	var text := "\n".join(lines)
	print("draw census\n" + text)
	_show(text)
	set_meta("running", false)


## The groups counted: [name, nodes] each.
func _groups() -> Array:
	var groups := []
	var parts := ["земля", "вода", "трава", "кроны", "тени крон", "кусты", "сугробы"]
	var known := {}
	for i in parts.size():
		var nodes := []
		for chunk: Array in game.chunks.chunk_nodes.values():
			if i < chunk.size():
				nodes.append(chunk[i])
				known[chunk[i]] = true
		groups.append(["чанки: " + parts[i], nodes])
	var caps: Array = game.chunks.cap_nodes.values()
	for n in caps:
		known[n] = true
	groups.append(["чанки: срезы", caps])
	for pair in [["звери", game.creatures], ["эффекты", game.effects], ["игрок", game.player],
			["нарисованные тени", game.fire_shadows], ["следы", game.tracks], ["курсор", game.cursor]]:
		if pair[1] != null:
			groups.append([pair[0], [pair[1]]])
			known[pair[1]] = true
	known[game.drifts_root] = true
	known[game.sky.sun] = true
	# Everything else in the world, by its script or class.
	var others := {}
	for n in game.world_root.get_children():
		if known.has(n) or not (n is Node3D):
			continue
		var key := _kind(n)
		if not others.has(key):
			others[key] = []
		others[key].append(n)
	for key in others:
		groups.append([key, others[key]])
	# The whole world and the whole interface, then the interface a piece at a time.
	groups.append(["весь мир", [game.world_root]])
	groups.append(["весь экран", [game.hud]])
	for n in game.hud.get_children():
		if n is CanvasItem and n != _panel:
			groups.append(["экран: " + _hud_name(n), [n]])
	return groups


## What the interface calls `n`: the name of its var that holds it, or its kind.
func _hud_name(n: Node) -> String:
	for p in game.hud.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.type == TYPE_OBJECT and game.hud.get(p.name) == n:
			return String(p.name).trim_prefix("_")
	return _kind(n)


func _kind(n: Node) -> String:
	var s: Script = n.get_script()
	if s != null and s.resource_path != "":
		return s.resource_path.get_file().get_basename()
	return "%s %s" % [n.get_class(), String(n.name).left(16)]


## Calls and objects of the frame drawn last, once the change has been drawn.
func _count() -> Vector2i:
	await _frames(HIDDEN_FRAMES)
	return Vector2i(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _show(text: String) -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := UiStyle.label(text)
	_panel.add_child(label)
	# Below the statistics, so a screenshot holds both.
	_panel.position = Vector2(8, game.hud.size.y * 0.3)
	_panel.gui_input.connect(_on_panel_input)
	game.hud.add_child(_panel)


func _on_panel_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_panel.queue_free()
		_panel = null

