extends Node3D
## The animals drawn (the rules are Wildlife, src/shared, stepped by the world's
## session on the server; drawn is the client's copy, RemoteWildlife): a sprite for
## each, put where it walks and turned the way it goes, and the paw prints it leaves
## (see tracks.gd). Animals far from the player move in steps (Wildlife.FAR_STEP), and
## their sprites are put again only when the server moved them (Animal.fresh). A
## species' picture is its mod's sprites/creatures/<sprite>.png: a row a view (`views`:
## the side, facing right, mirrored for left; the front, as it comes at the camera; the
## back, as it goes away), each of `frames` frames: the
## first the animal at rest, then `walk` frames of its walk (or swim) played by the way
## it covers, two steps a round, or of a flyer's wing beat in the air; one that hops shows
## the second while in a leap (legs stretched) and the third as it takes off and lands;
## a flyer with `hop` frames (the last ones) hops with them as it goes about on the
## ground; the frames left are idle ones (a tail flicked, the head bent down) shown now
## and then while it stands. Which
## view and which way is worked out here from how it moved on the screen: the server
## sends only where it is. A species with `tints` has its picture multiplied by one of
## them for each animal.

const Content := preload("res://src/shared/content/content.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")

## Frames of a wing beat a second.
const FLAP_RATE := 12.0
## World units round a sprite's culling box for what the shaders move a little (the
## half pixel snap); the box is also widened by half the sprite's width, where the
## shadow pass turns the quad to face the light.
const CULL_MARGIN := 0.5
## How much more one way on the screen than the other a move must go to turn the animal
## from the side to the front or back and again (between the two it keeps its view).
const TURN_BIAS := 1.5
## A move longer than this (world units) between two draws is a jump (a snapshot after
## a gap), not a walk: it turns the animal but plays no steps.
const JUMP := 3.0
## Seconds an animal stands still between idle frames, and how long one lasts; the last
## idle frame of a walker (its head down at the grass) lasts longer.
const IDLE_GAP := Vector2(2.0, 6.0)
const IDLE_HOLD := Vector2(0.4, 0.9)
const IDLE_LONG := Vector2(1.5, 3.5)
## Rows of a picture: the side, the front, the back.
const SIDE := 0
const FRONT := 1
const BACK := 2
## World units a flyer goes on the ground a round of its hop (crouched, up, sitting).
const HOP_STEP := 0.36


## How an animal is drawn now: its view, which way it goes, how far it has walked (for
## its steps) and its idle frame.
class Look:
	var view := SIDE
	## 1 facing right on the screen, -1 left (the side view mirrored).
	var side := 0.0
	var last := Vector3.ZERO
	var walked := 0.0
	var idle := 0
	var change_at := 0.0


var wildlife
## Footprints (see tracks.gd); animals leave paw prints sized by their mass.
var tracks
## The performance statistics (PerfPanel), told how long the animals take a frame.
var perf
## kind -> [mesh, materials: for each of its tints (one, white, for none) one a view and
## frame (view * frames + frame), the size of the body its first frame shows (world
## units, see body_size), frames a row, frames of its walk, views]
var looks := {}
var _sprites := {}
var _looks := {}
## sprite -> where its culling box was fitted, and the views it was fitted for.
var _fitted := {}
var _views: Array = []
var _rng := RandomNumberGenerator.new()


## Draws the animals of `w` (RemoteWildlife) from now on, those there already and those to come.
func watch(w) -> void:
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var spec: Dictionary = AiRules.SPECIES[kind]
		var tex: Texture2D = picture(spec)
		var frames: int = spec.frames
		var views: int = spec.get("views", 1)
		var tints: Array = spec.tints if not spec.tints.is_empty() else [Color.WHITE]
		var variants := []
		for tint: Color in tints:
			var mats := []
			for v in views:
				for f in frames:
					var m := PlayerScript.sprite_material(SpriteShader, tex)
					m.set_shader_parameter("frame_uv", Vector4(float(f) / frames, float(v) / views, 1.0 / frames, 1.0 / views))
					m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
					mats.append(m)
			variants.append(mats)
		looks[kind] = [PixelView.sprite_mesh(tex.get_width() / frames, tex.get_height() / views), variants,
			body_size(tex, frames, views), frames, walk_frames(spec), views, mini(spec.get("hop", 0), frames - 1 - walk_frames(spec))]
	wildlife = w
	for a in w.animals:
		_on_born(a)
	w.born.connect(_on_born)
	w.gone.connect(_on_gone)
	w.stepped.connect(_on_stepped)


## How many frames of species `spec`'s picture are its walk (or wing beat).
static func walk_frames(spec: Dictionary) -> int:
	var walk: int = spec.get("walk", -1)
	return spec.frames - 1 if walk < 0 else mini(walk, spec.frames - 1)


