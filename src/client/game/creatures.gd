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
## and then while it stands, or with `idle_anim` one idle animation played through
## now and then; after the attack `run` frames of its gallop, played by the way it
## covers while it flees, hunts or charges (RUNS), `hurt` ones of its flinch at a blow,
## and `death` ones. One with frames of death lies where it fell on the last of them
## till its carcass is taken: the carcass on the ground names the species (`body`,
## ActionsFight._wound), and this draws it (show_bodies, asked by Props), playing the
## death first when it fell in view, as the blow that killed it lands. Which
## view and which way is worked out here from how it moved on the screen: the server
## sends only where it is. A species with `tints` has its picture multiplied by one of
## them for each animal. A fish (Wildlife.dives) is drawn after the water, all of it in
## the water's colour, the more the deeper it swims (sprite_water.gdshader `whole`, its
## sprite's material_overlay); its own picture only casts its shadow on the bed. Under
## ice it shows faint, clearer under clear ice (IceView gives its materials the ice).
## An animal struck flinches as the blow meets it (flinch, struck_at): its picture jerks
## up and away from the one who struck and shakes back, in whole pixels.

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
## Seconds each frame of an idle animation shows (a species with `idle_anim`).
const IDLE_FRAME := 0.35
## The states in which one with `run` frames gallops: at its full speed, as it flees,
## hunts or charges (it goes about at a third of it, Wildlife._move).
const RUNS := ["flee", "hunt", "charge"]
## The way a round of the run covers, in rounds of the walk's way (two steps): the
## boar's four frames of gallop a stride of 2.4 world units, 0.12 s each at its full speed.
const RUN_ROUND := 2.2
## Seconds each frame of its flinch at a blow shows, and each frame of its death (the
## last stays).
const HURT_FRAME := 0.15
const DEATH_FRAME := 0.2
## A body (a carcass naming the species, see show_bodies) and the beast it was come in
## either order, the carcass with the chunk's things on the ground and the beast's going
## with the animals: each waits BODY_WAIT seconds for the other, taken for it within
## BODY_REACH world units.
const BODY_REACH := 1.5
const BODY_WAIT := 1.0
## Seconds a body that took its beast's sprite with no blow on it known waits before it
## falls: the reply naming the blow that killed it comes after the beast's going (its
## kill is done at once, Wildlife.hurt) and tells when the blade meets it (felled).
const BLOW_WAIT := 0.15
## An animal struck flinches (the user's ask, 2026-11-20) as the weapon meets it, frames 3
## and 4 of the swing: its picture jerks FLINCH_UP pixels up, down again over FLINCH_JERK
## seconds (seen on one that bolts at once, Wildlife.hurt), and FLINCH_PX pixels along the
## screen away from the one who struck, then shakes to and fro, FLINCH_HZ times a second,
## dying away by FLINCH_DAMP, still after FLINCH_TIME seconds. A blow at a point (another
## player's, struck_at) is taken by the animal drawn within FLINCH_SLACK of where blows
## land on it (BLOW_HEIGHT over its feet; the copy lags the server a little) whose striker
## stood within STRIKE_REACH of its body, with FLINCH_SLACK to spare.
const FLINCH_PX := 2.0
const FLINCH_UP := 2.0
const FLINCH_JERK := 0.1
const FLINCH_HZ := 7.0
const FLINCH_DAMP := 7.0
const FLINCH_TIME := 0.25
const FLINCH_SLACK := 0.75
## As it flinches it flashes red (the user's ask, 2026-11-21: drawn by sprite.gdshader,
## not into its frames): wholly for FLASH_HOLD seconds, then fading by
## PixelView.FLASH_STEPS steps, gone after FLASH_TIME (no longer than FLINCH_TIME).
const FLASH_HOLD := 0.08
const FLASH_TIME := 0.22
const BLOW_HEIGHT := 0.3
const STRIKE_REACH := 1.4
## Blows waiting to land at once, at most.
const BLOWS_MOST := 16


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
	## Seconds since it flinched at a blow (while in Creatures._flinching), and which way
	## along the screen it jolted first (1 right, -1 left).
	var flinch := 0.0
	var flinch_side := 1.0
	## When its hurt frames began (-1: it is not hurt now, see _flinch_step).
	var hurt_at := -1.0
	## The body lying where it fell (show_bodies), waiting for it to go; null.
	var body: Body = null


