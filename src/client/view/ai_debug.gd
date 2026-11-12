extends Node3D
## The AI's debug (decision 184; «Отладка ИИ зверей» on «Тестирование», F4): over each
## animal near, what it has in mind as the server tells it (Protocol.MINDS, the client's
## copy RemoteWildlife.minds): what it does and why, its hunger and health; a line to
## where it goes (grey), to what it runs from or goes for (red, orange on a hunt, green to
## a float) and to its flock's lead (blue). A tap on an animal (Controls.tap) chooses it:
## its card shows the rest (rage, calm, its hurt, whether it thinks every tick), and
## circles round it on the ground: its sight (white), how near a person frightens it
## (yellow) and how near one makes it growl (red). The lines go through PixelView.shear,
## so they lie where the shaders draw the world. The text is the interface's own letters,
## outlined, the size of the names over the people (Others): on a layer under the rest of
## the interface, its bottom middle put over the animal on the screen each frame, whole
## pixels. A debug drawing: not warmed up ahead (ShaderWarmup), its first frame may build
## a shader. `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## How far over the animal's feet the text's lowest line hangs (world units).
const TEXT_OVER := 0.9
## World units from a tap's ray within which an animal is chosen.
const PICK_REACH := 0.7
## Segments of a circle drawn.
const ROUND := 40
## The colours of the lines and circles.
const GOES := Color(0.75, 0.75, 0.75)
const FLEES := Color(1.0, 0.3, 0.25)
const HUNTS := Color(1.0, 0.6, 0.15)
const LURED := Color(0.4, 0.9, 0.4)
const LEAD := Color(0.4, 0.6, 1.0)
const SIGHT := Color(1.0, 1.0, 1.0, 0.8)
const WARY := Color(1.0, 0.9, 0.3)
const GROWLS := Color(1.0, 0.3, 0.25)

## The indices of an entry of Protocol.MINDS (Wildlife.mind).
enum { ID, STATE, CAUSE, HUNGER, HEALTH, MOST, TARGET, TOWARD, LEAD_ID, OWNER, RAGE, CALM, IDLE, HURT, SEEN, WARY_AT, CLOSE_AT, NEAR }

var game
## The animal chosen by a tap (its id), -1 for none.
var chosen := -1
## The labels by animal id, and where each hangs (world).
var _labels := {}
var _heads := {}
## The layer the labels are on: the whole interface, under its other parts.
var _layer: Control
var _mesh := ImmediateMesh.new()
var _lines: MeshInstance3D


func _ready() -> void:
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 2
	_lines.material_override = m
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.top_level = true
	# Drawn wherever the lines go: no culling box to keep up.
	_lines.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	add_child(_lines)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var w = game.wildlife
	var on: bool = game.settings.ai_debug and w != null and not w.minds.is_empty()
	if not on:
		if not _labels.is_empty():
			for label: Label in _labels.values():
				label.queue_free()
			_labels.clear()
			_heads.clear()
		return
	var minds: Dictionary = w.minds
	for id: int in _labels.keys():
		if not minds.has(id) or w.by_id(id) == null:
			_labels[id].queue_free()
			_labels.erase(id)
			_heads.erase(id)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var drew := false
	for id: int in minds:
		var a = w.by_id(id)
		if a == null:
			continue
		var m: Array = minds[id]
		var label: Label = _labels.get(id)
		if label == null:
			label = _label()
			_labels[id] = label
		label.text = card(m, AiRules.SPECIES.get(a.kind, {}), id == chosen)
		_heads[id] = a.pos + Vector3(0.0, a.lift + TEXT_OVER, 0.0)
		drew = _draw(a, m, w) or drew
	_place_labels()
	if not drew:
		# A surface needs a vertex.
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


## The lines of animal `a` with mind `m`; true when it drew any.
func _draw(a, m: Array, w) -> bool:
	var from: Vector3 = a.pos + Vector3(0.0, a.lift + 0.05, 0.0)
	var drew := false
	var target: Vector3 = m[TARGET]
	if target.is_finite() and Vector2(target.x - from.x, target.z - from.z).length() > 0.1:
		_line(from, target, GOES)
		drew = true
	var toward: Vector3 = m[TOWARD]
	if toward.is_finite():
		var state: String = m[STATE]
		_line(from, toward, FLEES if state == "flee" else (LURED if state == "bait" else HUNTS))
		drew = true
	var lead_id: int = m[LEAD_ID]
	if lead_id >= 0 and lead_id != a.id:
		var lead = w.by_id(lead_id)
		if lead != null:
			_line(from, lead.pos + Vector3(0.0, lead.lift + 0.05, 0.0), LEAD)
			drew = true
	if a.id == chosen:
		var feet: Vector3 = a.pos + Vector3(0.0, 0.03, 0.0)
		for r: Array in [[m[SEEN], SIGHT], [m[WARY_AT], WARY], [m[CLOSE_AT], GROWLS]]:
			if float(r[0]) > 0.0:
				_circle(feet, r[0], r[1])
				drew = true
	return drew


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(PixelView.shear(a))
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(PixelView.shear(b))


