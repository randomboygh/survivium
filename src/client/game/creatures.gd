extends Node3D
## The animals drawn (the rules are Wildlife, src/shared): a sprite for each, put where
## it walks and turned the way it faces, and the paw prints it leaves (see tracks.gd).
## Animals off the screen move in steps (Wildlife.FAR_STEP), and their sprites are
## put again only then. A species' picture is its mod's sprites/creatures/<sprite>.png,
## a row of `frames` frames: the first is the animal at rest, the others its walk (or
## its swim), one per step, or a flyer's wing beat in the air.

const Content := preload("res://src/shared/content/content.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")

## Animals off the screen by more than this many world units are not near (see
## Wildlife.Animal.near).
const FAR_MARGIN := 4.0
## Frames of a wing beat a second.
const FLAP_RATE := 12.0
## World units round a sprite's culling box for what the shaders move a little (the
## half pixel snap); the box is also widened by half the sprite's width, where the
## shadow pass turns the quad to face the light.
const CULL_MARGIN := 0.5

var wildlife
## Footprints (see tracks.gd); animals leave paw prints sized by their mass.
var tracks
## The performance statistics (PerfPanel), told how long the animals take a frame.
var perf
## kind -> [mesh, materials, one a frame]
var looks := {}
var _sprites := {}
## sprite -> where its culling box was fitted, and the views it was fitted for.
var _fitted := {}
var _views: Array = []


## Draws the animals of `w` (Wildlife) from now on, those there already and those to come.
func watch(w) -> void:
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var spec: Dictionary = AiRules.SPECIES[kind]
		var tex: Texture2D = picture(spec)
		var frames: int = spec.frames
		var mats := []
		for f in frames:
			var m := PlayerScript.sprite_material(SpriteShader, tex)
			m.set_shader_parameter("frame_uv", Vector4(float(f) / frames, 0.0, 1.0 / frames, 1.0))
			mats.append(m)
		looks[kind] = [PixelView.sprite_mesh(tex.get_width() / frames, tex.get_height()), mats]
	wildlife = w
	for a in w.animals:
		_on_born(a)
	w.born.connect(_on_born)
	w.gone.connect(_on_gone)
	w.stepped.connect(_on_stepped)


func _process(delta: float) -> void:
	if wildlife == null:
		return
	var t := Time.get_ticks_usec()
	var seen := _seen()
	for a in wildlife.animals:
		a.near = seen.has_point(PixelView.screen_plane(a.pos))
	wildlife.update(delta)
	var beat := Time.get_ticks_msec() * 0.001 * FLAP_RATE
	if _views != PixelView.box_views:
		# The camera turns: every box again, for the views it may show.
		_views = PixelView.box_views
		_fitted.clear()
		for a in wildlife.animals:
			_fit(a, _sprites[a])
	for a in wildlife.animals:
		if a.away == 0.0:
			var sprite: MeshInstance3D = _sprites[a]
			sprite.position = PixelView.snap(a.pos)
			if _fitted.get(sprite) != sprite.position:
				_fit(a, sprite)
			# Facing east or west in the world, which way on the screen.
			sprite.scale.x = a.facing * (1.0 if PixelView.right.x >= 0.0 else -1.0)
			if a.flying or a.moving or a.frame != 0:
				var mats: Array = looks[a.kind][1]
				var frame := 0
				if a.flying and mats.size() > 1:
					frame = 1 + (int(beat) + a.get_instance_id()) % (mats.size() - 1)
				elif a.moving and mats.size() > 1 and not AiRules.SPECIES[a.kind].flies:
					# A walk of two frames, one a step; a flyer only hops on the ground.
					frame = 1 + (1 if a.left else 0) % (mats.size() - 1)
				if frame != a.frame:
					a.frame = frame
					sprite.material_override = mats[frame]
	if perf != null:
		perf.note("животные", t)


## The picture of species `spec` (a record of AiRules.SPECIES).
static func picture(spec: Dictionary) -> Texture2D:
	return load(picture_path(spec))


static func picture_path(spec: Dictionary) -> String:
	return Content.asset(spec, "sprites/creatures/%s.png" % spec.sprite)


## The screen-plane rectangle the camera shows, FAR_MARGIN larger all round (all of
## the plane without a camera).
func _seen() -> Rect2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var half := get_viewport().get_visible_rect().size / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * FAR_MARGIN
	var centre := PixelView.plane_of(Vector2(cam.global_position.x, cam.global_position.z))
	return Rect2(centre - half, half * 2.0)


## The sprite drawn for animal `a`, or null.
func sprite_of(a) -> MeshInstance3D:
	return _sprites.get(a)


func _on_born(a) -> void:
	var sprite := MeshInstance3D.new()
	sprite.mesh = looks[a.kind][0]
	sprite.material_override = looks[a.kind][1][0]
	sprite.position = PixelView.snap(a.pos)
	add_child(sprite)
	_sprites[a] = sprite
	_fit(a, sprite)


func _on_gone(a) -> void:
	_fitted.erase(_sprites[a])
	_sprites[a].queue_free()
	_sprites.erase(a)


## Fits the culling box of animal `a`'s sprite to where the shaders draw it (sheared by
## its height), so a sprite off the screen is not drawn; even about x, as the sprite
## is mirrored to face the other way.
func _fit(a, sprite: MeshInstance3D) -> void:
	var at := sprite.position
	var mesh_box: AABB = looks[a.kind][0].get_aabb()
	var box := PixelView.sheared_box(AABB(at + mesh_box.position, mesh_box.size), CULL_MARGIN + mesh_box.size.x * 0.5)
	box.position -= at
	var half := maxf(-box.position.x, box.end.x)
	sprite.custom_aabb = AABB(Vector3(-half, box.position.y, box.position.z), Vector3(2.0 * half, box.size.y, box.size.z))
	_fitted[sprite] = at


func _on_stepped(_a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	if tracks != null:
		tracks.leave(at, dir, left, false, size)
