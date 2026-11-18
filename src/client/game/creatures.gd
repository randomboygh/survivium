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
## ground (one with none, a butterfly, sits still, slowly beating its wings), and `attack` frames after those its attack
## (as it leaps to bite, the first while it warns one off, see Wildlife._fights);
## the frames left are idle ones (a tail flicked, the head bent down) shown now
## and then while it stands. Which
## view and which way is worked out here from how it moved on the screen: the server
## sends only where it is. A species with `tints` has its picture multiplied by one of
## them for each animal. A fish (Wildlife.dives) is drawn after the water, all of it in
## the water's colour, the more the deeper it swims (sprite_water.gdshader `whole`, its
## sprite's material_overlay); its own picture only casts its shadow on the bed. Under
## ice it shows faint, clearer under clear ice (IceView gives its materials the ice).

const Content := preload("res://src/shared/content/content.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")
const UnderwaterShader := preload("res://shaders/sprite_water.gdshader")
const Wildlife := preload("res://src/shared/game/wildlife.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const CELL := WorldData.CELL

## Frames of a wing beat a second.
const FLAP_RATE := 12.0
## Frames a second of the wing beat of a flyer sitting still (see Wildlife.sits_still),
## seconds it sits with its wings still between two flutters, and how long a flutter lasts:
## each on its own clock, so they do not all flap at once.
const SIT_FLAP_RATE := 4.0
const SIT_GAP := Vector2(3.0, 9.0)
const SIT_FLUTTER := Vector2(0.5, 1.2)
## World units round a sprite's culling box for what the shaders move a little (the
## half pixel snap); the box is also widened by half the sprite's width, where the
## shadow pass turns the quad to face the light.
const CULL_MARGIN := 0.5
## A sprite's box is fitted again only when its height changes by more than this (world
## units): the shear moves a box by its height alone, so a walk on the level keeps it,
## and the box is grown by the shear of this much in the steepest slope (PixelView
## view_of: 2 at the lowest tilt). Every animal that moved used to be fitted each frame,
## the views of a whole turn round each time while the camera spun.
const FIT_SLACK := 0.5
const FIT_GROW := FIT_SLACK * 2.0
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
## Seconds each attack frame of a bite shows (Wildlife.BITE_TIME over three frames).
const BITE_FRAME := 0.13


## How an animal is drawn now: its view, which way it goes, how far it has walked (for
## its steps) and its idle frame.
class Look:
	var animal
	var sprite: MeshInstance3D
	var view := SIDE
	## 1 facing right on the screen, -1 left (the side view mirrored).
	var side := 0.0
	var last := Vector3.ZERO
	var walked := 0.0
	var idle := 0
	var change_at := 0.0
	## Till when a flyer sitting still flutters its wings (0 while they are still).
	var flutter_end := 0.0
	## The sprite's scale.x last put (0 before the first): set only when it changes.
	var flip := 0.0
	## When its bite began to be drawn (-1: it does not bite now).
	var bite_at := -1.0
	## A fish: how deep under the surface it was last drawn (world units, see _sink;
	## -1 for the others).
	var depth := -1.0


var wildlife
## The world (WorldData) the fish swim in: the water over them (see _sink).
var world
## Footprints (see tracks.gd); animals leave paw prints sized by their mass.
var tracks
## The performance statistics (PerfPanel), told how long the animals take a frame.
var perf
## kind -> [mesh, materials: for each of its tints (one, white, for none) one a view and
## frame (view * frames + frame), the size of the body its first frame shows (world
## units, see body_size), frames a row, frames of its walk, views, hop frames, attack
## frames, a fish's materials drawn over those after the water (as the materials; empty
## for the others)]
var looks := {}
var _sprites := {}
var _looks := {}
## The Looks of all the animals drawn, walked every frame (no lookups by animal).
var _shown: Array[Look] = []
## sprite -> the height its culling box was fitted at, and the views it was fitted for.
var _fitted := {}
var _views: Array = []
var _rng := RandomNumberGenerator.new()


## Draws the animals of `w` (RemoteWildlife) from now on, those there already and those to come.
func watch(w) -> void:
	_build_looks()
	wildlife = w
	for a in w.animals:
		_on_born(a)
	w.born.connect(_on_born)
	w.gone.connect(_on_gone)
	w.stepped.connect(_on_stepped)


## The species read anew (a hot reload, ModReload): their pictures, frames and tints
## again, and every animal drawn with them.
func relook() -> void:
	_build_looks()
	if wildlife == null:
		return
	for look in _shown.duplicate():
		var a = look.animal
		if not looks.has(a.kind):
			# Its species is gone from the data: the server takes it out too (Wildlife.reread).
			_on_gone(a)
			continue
		look.sprite.mesh = looks[a.kind][0]
		look.view = SIDE
		a.frame = 0
		_show(a, look.sprite, 0)
		_fit(a, look.sprite)


func _build_looks() -> void:
	looks = {}
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var spec: Dictionary = AiRules.SPECIES[kind]
		var tex: Texture2D = picture(spec)
		var frames: int = spec.frames
		var views: int = spec.get("views", 1)
		var tints: Array = spec.tints if not spec.tints.is_empty() else [Color.WHITE]
		var variants := []
		var overs := []
		var fish := Wildlife.dives(spec)
		for tint: Color in tints:
			var mats := []
			var over := []
			for v in views:
				for f in frames:
					var m := PlayerScript.sprite_material(SpriteShader, tex)
					var uv := Vector4(float(f) / frames, float(v) / views, 1.0 / frames, 1.0 / views)
					if fish:
						# Its own picture only casts the shadow on the bed; the fish is drawn
						# over it after the water, which is drawn at priority 0 (as Player.underwater).
						m.set_shader_parameter("shadow_only", 1.0)
						var w := PlayerScript.sprite_material(UnderwaterShader, tex)
						w.render_priority = 1
						w.set_shader_parameter("whole", 1.0)
						w.set_shader_parameter("frame_uv", uv)
						w.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
						over.append(w)
					m.set_shader_parameter("frame_uv", uv)
					m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
					if spec.flies and f >= 1 and f <= walk_frames(spec):
						# A wing beat in the air: its shadow is the front's frame laid flat, a bird
						# seen from above (sprite.gdshader flat_shadow), not its profile turned to the sun.
						var front := FRONT if views > FRONT else v
						m.set_shader_parameter("flat_shadow", 2.0 if v == SIDE and views > FRONT else 1.0)
						m.set_shader_parameter("shadow_uv", Vector4(float(f) / frames, float(front) / views, 1.0 / frames, 1.0 / views))
					mats.append(m)
			variants.append(mats)
			overs.append(over)
		looks[kind] = [PixelView.sprite_mesh(tex.get_width() / frames, tex.get_height() / views), variants,
			body_size(tex, frames, views), frames, walk_frames(spec), views, mini(spec.get("hop", 0), frames - 1 - walk_frames(spec)),
			mini(spec.get("attack", 0), frames - 1 - walk_frames(spec)), overs if fish else []]


## How many frames of species `spec`'s picture are its walk (or wing beat).
static func walk_frames(spec: Dictionary) -> int:
	var walk: int = spec.get("walk", -1)
	return spec.frames - 1 if walk < 0 else mini(walk, spec.frames - 1)


func _process(delta: float) -> void:
	if wildlife == null:
		return
	var t := Time.get_ticks_usec()
	if wildlife.has_method("glide"):
		# The server's animals over a socket move between their snapshots (RemoteWildlife).
		wildlife.glide()
	var now := Time.get_ticks_msec() * 0.001
	var beat := now * FLAP_RATE
	var flip := 1.0 if PixelView.right.x >= 0.0 else -1.0
	if not is_same(_views, PixelView.box_views):
		# The camera turns: every box again, for the views it may show.
		_views = PixelView.box_views
		_fitted.clear()
		for look in _shown:
			_fit(look.animal, look.sprite)
	for look in _shown:
		var a = look.animal
		if a.fresh:
			a.fresh = false
			var sprite := look.sprite
			sprite.position = PixelView.snap(a.pos + Vector3(0.0, a.lift, 0.0))
			if look.depth >= 0.0:
				_sink(a, look)
			if absf(_fitted.get(sprite, INF) - sprite.position.y) > FIT_SLACK:
				_fit(a, sprite)
			_went(a, look, flip)
		elif not a.near:
			# Off every screen (Wildlife.look_from): its picture waits for its next step.
			continue
		elif not (a.flying or a.hop > 0.0) and now < look.change_at:
			# Its walk goes by the way it covered, which changes only when it is fresh.
			continue
		var frame := _frame(a, look, beat, now)
		var shown: int = look.view * looks[a.kind][3] + frame
		if shown != a.frame:
			a.frame = shown
			_show(a, look.sprite, shown)
		var sx := look.side if look.view == SIDE else 1.0
		if sx != look.flip:
			look.flip = sx
			look.sprite.scale.x = sx
	if perf != null:
		perf.note("animals", t)


## Turns animal `a` the way it moved since it was last drawn, and counts its walk.
func _went(a, look: Look, flip: float) -> void:
	var d := Vector2(a.pos.x - look.last.x, a.pos.z - look.last.z)
	var rise: float = a.pos.y - look.last.y
	look.last = a.pos
	var moved := d.length()
	if moved < 0.001:
		if a.perched and not a.flying and absf(rise) > 0.001 and absf(rise) < JUMP:
			# Up or down a trunk (Wildlife._climb): its back to us going up, head first
			# coming down, its paws going.
			look.walked += absf(rise)
			if looks[a.kind][5] >= 3:
				look.view = BACK if rise > 0.0 else FRONT
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
		# posmod: an instance id may be negative, and % of a negative number is negative,
		# which picked frames off the end of the sheet (another view's), so a flyer seemed
		# to spin in the air.
		return 1 + posmod(int(beat) + a.get_instance_id(), walk)
	if a.hop > 0.0 and walk > 1:
		look.idle = 0
		return 1 if a.hop > 0.2 and a.hop < 0.8 else 2
	var hop: int = looks[a.kind][6]
	if spec.flies and spec.get("hop", 0) <= 0 and walk > 0:
		# A flyer that does not hop (a butterfly) sits still with its wings still, and now
		# and then opens and shuts them a few times (at rest, then the first beat).
		look.idle = 0
		if look.flutter_end == 0.0:
			if now < look.change_at:
				return 0
			look.flutter_end = now + _rng.randf_range(SIT_FLUTTER.x, SIT_FLUTTER.y)
		if now < look.flutter_end:
			look.change_at = now + 1.0 / SIT_FLAP_RATE
			return 1 if posmod(int(now * SIT_FLAP_RATE), 2) == 0 else 0
		look.flutter_end = 0.0
		look.change_at = now + _rng.randf_range(SIT_GAP.x, SIT_GAP.y)
		return 0
	var attack: int = looks[a.kind][7]
	if attack > 0 and a.state == "bite":
		# The leap to bite: its attack frames one after another, the
		# last held till it is done (Wildlife.BITE_TIME).
		look.idle = 0
		if look.bite_at < 0.0:
			look.bite_at = now
		look.change_at = now
		return frames - attack + mini(int((now - look.bite_at) / BITE_FRAME), attack - 1)
	look.bite_at = -1.0
	if attack > 0 and a.state == "warn":
		# Warning one off: crouched, its first attack frame.
		look.idle = 0
		look.change_at = now
		return frames - attack
	if a.moving and hop > 0 and spec.flies:
		# Hopping about on the ground: crouched, up (the last frames), sitting.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		var at := int(look.walked / HOP_STEP * (hop + 1)) % (hop + 1)
		return 0 if at == hop else frames - attack - hop + at
	if a.moving and walk > 0 and not spec.flies:
		# Two steps a round of the walk, however many frames it has.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
		var step := 0.25 + 0.3 * size
		return 1 + int(look.walked / step * maxf(walk / 2.0, 1.0)) % walk
	var idles := frames - 1 - walk - hop - attack
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


## Shows frame `shown` (view * frames + frame) of animal `a` on its sprite: a fish's
## drawn over it after the water too (its material_overlay).
func _show(a, sprite: MeshInstance3D, shown: int) -> void:
	sprite.material_override = _mats(a)[shown]
	var overs: Array = looks[a.kind][8]
	if not overs.is_empty():
		var over: Array = overs[a.tint % overs.size()]
		sprite.material_overlay = over[shown]
	elif sprite.material_overlay != null:
		sprite.material_overlay = null


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


## The picture of species `spec` (a record of AiRules.SPECIES); after a hot reload read
## from its file (Content.live).
static func picture(spec: Dictionary) -> Texture2D:
	var at := Content.real(picture_path(spec))
	if Content.live or not at.begins_with("res://"):
		var img := Content.picture(picture_path(spec))
		if img != null:
			return ImageTexture.create_from_image(img)
	return load(at) if at != "" else null


static func picture_path(spec: Dictionary) -> String:
	return Content.asset(spec, "sprites/creatures/%s.png" % spec.sprite)


## The sprite drawn for animal `a`, or null.
func sprite_of(a) -> MeshInstance3D:
	return _sprites.get(a)


## The materials the fish are drawn with over the water (IceView gives them the ice).
func fish_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for kind in looks:
		for over: Array in looks[kind][8]:
			for m: ShaderMaterial in over:
				out.append(m)
	return out


## How deep under the water surface fish `a` swims as drawn (world units), -1 for one
## not drawn or not a fish.
func depth_of(a) -> float:
	var look: Look = _looks.get(a)
	return look.depth if look != null else -1.0


## Where animal `a` breathes out (AirEffects): [its muzzle (world units, unsheared), the
## way it faces (world xz)], high in its body and ahead of its middle the way it is drawn
## facing; empty while it is not drawn or shows its back.
func muzzle(a) -> Array:
	var look: Look = _looks.get(a)
	if look == null or look.view == BACK:
		return []
	var body: Vector2 = looks[a.kind][2]
	var at := look.sprite.position + Vector3(0.0, body.y * 0.7, 0.0)
	if look.view == FRONT:
		var toward := Vector2(-PixelView.up.x, -PixelView.up.y)
		return [at + Vector3(toward.x, 0.0, toward.y) * 0.05, toward]
	var ahead := PixelView.right * look.side
	return [at + Vector3(ahead.x, 0.0, ahead.y) * body.x * 0.45, ahead]


func _on_born(a) -> void:
	if not looks.has(a.kind):
		# A species the client's data does not have (a server with other data).
		return
	var sprite := MeshInstance3D.new()
	sprite.mesh = looks[a.kind][0]
	_show(a, sprite, 0)
	# The player's real shadow from a fire falls on it with «Тень на вещах» (PixelView.LAYER_THINGS).
	sprite.layers = PixelView.LAYER_THINGS
	sprite.position = PixelView.snap(a.pos + Vector3(0.0, a.lift, 0.0))
	add_child(sprite)
	_sprites[a] = sprite
	var look := Look.new()
	look.animal = a
	look.sprite = sprite
	look.last = a.pos
	look.side = a.facing * (1.0 if PixelView.right.x >= 0.0 else -1.0)
	look.change_at = Time.get_ticks_msec() * 0.001 + _rng.randf_range(0.0, IDLE_GAP.y)
	_looks[a] = look
	_shown.append(look)
	look.flip = look.side
	sprite.scale.x = look.side
	if Wildlife.dives(AiRules.SPECIES[a.kind]):
		look.depth = 0.0
		_sink(a, look)
	_fit(a, sprite)


## Tells fish `a`'s picture how deep under the water surface (or the ice) over it it
## swims: by the sprite's scale along y past 1 (sprite_water.gdshader `whole`), set only
## when it changes by a texel row.
func _sink(a, look: Look) -> void:
	var under := 0.0
	if world != null:
		var bits: int = world.water_col(floori(a.pos.x / CELL), floori(a.pos.z / CELL))
		if bits != 0:
			var top := WorldData.top_level(bits)
			var surface: float = float(top) if world.frozen_at(floori(a.pos.x / CELL), floori(a.pos.z / CELL)) else top + world.water_top(top)
			under = maxf(0.0, surface * CELL - a.pos.y)
	if absf(under - look.depth) * PixelView.PIXELS_PER_UNIT >= 0.5 or look.depth == 0.0:
		look.depth = maxf(under, 0.001)
		look.sprite.scale.y = 1.0 + look.depth


func _on_gone(a) -> void:
	if not _sprites.has(a):
		return
	_fitted.erase(_sprites[a])
	_sprites[a].queue_free()
	_sprites.erase(a)
	_shown.erase(_looks[a])
	_looks.erase(a)


## Fits the culling box of animal `a`'s sprite to where the shaders draw it (sheared by
## its height), so a sprite off the screen is not drawn; even about x, as the sprite
## is mirrored to face the other way.
func _fit(a, sprite: MeshInstance3D) -> void:
	var at := sprite.position
	var mesh_box: AABB = looks[a.kind][0].get_aabb()
	var box := PixelView.sheared_box(AABB(at + mesh_box.position, mesh_box.size), CULL_MARGIN + FIT_GROW + mesh_box.size.x * 0.5)
	box.position -= at
	var half := maxf(-box.position.x, box.end.x)
	sprite.custom_aabb = AABB(Vector3(-half, box.position.y, box.position.z), Vector3(2.0 * half, box.size.y, box.size.z))
	_fitted[sprite] = at.y


func _on_stepped(_a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	if tracks != null:
		tracks.leave(at, dir, left, false, size)