## A beast killed lying where it fell till its carcass is taken (show_bodies).
class Body:
	var kind := ""
	var tint := 0
	## Where the carcass lies, and the way the beast went (world xz).
	var at := Vector3.ZERO
	var way := Vector2.RIGHT
	## Its sprite: none while it waits for the beast it was (`look`) to go, whose own it
	## takes then.
	var sprite: MeshInstance3D = null
	var look: Look = null
	var view := SIDE
	## 1 facing right on the screen, -1 left.
	var side := 1.0
	## When its death begins to be drawn: INF while it waits for the beast (till
	## `wait_until`), -INF for one that lay there before it came in view.
	var dies_at := -INF
	var wait_until := 0.0
	## The id of the beast it was, once it took its sprite (-1 before; see felled).
	var beast := -1
	## Its frame of death drawn (-1: none yet).
	var frame := -1


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
## for the others), run frames, hurt frames, death frames, whether its idle frames are
## one animation]
var looks := {}
var _sprites := {}
var _looks := {}
## The Looks of all the animals drawn, walked every frame (no lookups by animal).
var _shown: Array[Look] = []
## sprite -> the height its culling box was fitted at, and the views it was fitted for.
var _fitted := {}
var _views: Array = []
var _rng := RandomNumberGenerator.new()
## [seconds left, Look, the striker's position] of blows not yet landed, and the Looks
## flinching now (walked every frame while there are any).
var _blows := []
var _flinching: Array[Look] = []
## chunk -> {[species, where] -> Body}: the bodies lying in the chunks drawn (show_bodies).
var _bodies := {}
## The bodies dying or waiting for their beasts now (walked every frame while there are
## any), and the Looks of beasts with frames of death gone a moment ago, waiting for
## their bodies with their sprites as they were: [Look, till when].
var _dying: Array[Body] = []
var _fallen := []


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
	var now := Time.get_ticks_msec() * 0.001
	for key: Vector2i in _bodies:
		var lying: Dictionary = _bodies[key]
		for id: Array in lying.keys():
			var b: Body = lying[id]
			if not looks.has(b.kind):
				_lift(b)
				lying.erase(id)
			elif b.sprite != null:
				b.sprite.mesh = looks[b.kind][0]
				b.frame = -1
				_draw_body(b, now)
				_fit_sprite(b.sprite, looks[b.kind][0])


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
		var after := frames - 1 - walk_frames(spec)
		looks[kind] = [PixelView.sprite_mesh(tex.get_width() / frames, tex.get_height() / views), variants,
			body_size(tex, frames, views), frames, walk_frames(spec), views, mini(spec.get("hop", 0), after),
			mini(spec.get("attack", 0), after), overs if fish else [], mini(spec.get("run", 0), after),
			mini(spec.get("hurt", 0), after), mini(spec.get("death", 0), after), spec.get("idle_anim", false) == true]


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
		# The camera turns: every box again, for the views it may show; the bodies turned.
		_views = PixelView.box_views
		_fitted.clear()
		for look in _shown:
			_fit(look.animal, look.sprite)
		_turn_bodies(now)
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
	if not _blows.is_empty() or not _flinching.is_empty():
		_flinch_step(delta)
	if not _dying.is_empty() or not _fallen.is_empty():
		_bodies_step(now)
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
	var k: Array = looks[a.kind]
	var frames: int = k[3]
	var walk: int = k[4]
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	# The run, the hurt and the death come last in the row (see looks).
	var run: int = k[9]
	var hurt: int = k[10]
	var tail: int = run + hurt + k[11]
	if look.hurt_at >= 0.0 and hurt > 0:
		# Flinching at a blow (_flinch_step): its hurt frames one after another.
		var at := int((now - look.hurt_at) / HURT_FRAME)
		if at < hurt:
			look.idle = 0
			look.change_at = look.hurt_at + (at + 1) * HURT_FRAME
			return frames - hurt - k[11] + at
		look.hurt_at = -1.0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
	if a.flying and walk > 0:
		look.idle = 0
		# posmod: an instance id may be negative, and % of a negative number is negative,
		# which picked frames off the end of the sheet (another view's), so a flyer seemed
		# to spin in the air.
		return 1 + posmod(int(beat) + a.get_instance_id(), walk)
	if a.hop > 0.0 and walk > 1:
		look.idle = 0
		return 1 if a.hop > 0.2 and a.hop < 0.8 else 2
	var hop: int = k[6]
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
	var attack: int = k[7]
	if attack > 0 and a.state == "bite":
		# The leap to bite: its attack frames one after another, the
		# last held till it is done (Wildlife.BITE_TIME).
		look.idle = 0
		if look.bite_at < 0.0:
			look.bite_at = now
		look.change_at = now
		return frames - tail - attack + mini(int((now - look.bite_at) / (Wildlife.BITE_TIME / attack)), attack - 1)
	look.bite_at = -1.0
	if attack > 0 and a.state == "warn":
		# Warning one off: crouched, its first attack frame.
		look.idle = 0
		look.change_at = now
		return frames - tail - attack
	if a.moving and hop > 0 and spec.flies:
		# Hopping about on the ground: crouched, up (the last frames), sitting.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		if spec.get("walks", false):
			# A flyer that walks on the ground (the grouse): its hop frames are steps, two a
			# round of the walk, as a walker's.
			var stride := 0.25 + 0.3 * clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
			return frames - tail - attack - hop + int(look.walked / stride * maxf(hop / 2.0, 1.0)) % hop
		var at := int(look.walked / HOP_STEP * (hop + 1)) % (hop + 1)
		return 0 if at == hop else frames - tail - attack - hop + at
	if a.moving and walk > 0 and not spec.flies:
		# Two steps a round of the walk, however many frames it has; a round of the run
		# RUN_ROUND of those.
		look.idle = 0
		look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
		var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
		var step := 0.25 + 0.3 * size
		if run > 0 and a.state in RUNS:
			return frames - tail + int(look.walked / (step * 2.0 * RUN_ROUND) * run) % run
		return 1 + int(look.walked / step * maxf(walk / 2.0, 1.0)) % walk
	var idles := frames - 1 - walk - hop - attack - tail
	if idles <= 0 or now < look.change_at:
		return look.idle
	if k[12]:
		# One idle animation: played through now and then, back to standing.
		if look.idle == 0:
			look.idle = 1 + walk
		elif look.idle < walk + idles:
			look.idle += 1
		else:
			look.idle = 0
			look.change_at = now + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
			return 0
		look.change_at = now + IDLE_FRAME
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


