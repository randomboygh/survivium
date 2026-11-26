extends Node
## A tree answers a blow of the axe (the user's ask, 2026-11-19): its crown shudders, a
## quick shake from side to side that dies away, and a few leaves come off and flutter
## down, as the axe meets the trunk (frame 3 of the chop, STRIKE of the swing). Seen for
## one's own blows (Controls._did) and for other players' (Others, from the work their
## snapshots carry), so nothing new goes over the net.
## The shake is drawn by leaves.gdshader (and tree.gdshader for the trees drawn as
## pictures, the picture leaning the more the higher): `shakes` holds up to SHAKES trees, each the
## foot of its trunk (xyz) and how far its crown leans now in pixels (w); a card leans by
## its distance from the trunk and its height. The trunk itself stays put. Cheap: one
## array set on one material while a tree shakes, a pool of LEAF_EMITTERS small emitters.
## Held by Effects (`trees`).

const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
const PX := 1.0 / 16.0
## The share of a chop's swing where the axe meets the trunk: frame 3 of 4, the crouch
## (docs/planning/character-animations.md), as Controls.STRIKE.
const STRIKE := 0.5
## Trees shaking at once (leaves.gdshader `shakes` is this long).
const SHAKES := 4
## The shake: how far the top of the crown leans at first (pixels), how many times a
## second it goes to and fro, how fast it dies away, and when it is over (seconds).
const SHAKE_PX := 3.0
const SHAKE_HZ := 6.0
const SHAKE_DAMP := 4.5
const SHAKE_TIME := 0.8
## Leaves off a crown in full leaf at one blow, more in autumn; a conifer drops a few
## needles. Their flight (seconds), their pull down (less the air's hold, damping) and
## how hard they leave the crown.
const LEAVES_MOST := 20
const AUTUMN_MORE := 1.6
const NEEDLES_SHARE := 0.4
const LEAF_TIME := 3.2
const LEAF_FALL := 1.0
const LEAF_PUSH := Vector2(0.15, 0.6)
const LEAF_CURVE := 0.8
const LEAF_EMITTERS := 3
## How far round its trunk a crown is looked for (cells, each way).
const CROWN_REACH := 6
## A felled tree drawn as a picture falls (decision 4А of the trees' redraw: away from the
## one who felled it, in about a second): turning over faster and faster to FALL_ANGLE in
## FALL_TIME, a little bounce of FALL_BOUNCE back up and down in BOUNCE_TIME, then fading out
## in FADE_TIME (the logs and twigs lie where it fell). FALLS at once (tree.gdshader `falls`).
const FALLS := 4
const FALL_TIME := 1.0
const FALL_ANGLE := PI / 2.0
const FALL_BOUNCE := 0.06
const BOUNCE_TIME := 0.25
const FADE_TIME := 0.4

var game
var fx
## [seconds left, trunk cell, the one who struck's position] of blows not yet landed.
var _waiting := []
## [foot of the trunk, sign of the first lean, seconds since] of the trees shaking.
var _shaking := []
## Whether the material was last left with a shake on it.
var _set := false
var _emitters: Array[CPUParticles3D] = []
## [node, foot, way (x, z), seconds since] of the trees falling.
var _falling := []
## Column -> where the last blow on its trunk was struck from (the way it falls, `fall`).
var _struck := {}
var _next := 0


func _init(g, effects) -> void:
	game = g
	fx = effects


## A blow of the axe on the trunk at world point `at` lands in `delay` seconds, struck
## from world point `from`. Anything but a living tree's trunk there is left alone, and
## so is a tree gone by then (the blow that felled it).
func hit(at: Vector3, delay: float, from: Vector3) -> void:
	if not at.is_finite() or _waiting.size() >= SHAKES * 2:
		return
	_waiting.append([delay, Vector3i((at / CELL).floor()), from])