func _circle(at: Vector3, r: float, c: Color) -> void:
	for i in ROUND:
		var t0 := TAU * i / ROUND
		var t1 := TAU * (i + 1) / ROUND
		_line(at + Vector3(cos(t0), 0.0, sin(t0)) * r, at + Vector3(cos(t1), 0.0, sin(t1)) * r, c)


func _label() -> Label:
	var label := UiStyle.label()
	# Put together from phrases already translated (card).
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_layer_made().add_child(label)
	return label


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


func _exit_tree() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null


## Puts the labels over their animals on the screen, whole pixels.
func _place_labels() -> void:
	if _layer == null or game.view == null:
		return
	var t := _layer.get_global_transform()
	for id: int in _labels:
		var label: Label = _labels[id]
		label.reset_size()
		var at: Vector2 = (game.view.screen_of(_heads[id]) - t.origin) / t.get_scale()
		label.position = (at - Vector2(label.size.x * 0.5, label.size.y)).floor()


## Chooses the animal nearest the tap's ray (`origin`, `dir`, world units) within
## PICK_REACH; the one chosen already, tapped again, is let go. True when the tap was on
## an animal (it is the debug's, not the hands').
func pick(origin: Vector3, dir: Vector3) -> bool:
	var w = game.wildlife
	if not game.settings.ai_debug or w == null:
		return false
	var best := -1
	var best_d := PICK_REACH
	var d := dir.normalized()
	for id: int in w.minds:
		var a = w.by_id(id)
		if a == null:
			continue
		var mid: Vector3 = a.pos + Vector3(0.0, a.lift + 0.3, 0.0) - origin
		var off := (mid - d * mid.dot(d)).length()
		if off < best_d:
			best_d = off
			best = id
	if best < 0:
		return false
	chosen = -1 if best == chosen else best
	return true


## The words over an animal of species `spec` with mind `m`: its name and what it does,
## its hunger and health; for the one chosen (`full`) the rest too.
static func card(m: Array, spec: Dictionary, full: bool) -> String:
	var lines := ["%s: %s" % [Lang.t(spec.get("title", "?")), doing(m)]]
	lines.append(Lang.f("hunger %d%% · health %d/%d", [roundi(float(m[HUNGER]) * 100.0), m[HEALTH], m[MOST]]))
	if not full:
		return "\n".join(lines)
	if float(m[RAGE]) > 0.0 or float(m[CALM]) > 0.0:
		lines.append(Lang.f("rage %d s · calm %d s", [ceili(m[RAGE]), ceili(m[CALM])]))
	if float(m[HURT]) > 0.0:
		lines.append(Lang.f("runs after a hit %d s more", [ceili(m[HURT])]))
	if float(m[IDLE]) > 0.0:
		lines.append(Lang.f("stands %d s more", [ceili(m[IDLE])]))
	lines.append(Lang.f("sight %d · fears people within %d · growls within %d", [roundi(m[SEEN]), roundi(m[WARY_AT]), roundi(m[CLOSE_AT])]))
	if int(m[OWNER]) >= 0:
		lines.append(Lang.f("tame, owner %d", [m[OWNER]]))
	lines.append(Lang.t("thinks every step: seen") if m[NEAR] else Lang.t("thinks less often: no one sees it"))
	return "\n".join(lines)


## What an animal with mind `m` does, and why, in words.
static func doing(m: Array) -> String:
	var cause: String = m[CAUSE]
	match m[STATE]:
		"flee":
			match cause:
				"person":
					return Lang.t("flees a person")
				"fire":
					return Lang.t("flees fire")
				"hurt":
					return Lang.t("flees the place of a hit")
				"alarm":
					return Lang.t("flees: the pack is alarmed")
			return Lang.f("flees: %s", [_kind_title(cause)])
		"hunt":
			return Lang.f("hunts: %s", [_kind_title(cause)])
		"rest":
			return Lang.t("sleeps: not its time")
		"warn":
			return Lang.t("growls at a person")
		"charge":
			return Lang.t("hunts a person") if cause == "hunt_person" else Lang.t("drives a person off")
		"bite":
			return Lang.t("bites")
		"bait":
			return Lang.t("swims to the float")
	if float(m[IDLE]) > 0.0:
		return Lang.t("stands")
	match cause:
		"graze":
			return Lang.t("goes to graze")
		"lead":
			return Lang.t("follows the leader")
		"owner":
			return Lang.t("with its owner")
	return Lang.t("wanders")


static func _kind_title(kind: String) -> String:
	return Lang.t(AiRules.SPECIES.get(kind, {}).get("title", kind))