## Animal `a` (of the copy) is struck by one standing at `from` (world units): it flinches
## in `delay` seconds, as the blow lands (Controls._did: one's own blow, the server's reply
## names the animal).
func flinch(a, delay: float, from: Vector3) -> void:
	var look: Look = _looks.get(a)
	if look == null or _blows.size() >= BLOWS_MOST:
		return
	_blows.append([delay, look, from])


## The animal with `id`, gone from the copy before the reply naming one's own blow came
## (Controls._did: the blow killed it), is struck in `delay` seconds: its body, still
## waiting to fall, falls as the blow lands.
func felled(id: int, delay: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for b in _dying:
		if b.beast == id and now < b.dies_at and b.dies_at != INF:
			b.dies_at = now + maxf(delay, 0.0)


## A blow aimed at world point `at` by one standing at `from` lands in `delay` seconds
## (Others: another player's work, so nothing new goes over the net): the animal drawn
## there flinches, if one is (see FLINCH_SLACK). A point inside a solid cell (a trunk
## chopped, the ground dug) is no blow at an animal.
func struck_at(at: Vector3, delay: float, from: Vector3) -> void:
	if not at.is_finite() or _blows.size() >= BLOWS_MOST:
		return
	if world != null and world.is_solid(floori(at.x / CELL), floori(at.y / CELL), floori(at.z / CELL)):
		return
	var best: Look = null
	var best_d := FLINCH_SLACK
	for look in _shown:
		var a = look.animal
		if not a.near or a.aloft():
			continue
		var d: float = (a.pos + Vector3(0.0, BLOW_HEIGHT, 0.0)).distance_to(at)
		if d > best_d:
			continue
		var reach: float = STRIKE_REACH + Wildlife.radius(AiRules.SPECIES[a.kind]) + FLINCH_SLACK
		if Vector2(a.pos.x - from.x, a.pos.z - from.z).length() > reach:
			continue
		best = look
		best_d = d
	if best != null:
		_blows.append([delay, best, from])


## The blows landing and the animals flinching this frame: a flinching one's picture is
## put where it stands, moved by its jerk and shake and flashed red; put back when done.
func _flinch_step(delta: float) -> void:
	for i in range(_blows.size() - 1, -1, -1):
		var b: Array = _blows[i]
		b[0] -= delta
		if b[0] > 0.0:
			continue
		_blows.remove_at(i)
		var look: Look = b[1]
		if not _looks.has(look.animal):
			# Gone by then (the blow that killed it).
			continue
		var from: Vector3 = b[2]
		var a = look.animal
		var s: Vector2 = PixelView.screen_dir(Vector2(a.pos.x - from.x, a.pos.z - from.z))
		look.flinch_side = 1.0 if s.x >= 0.0 else -1.0
		if not _flinching.has(look):
			_flinching.append(look)
		# The time since it landed, once this frame's is added below.
		look.flinch = -b[0] - delta
		if looks[a.kind][10] > 0:
			# Its hurt frames from now on (_frame).
			look.hurt_at = Time.get_ticks_msec() * 0.001
			look.change_at = 0.0
	var right := Vector3(PixelView.right.x, 0.0, PixelView.right.y) / PixelView.PIXELS_PER_UNIT
	for i in range(_flinching.size() - 1, -1, -1):
		var look := _flinching[i]
		var a = look.animal
		look.flinch += delta
		var px := Vector2.ZERO
		var red := 0
		if look.flinch < FLINCH_TIME:
			px = flinch_px(look.flinch)
			px.x *= look.flinch_side
			red = flash_step(look.flinch)
		else:
			_flinching.remove_at(i)
		if red != PixelView.sprite_flash(look.sprite):
			PixelView.flash_sprite(look.sprite, red)
		look.sprite.position = PixelView.snap(a.pos + Vector3(0.0, a.lift, 0.0)) + right * px.x \
			+ Vector3(0.0, px.y / PixelView.PIXELS_PER_UNIT, 0.0)


## How far an animal that flinched `t` seconds ago is moved, in whole pixels: x along the
## screen away from the blow (less than 0: back toward it), a jolt at once, then a
## to-and-fro dying away; y up, a jerk at once, down again over FLINCH_JERK.
static func flinch_px(t: float) -> Vector2:
	return Vector2(roundf(FLINCH_PX * exp(-t * FLINCH_DAMP) * cos(t * FLINCH_HZ * TAU)),
		roundf(FLINCH_UP * maxf(0.0, 1.0 - t / FLINCH_JERK)))


## How red an animal that flinched `t` seconds ago flashes, in PixelView.FLASH_STEPS-ths.
static func flash_step(t: float) -> int:
	if t < 0.0 or t >= FLASH_TIME:
		return 0
	var left := clampf((FLASH_TIME - t) / (FLASH_TIME - FLASH_HOLD), 0.0, 1.0)
	return ceili(PixelView.FLASH_STEPS * left)


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
	var look: Look = _looks[a]
	var sprite: MeshInstance3D = _sprites[a]
	_fitted.erase(sprite)
	_flinching.erase(look)
	_sprites.erase(a)
	_shown.erase(look)
	_looks.erase(a)
	var now := Time.get_ticks_msec() * 0.001
	if look.body == null:
		look.body = _waiting(look)
	if look.body != null:
		# It fell, and its body lies there already: it takes the sprite.
		_adopt(look.body, look, now)
	elif looks.has(a.kind) and looks[a.kind][11] > 0 and a.near:
		# It may have fallen: its body comes with the things on the ground (show_bodies),
		# drawn as it is till then.
		_fallen.append([look, now + BODY_WAIT])
	else:
		sprite.queue_free()


## Fits the culling box of animal `a`'s sprite to where the shaders draw it (sheared by
## its height), so a sprite off the screen is not drawn; even about x, as the sprite
## is mirrored to face the other way, and about z (PixelView.shade_sprite).
func _fit(a, sprite: MeshInstance3D) -> void:
	_fit_sprite(sprite, looks[a.kind][0])
	_fitted[sprite] = sprite.position.y


## Fits the culling box of `sprite` drawing `mesh` where it stands (see _fit).
static func _fit_sprite(sprite: MeshInstance3D, mesh: Mesh) -> void:
	var at := sprite.position
	var mesh_box: AABB = mesh.get_aabb()
	var box := PixelView.sheared_box(AABB(at + mesh_box.position, mesh_box.size), CULL_MARGIN + FIT_GROW + mesh_box.size.x * 0.5)
	box.position -= at
	var half := maxf(-box.position.x, box.end.x)
	# Even about z too: the sprite's scale along z (a shade, a red flash) only grows it then.
	var deep := maxf(-box.position.z, box.end.z)
	sprite.custom_aabb = AABB(Vector3(-half, box.position.y, -deep), Vector3(2.0 * half, box.size.y, 2.0 * deep))


## Whether thing `d` lying on the ground (WorldData.drops) is a body drawn here rather than
## its item's model (Props): a carcass naming a species with frames of death.
static func is_body(d: Array) -> bool:
	if d.size() < 4 or not d[3] is Dictionary or not d[3].has("body"):
		return false
	var spec: Dictionary = AiRules.SPECIES.get(str(d[3].body), {})
	return int(spec.get("death", 0)) > 0


## Draws the bodies among the things lying in chunk `key` (`list`, its WorldData.drops) as
## they are now; one no longer there was taken. One new fell just now (its beast goes
## with it, see _on_gone) and plays its death, unless the chunk `came` in view just now
## with it lying there.
func show_bodies(key: Vector2i, list: Array, came := false) -> void:
	_lay_bodies(key, list, came, Time.get_ticks_msec() * 0.001)


func _lay_bodies(key: Vector2i, list: Array, came: bool, now: float) -> void:
	if looks.is_empty():
		_build_looks()
	var was: Dictionary = _bodies.get(key, {})
	var lying := {}
	for d: Array in list:
		if not is_body(d) or not looks.has(str(d[3].body)):
			continue
		var id := [str(d[3].body), d[1]]
		if was.has(id):
			lying[id] = was[id]
			was.erase(id)
		elif not lying.has(id):
			lying[id] = _lay(d, not came, now)
	for b: Body in was.values():
		_lift(b)
	if lying.is_empty():
		_bodies.erase(key)
	else:
		_bodies[key] = lying


## Whether the body of drop `d` in chunk `key` is still falling (its death drawn, or its
## beast not gone yet): the action button waits till it lies (Controls._front_body).
func falling(key: Vector2i, d: Array) -> bool:
	if not is_body(d):
		return false
	var b: Body = _bodies.get(key, {}).get([str(d[3].body), d[1]])
	return b != null and _dying.has(b)


## Takes away the bodies of chunk `key`, gone out of view (Props.hide_drops).
func hide_bodies(key: Vector2i) -> void:
	for b: Body in _bodies.get(key, {}).values():
		_lift(b)
	_bodies.erase(key)


## A body for carcass `d` (see show_bodies); `fresh`: it fell just now.
func _lay(d: Array, fresh: bool, now: float) -> Body:
	var b := Body.new()
	b.kind = str(d[3].body)
	b.tint = int(d[3].get("tint", 0))
	b.at = d[1]
	b.way = Vector2.from_angle(float(d[2]))
	_face(b)
	if fresh:
		var look := _beast_of(b)
		if look != null and _looks.has(look.animal):
			# Its beast is drawn still: it falls as it goes (_on_gone).
			look.body = b
			b.look = look
			b.dies_at = INF
			b.wait_until = now + BODY_WAIT
			_dying.append(b)
			return b
		if look != null:
			_adopt(b, look, now)
			return b
	# One whose beast was not drawn (killed out of view, or the carcass moved) lies dead.
	_own_sprite(b, now)
	return b


## The Look of the beast body `b` was: the nearest of its kind within BODY_REACH, drawn
## (without a body yet) or gone a moment ago (_fallen); null for none.
func _beast_of(b: Body) -> Look:
	var best: Look = null
	var best_d := BODY_REACH
	var near: Array[Look] = []
	for look in _shown:
		if look.body == null:
			near.append(look)
	for f: Array in _fallen:
		near.append(f[0])
	for look in near:
		var a = look.animal
		var d: float = Vector2(a.pos.x - b.at.x, a.pos.z - b.at.z).length()
		if a.kind == b.kind and d < best_d:
			best = look
			best_d = d
	return best


## A body waiting for another beast of `look`'s kind (show_bodies took the nearest drawn
## for it) that `look`, gone now, was: within BODY_REACH of it; null for none.
func _waiting(look: Look) -> Body:
	for b in _dying:
		var a = look.animal
		if b.dies_at == INF and b.kind == a.kind and Vector2(a.pos.x - b.at.x, a.pos.z - b.at.z).length() < BODY_REACH:
			if b.look != null:
				b.look.body = null
			b.look = look
			return b
	return null


## Body `b` takes the sprite of its beast (`look`, gone): drawn as it was till the blow
## that killed it lands (a blow on it still in _blows, else BLOW_WAIT for the reply that
## tells it, felled), then its death.
func _adopt(b: Body, look: Look, now: float) -> void:
	for i in range(_fallen.size() - 1, -1, -1):
		if _fallen[i][0] == look:
			_fallen.remove_at(i)
	look.body = null
	b.look = null
	if b.sprite != null and b.sprite != look.sprite:
		b.sprite.queue_free()
	b.sprite = look.sprite
	# Put back from a flinch it was in (_on_gone ended it): where it stands, not red.
	b.sprite.position = PixelView.snap(look.animal.pos + Vector3(0.0, look.animal.lift, 0.0))
	PixelView.flash_sprite(b.sprite, 0)
	b.view = look.view
	b.side = look.side if look.view == SIDE else 1.0
	b.frame = -1
	var lands := -1.0
	for blow: Array in _blows:
		if blow[1] == look:
			lands = maxf(lands, blow[0])
	b.dies_at = now + (lands if lands >= 0.0 else BLOW_WAIT)
	b.beast = look.animal.id
	if not _dying.has(b):
		_dying.append(b)
	_fit_sprite(b.sprite, looks[b.kind][0])


## Body `b` on a sprite of its own, where its carcass lies.
func _own_sprite(b: Body, now: float) -> void:
	b.sprite = MeshInstance3D.new()
	b.sprite.mesh = looks[b.kind][0]
	b.sprite.layers = PixelView.LAYER_THINGS
	b.sprite.position = PixelView.snap(b.at)
	add_child(b.sprite)
	b.frame = -1
	_draw_body(b, now)
	_fit_sprite(b.sprite, looks[b.kind][0])


## Body `b`'s view and side from the way its beast went, as the camera looks now.
func _face(b: Body) -> void:
	var s := PixelView.screen_dir(b.way)
	var views: int = looks[b.kind][5]
	if views >= 2 and absf(s.y) > absf(s.x):
		b.view = FRONT if s.y > 0.0 or views < 3 else BACK
	else:
		b.view = SIDE
	b.side = 1.0 if s.x >= 0.0 else -1.0


## Draws body `b`'s frame of death at time `now`, the last once it is over (nothing before
## it begins), flashed red as the blow that killed it lands, as a flinch is (_flinch_step);
## whether it is over.
func _draw_body(b: Body, now: float) -> bool:
	if b.sprite == null or now < b.dies_at:
		return false
	var k: Array = looks[b.kind]
	var death: int = k[11]
	var f := death - 1 if b.dies_at == -INF else mini(int((now - b.dies_at) / DEATH_FRAME), death - 1)
	var red := 0 if b.dies_at == -INF else flash_step(now - b.dies_at)
	if red != PixelView.sprite_flash(b.sprite):
		PixelView.flash_sprite(b.sprite, red)
	if f != b.frame:
		b.frame = f
		var variants: Array = k[1]
		b.sprite.material_override = variants[b.tint % variants.size()][b.view * k[3] + k[3] - death + f]
		b.sprite.material_overlay = null
		b.sprite.scale.x = b.side if b.view == SIDE else 1.0
	return f == death - 1 and red == 0


## The bodies dying or waiting for their beasts at time `now`, and the beasts gone that
## waited for their bodies in vain (not killed, or no carcass came).
func _bodies_step(now: float) -> void:
	for i in range(_dying.size() - 1, -1, -1):
		var b := _dying[i]
		if b.dies_at == INF:
			if now < b.wait_until:
				continue
			# Its beast did not go (another of its kind stood there): it falls on its own.
			if b.look != null:
				b.look.body = null
				b.look = null
			b.dies_at = now
			_own_sprite(b, now)
		if _draw_body(b, now):
			_dying.remove_at(i)
	for i in range(_fallen.size() - 1, -1, -1):
		if now >= _fallen[i][1]:
			(_fallen[i][0] as Look).sprite.queue_free()
			_fallen.remove_at(i)


## Every body turned to the camera as it looks now.
func _turn_bodies(now: float) -> void:
	for key: Vector2i in _bodies:
		for b: Body in _bodies[key].values():
			if b.sprite == null:
				continue
			_face(b)
			b.frame = -1
			_draw_body(b, now)
			_fit_sprite(b.sprite, looks[b.kind][0])


## Body `b` is gone: taken up, or out of view.
func _lift(b: Body) -> void:
	_dying.erase(b)
	if b.look != null:
		b.look.body = null
		b.look = null
	if b.sprite != null:
		b.sprite.queue_free()
		b.sprite = null


func _on_stepped(_a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	if tracks != null:
		tracks.leave(at, dir, left, false, size)