## The pictured tree of column `col` was felled: its picture (`data`, TreeSprites.build's
## instance: 20 floats) falls away from where the last blow came (from the player's own
## place when none was seen).
func fall(col: Vector2i, data: PackedFloat32Array) -> void:
	if game.get("tree_mat") == null or data.size() < 20:
		return
	if _falling.size() >= FALLS:
		_end_fall(0)
	var foot := Vector3(data[3], data[7], data[11])
	var from: Vector3 = _struck.get(col, game.player.position if game.get("player") != null else foot)
	_struck.erase(col)
	var way := Vector2(foot.x - from.x, foot.z - from.z)
	if way.length() < 0.01:
		way = Vector2.from_angle(float(hash(col) % 628) / 100.0)
	var node := Foliage.multimesh(game.tree_mesh, game.tree_mat, true, true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh.instance_count = 1
	node.multimesh.buffer = data
	# Lying, it reaches as far as it stood high.
	var r := 16.0
	node.custom_aabb = AABB(foot + Vector3(-r, -1.0, -r), Vector3(2.0 * r, r, 2.0 * r))
	game.world_root.add_child(node)
	_falling.append([node, foot, way.normalized(), 0.0])


## The fall's turn (radians) and fade (0..1) `t` seconds after it began.
static func fall_at(t: float) -> Vector2:
	if t < FALL_TIME:
		var k := t / FALL_TIME
		return Vector2(FALL_ANGLE * k * k, 0.0)
	t -= FALL_TIME
	if t < BOUNCE_TIME:
		return Vector2(FALL_ANGLE - FALL_BOUNCE * sin(PI * t / BOUNCE_TIME), 0.0)
	return Vector2(FALL_ANGLE, clampf((t - BOUNCE_TIME) / FADE_TIME, 0.0, 1.0))


func _end_fall(i: int) -> void:
	var f: Array = _falling[i]
	f[0].queue_free()
	_falling.remove_at(i)


func _process_falls(delta: float) -> void:
	if _falling.is_empty() and game.get("tree_mat") == null:
		return
	var falls := PackedVector4Array()
	var ways := PackedVector4Array()
	falls.resize(FALLS)
	ways.resize(FALLS)
	for i in range(_falling.size() - 1, -1, -1):
		_falling[i][3] += delta
		if _falling[i][3] >= FALL_TIME + BOUNCE_TIME + FADE_TIME:
			_end_fall(i)
	for i in _falling.size():
		var f: Array = _falling[i]
		var at := fall_at(f[3])
		falls[i] = Vector4(f[1].x, f[1].y, f[1].z, at.x)
		ways[i] = Vector4(f[2].x, f[2].y, 0.0, at.y)
	if game.tree_mat != null and (not _falling.is_empty() or _fall_set):
		game.tree_mat.set_shader_parameter("falls", falls)
		game.tree_mat.set_shader_parameter("fall_ways", ways)
		game.tree_mat.set_shader_parameter("fall_count", _falling.size())
	_fall_set = not _falling.is_empty()


var _fall_set := false


func _process(delta: float) -> void:
	_process_falls(delta)
	for i in range(_waiting.size() - 1, -1, -1):
		var w: Array = _waiting[i]
		w[0] -= delta
		if w[0] <= 0.0:
			_waiting.remove_at(i)
			_land(w[1], w[2])
	if _shaking.is_empty() and not _set:
		return
	var shakes := PackedVector4Array()
	shakes.resize(SHAKES)
	for i in range(_shaking.size() - 1, -1, -1):
		var s: Array = _shaking[i]
		s[2] += delta
		if s[2] >= SHAKE_TIME:
			_shaking.remove_at(i)
	for i in _shaking.size():
		var s: Array = _shaking[i]
		var t: float = s[2]
		var lean: float = s[1] * SHAKE_PX * exp(-t * SHAKE_DAMP) * sin(t * SHAKE_HZ * TAU)
		shakes[i] = Vector4(s[0].x, s[0].y, s[0].z, lean)
	_set = not _shaking.is_empty()
	# The crowns of cards and the trees drawn as pictures (tree.gdshader) alike.
	for mat: ShaderMaterial in [game.leaves_mat, game.tree_mat]:
		if mat != null:
			mat.set_shader_parameter("shakes", shakes)
			mat.set_shader_parameter("shake_count", _shaking.size())


## The tree whose trunk holds `cell`, as [its column, species], or [] for none.
func _tree_of(cell: Vector3i) -> Array:
	var w = game.world
	if w == null or w.get_cell(cell.x, cell.y, cell.z) != Mat.LOG:
		return []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var col := Vector2i(cell.x + dx, cell.z + dz)
			if w.trees.has(col) and w.log_col(col.x, col.y) != 0:
				return [col, w.trees[col]]
	return []


func _land(cell: Vector3i, from: Vector3) -> void:
	var tree := _tree_of(cell)
	if tree.is_empty():
		return
	var col: Vector2i = tree[0]
	if _struck.size() > 64:
		_struck.clear()
	_struck[col] = from
	var logs: int = game.world.log_col(col.x, col.y)
	var foot := Vector3(col.x + 0.5, WorldData.level_of(logs & -logs), col.y + 0.5) * CELL
	# The crown leans first away from the axe, along the screen.
	var side := Vector2(foot.x - from.x, foot.z - from.z).dot(PixelView.right)
	if _shaking.size() >= SHAKES:
		_shaking.pop_front()
	_shaking.append([foot, 1.0 if side >= 0.0 else -1.0, 0.0])
	_set = true
	_drop_leaves(col, int(tree[1]))


## A few leaves of tree `col` of `species` off its crown, by the season.
func _drop_leaves(col: Vector2i, species: int) -> void:
	if not fx.enabled or species < 0 or species >= Trees.SPECIES.size():
		return
	var looks: Dictionary = Trees.SPECIES[species]
	if looks.dead:
		return
	var w = game.world
	var leaves := 0
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for dz in range(-CROWN_REACH, CROWN_REACH + 1):
		for dx in range(-CROWN_REACH, CROWN_REACH + 1):
			var bits: int = w.leaf_col(col.x + dx, col.y + dz)
			if bits == 0:
				continue
			leaves |= bits
			x0 = minf(x0, dx)
			x1 = maxf(x1, dx + 1)
			z0 = minf(z0, dz)
			z1 = maxf(z1, dz + 1)
	if leaves == 0:
		return
	var low := WorldData.level_of(leaves & -leaves)
	var high := low
	for k in range(low + 1, 63):
		if leaves & (1 << k) != 0:
			high = k
	var sky = game.sky
	var needles: bool = looks.leaves == Trees.NEEDLES and looks.bare == 0.0
	var amount: float = sky.leaf_amount
	if needles:
		amount = (0.35 + 0.65 * amount) * NEEDLES_SHARE
	elif Foliage.goes_bare(col, species):
		amount = maxf(0.0, amount - 0.55) / 0.15 * 0.7 if amount < 0.7 else amount
	else:
		amount = 0.35 + 0.65 * amount
	if game.clock != null and game.clock.season == 2 and not needles:
		amount *= AUTUMN_MORE
	var n := roundi(LEAVES_MOST * amount)
	if n < 1:
		return
	# The colour of the crown (Foliage, leaves.gdshader): the tree's tint by the season,
	# toned toward grey as the leaves are.
	var tints: Array = looks.tints
	var c: Color = tints[hash(col) % tints.size()]
	var f: Vector3 = sky.foliage
	c = Color(c.r * f.x, c.g * f.y, c.b * f.z)
	var grey := c.r * 0.3 + c.g * 0.55 + c.b * 0.15
	c = Color(grey, grey, grey).lerp(c, 0.6)
	var p := _emitter()
	p.amount = n
	p.color_ramp = fx._ramp([c.lightened(0.25), c, c.darkened(0.3)])
	# Off the lower half of the crown at its edge toward the camera, drifting out toward
	# it, so they are seen falling, not hidden behind the leaves.
	var toward := -PixelView.up
	var mid := Vector3(col.x + (x0 + x1) * 0.5, low + (high + 1 - low) * 0.35, col.y + (z0 + z1) * 0.5) * CELL
	var near := toward * (z1 - z0) * 0.5 * CELL
	p.position = mid + Vector3(near.x, 0.0, near.y)
	p.emission_box_extents = Vector3((x1 - x0) * 0.35, (high + 1 - low) * 0.2, 0.1) * CELL
	p.direction = Vector3(toward.x, -0.5, toward.y)
	var light := clampf(maxf(sky.sky_light, sky.flash), 0.12, 1.0)
	((p.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter("light", light)
	p.restart()


func _emitter() -> CPUParticles3D:
	if _emitters.size() < LEAF_EMITTERS:
		var e: CPUParticles3D = fx._emitter(LEAVES_MOST * 2, LEAF_TIME, Vector2(2.0 * PX, 2.0 * PX), 1.0)
		fx.remove_child(e)
		add_child(e)
		e.one_shot = true
		e.explosiveness = 0.75
		e.randomness = 0.5
		e.lifetime_randomness = 0.35
		e.spread = 70.0
		e.initial_velocity_min = LEAF_PUSH.x
		e.initial_velocity_max = LEAF_PUSH.y
		# The air holds them back: they drift down slowly, not drop.
		e.damping_min = 0.3
		e.damping_max = 0.6
		e.gravity = Vector3(0.0, -LEAF_FALL, 0.0)
		# Each one curves its own way as it flutters down.
		e.tangential_accel_min = -LEAF_CURVE
		e.tangential_accel_max = LEAF_CURVE
		# A leaf two pixels across, now and then one.
		e.scale_amount_min = 0.7
		e.scale_amount_max = 1.0
		(e.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_emitters.append(e)
	var p := _emitters[_next]
	_next = (_next + 1) % LEAF_EMITTERS
	return p