func _process(delta: float) -> void:
	if wildlife == null:
		return
	var t := Time.get_ticks_usec()
	var now := Time.get_ticks_msec() * 0.001
	var beat := now * FLAP_RATE
	var flip := 1.0 if PixelView.right.x >= 0.0 else -1.0
	if _views != PixelView.box_views:
		# The camera turns: every box again, for the views it may show.
		_views = PixelView.box_views
		_fitted.clear()
		for a in wildlife.animals:
			_fit(a, _sprites[a])
	for a in wildlife.animals:
		var sprite: MeshInstance3D = _sprites[a]
		var look: Look = _looks[a]
		if a.fresh:
			a.fresh = false
			sprite.position = PixelView.snap(a.pos + Vector3(0.0, a.lift, 0.0))
			if _fitted.get(sprite) != sprite.position:
				_fit(a, sprite)
			_went(a, look, flip)
		elif not (a.flying or a.moving or a.hop > 0.0) and now < look.change_at:
			continue
		var frame := _frame(a, look, beat, now)
		var shown: int = look.view * looks[a.kind][3] + frame
		if shown != a.frame:
			a.frame = shown
			sprite.material_override = _mats(a)[shown]
		sprite.scale.x = look.side if look.view == SIDE else 1.0
	if perf != null:
		perf.note("животные", t)


## Turns animal `a` the way it moved since it was last drawn, and counts its walk.
func _went(a, look: Look, flip: float) -> void:
	var d := Vector2(a.pos.x - look.last.x, a.pos.z - look.last.z)
	look.last = a.pos
	var moved := d.length()
	if moved < 0.001:
		if look.side == 0.0:
			look.side = a.facing * flip
		return
	if moved < JUMP:
		look.walked += moved
	var s := PixelView.screen_dir(d)
	var views: int = looks[a.kind][5]
	if views >= 2 and absf(s.y) > absf(s.x) * TURN_BIAS:
		look.view = FRONT if s.y > 0.0 or views < 3 else BACK
	elif absf(s.x) > absf(s.y) * TURN_BIAS or views < 2:
		look.view = SIDE
	if absf(s.x) > 0.05 * moved:
		look.side = signf(s.x)
	elif look.side == 0.0:
		look.side = a.facing * flip


## The frame of its row animal `a` shows now.
func _frame(a, look: Look, beat: float, now: float) -> int:
	var frames: int = looks[a.kind][3]
	var walk: int = looks[a.kind][4]
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if a.flying and walk > 0:
		look.idle = 0
		return 1 + (int(beat) + a.get_instance_id()) % walk
	if a.hop > 0.0 and walk > 1:
		look.idle = 0
		return 1 if a.hop > 0.2 and a.hop < 0.8 else 2
	var hop: int = looks[a.kind][6]
	if a.moving and hop > 0 and spec.flies:
		# Hopping about on the ground: crouched, up (the last frames), sitting.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		var at := int(look.walked / HOP_STEP * (hop + 1)) % (hop + 1)
		return 0 if at == hop else frames - hop + at
	if a.moving and walk > 0 and not spec.flies:
		# Two steps a round of the walk, however many frames it has.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
		var step := 0.25 + 0.3 * size
		return 1 + int(look.walked / step * maxf(walk / 2.0, 1.0)) % walk
	var idles := frames - 1 - walk - hop
	if idles <= 0 or now < look.change_at:
		return look.idle
	if look.idle != 0:
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
	else:
		var pick := _rng.randi_range(0, idles - 1)
		look.idle = 1 + walk + pick
		var hold: Vector2 = IDLE_LONG if pick == idles - 1 and idles > 1 and not spec.flies else IDLE_HOLD
		look.change_at = now + _rng.randf_range(hold.x, hold.y)
	return look.idle


## The views' and frames' materials animal `a` is drawn with, in its tint.
func _mats(a) -> Array:
	var variants: Array = looks[a.kind][1]
	return variants[a.tint % variants.size()]


## How wide and how tall the body drawn in the first frame of picture `tex` (of
## `frames` frames side by side) is, in world units: its opaque pixels. An animal's
## drawn shadows are as big (see FireShadows._cast_all), so a new one needs no size.
static func body_size(tex: Texture2D, frames: int, views := 1) -> Vector2:
	var img := tex.get_image()
	if img == null:
		return Vector2(tex.get_width() / frames, tex.get_height() / views) / PixelView.PIXELS_PER_UNIT
	if img.is_compressed():
		img.decompress()
	var w := img.get_width() / frames
	var h := img.get_height() / views
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	if hi.x < 0:
		return Vector2.ZERO
	return Vector2(hi - lo + Vector2i.ONE) / PixelView.PIXELS_PER_UNIT


## The picture of species `spec` (a record of AiRules.SPECIES).
static func picture(spec: Dictionary) -> Texture2D:
	return load(picture_path(spec))


static func picture_path(spec: Dictionary) -> String:
	return Content.asset(spec, "sprites/creatures/%s.png" % spec.sprite)


## The sprite drawn for animal `a`, or null.
func sprite_of(a) -> MeshInstance3D:
	return _sprites.get(a)


func _on_born(a) -> void:
	var sprite := MeshInstance3D.new()
	sprite.mesh = looks[a.kind][0]
	sprite.material_override = _mats(a)[0]
	sprite.position = PixelView.snap(a.pos + Vector3(0.0, a.lift, 0.0))
	add_child(sprite)
	_sprites[a] = sprite
	var look := Look.new()
	look.last = a.pos
	look.side = a.facing * (1.0 if PixelView.right.x >= 0.0 else -1.0)
	look.change_at = Time.get_ticks_msec() * 0.001 + _rng.randf_range(0.0, IDLE_GAP.y)
	_looks[a] = look
	sprite.scale.x = look.side
	_fit(a, sprite)


func _on_gone(a) -> void:
	_fitted.erase(_sprites[a])
	_sprites[a].queue_free()
	_sprites.erase(a)
	_looks.erase(a)


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
