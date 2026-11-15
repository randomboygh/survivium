extends Node3D
## Sunlight among the trees by day (the «Солнечные лучи» setting): shafts of light
## that come out of the crowns along the sun's way to the ground (each starts on the
## tree's middle plane, the upright one through its trunk across the sun's way, inside
## the crown's outline on that plane: a spruce's triangle, a broadleaf's round), the
## sun's flecks where the shafts meet the ground in the crowns' shadows, and specks of dust
## glinting in the shafts. Each tree near the player gets a few of each, placed from
## its column (the same every time); every tree whose light can reach the picture gets
## them, the nearest first, laid out again when the player has moved MOVE world units,
## the camera has turned or the trees have changed. Each tree's light is worked out
## once for the sun's way (again when it has turned TURN), a few trees a frame within
## WORK_US, so neither a walk in a wood nor the sun's turning takes a long frame; the shaders
## (sun_rays.gdshader) draw them. Sky tells how strong and what colour they are and
## where the sun is (see Sky._update_rays). `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const SunRaysShader := preload("res://shaders/sun_rays.gdshader")
const ParticleShader := preload("res://shaders/particle.gdshader")

const CELL := WorldData.CELL
## How far past the picture's edges, in world units, a tree is looked for: its crown
## and shafts reach into the picture from there.
const REACH := 12.0
## The farthest from the player a tree is looked for, in world units.
const FARTHEST := 40.0
## The player moves this far, in world units, before the light is laid out again.
const MOVE := 2.0
## The sun turns this much (the dot of its old and new way, 1 - it) before the light
## is laid out again.
const TURN := 0.0004
## The longest a shaft runs, in world units, when it meets no ground (out over a cliff).
const LONGEST := 48.0
## The thinnest and widest a shaft is, in world units (3 pixels to 13).
const THINNEST := 0.19
const WIDEST := 0.8
const MAX_SHAFTS := 384
const MAX_FLECKS := 512
## The step a shaft is looked along at high over the ground (see _length), in world units.
const COARSE := 3.0
## Floats of one instance in a MultiMesh's buffer: a transform (12) and a colour (4).
const INSTANCE_FLOATS := 16
## Bunches of shafts a tree gets at most, and shafts in a bunch at most.
const BUNCHES := 2
const IN_BUNCH := 4
## How far apart the shafts of a bunch stand at most, along the middle plane (units).
const BUNCH_SPREAD := 0.7
## The least angle below the level a shaft is drawn at in the picture (degrees, see
## steep_way), and the steps of 2 degrees its fall is made steeper by at most.
const STEEP_PICTURE := 25.0
const STEEPEST := 40
## Shafts whose end on the ground crowns hide in the picture are kept this often (0..1):
## a thick wood shows only a few; and how high over the ground is looked for them.
const HIDDEN_KEPT := 0.2
const SEEN_ABOVE := 12.0
## Levels a crown is looked for above the foot of its trunk.
const CROWN_LEVELS := 24
## Columns from the trunk a crown is looked for at the middle of its height.
const CROWN_REACH := 8
## Cells of air in a row past which a crown's outline on its middle plane ends.
const OUTLINE_GAP := 2
## Crowns (and the light of trees) remembered before the memory is cleared.
const MAX_CROWNS := 4096
## Microseconds a frame spends at most on working out the trees' light; while it goes
## on, the light worked out so far is laid out this often (ms).
const WORK_US := 1000
const SHOW_EVERY_MS := 250

var game
## How strong the light is (0 none) and its colour, and the way to the sun.
var amount := 0.0
var color := Color(1.0, 0.95, 0.8)
var to_sun := Vector3.UP
var shafts: MultiMeshInstance3D
var flecks: MultiMeshInstance3D
var motes: CPUParticles3D
var _shaft_mat: ShaderMaterial
var _fleck_mat: ShaderMaterial
## The crowns found: {column: Vector3(foot, top, radius) in world units}.
var _crowns := {}
## Where and for what sun the light was laid out last, and how many trees there were.
var _laid_at := Vector3.INF
var _laid_sun := Vector3.ZERO
var _laid_trees := -1
var _laid_view := []
## The view (up, squash, slope) the trees' light was worked out for.
var _worked_view := []
## The sun's turns so far (each over TURN) and its way at the last: the shafts' way
## down, the way across it along the ground (the trees' middle planes run along it),
## and the shadows' way along the ground.
var _sun_turns := 0
var _down := Vector3.DOWN
var _across := Vector2.RIGHT
## The light of each tree near, worked out for a turn of the sun: {column: see
## _tree_light}.
var _light := {}
## The trunk columns near, nearest first, and the next whose light is to be checked.
var _trees := []
var _next := 0
## The tree whose light is being worked out (see _work_out), null for none.
var _job: TreeJob
## Light was worked out since it was laid out last, and when that was (ms).
var _worked := false
var _shown_at := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_shaft_mat = _material(0)
	_fleck_mat = _material(1)
	shafts = _instances(MAX_SHAFTS, _shaft_mat)
	flecks = _instances(MAX_FLECKS, _fleck_mat)
	motes = CPUParticles3D.new()
	motes.amount = 48
	motes.lifetime = 5.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	motes.emission_points = PackedVector3Array([Vector3.ZERO])
	motes.direction = Vector3.UP
	motes.spread = 180.0
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.08
	motes.gravity = Vector3(0.0, -0.01, 0.0)
	motes.color_ramp = Gradient.new()
	motes.color_ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	motes.color_ramp.colors = PackedColorArray([Color(1, 0.95, 0.8, 0), Color(1, 0.95, 0.8, 1), Color(1, 0.9, 0.7, 1), Color(1, 0.9, 0.7, 0)])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE / PixelView.PIXELS_PER_UNIT
	var m := ShaderMaterial.new()
	m.shader = ParticleShader
	m.set_shader_parameter("brightness", 1.3)
	quad.material = m
	motes.mesh = quad
	motes.extra_cull_margin = 32.0
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.emitting = false
	add_child(motes)
	PixelView.blank_particles(motes)


func _material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SunRaysShader
	m.set_shader_parameter("mode", mode)
	return m


func _instances(count: int, mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders put each one where it falls in the view.
	node.extra_cull_margin = 16384.0
	add_child(node)
	return node


## A quad x -0.5..0.5, y 0..1, which the shader lays along a shaft or on the ground.
static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_delta: float) -> void:
	var on := amount > 0.0 and game != null and game.player != null and to_sun.y > 0.05
	shafts.visible = on
	flecks.visible = on
	if motes.emitting != on:
		motes.emitting = on
	if not on:
		return
	var t := Time.get_ticks_usec()
	var down := _shaft_way()
	for m in [_shaft_mat, _fleck_mat]:
		m.set_shader_parameter("amount", amount)
		m.set_shader_parameter("light_color", color)
		m.set_shader_parameter("light_down", down)
	var view := _view()
	if to_sun.dot(_laid_sun) <= 1.0 - TURN or view.slice(0, 3) != _worked_view:
		# The sun or the view (which shafts show depends on it, see _seen) has turned:
		# every tree's light is worked out anew, a few a frame, and laid out once all
		# are (the old light stays until then).
		_worked_view = view.slice(0, 3)
		_laid_sun = to_sun
		_down = down
		var flat := Vector2(down.x, down.z)
		_across = Vector2(-flat.y, flat.x).normalized() if flat.length() > 0.01 else Vector2.RIGHT
		_sun_turns += 1
		_next = 0
	var p: Vector3 = game.player.position
	var near := _near(p)
	var count := _tree_count(near)
	if p.distance_to(_laid_at) >= MOVE or count != _laid_trees or view != _laid_view:
		_laid_at = p
		_laid_trees = count
		_laid_view = view
		_trees = _trees_near(p, near)
		_next = 0
		_lay_out(p, near)
	else:
		_work_out(t)
		if _worked and (_next >= _trees.size() or Time.get_ticks_msec() - _shown_at >= SHOW_EVERY_MS):
			_lay_out(p, near)
	if game.hud != null:
		game.hud.perf.note("sun rays", t)


## Works out the light of the trees near whose light is not of the sun now, the
## nearest first, until `budget` microseconds have gone since `t0`.
func _work_out(t0: int, budget := WORK_US) -> void:
	var w = game.world
	while Time.get_ticks_usec() - t0 < budget:
		if _job != null:
			# A tree's shafts are looked along one a call: each looks at the ground many
			# times, a whole tree was 5-11 ms on a phone.
			if _job.turn != _sun_turns:
				_job = null
			elif _shaft_step(w, _job):
				_light[_job.col] = _job_light(_job)
				_job = null
				_worked = true
			continue
		if _next >= _trees.size():
			break
		var col: Vector2i = _trees[_next]
		_next += 1
		var had: Array = _light.get(col, [])
		if not had.is_empty() and had[0] == _sun_turns:
			continue
		if _light.size() > MAX_CROWNS:
			_light.clear()
		_job = _plan(w, col)
		if _job == null:
			_light[col] = [_sun_turns]
			_worked = true


## Works out the light of all the trees near at once and lays it out (the screenshots,
## which take a picture before the game would have worked it all out); false when the
## light is off.
func finish() -> bool:
	if not shafts.visible or game == null or game.player == null:
		return false
	var p: Vector3 = game.player.position
	var near := _near(p)
	_trees = _trees_near(p, near)
	_laid_view = _view()
	_next = 0
	_work_out(Time.get_ticks_usec(), 1 << 40)
	_lay_out(p, near)
	return true


## What of the view the light's place in the picture goes by.
func _view() -> Array:
	return [PixelView.up, PixelView.squash, PixelView.slope, game.view.image_size]


## The way the shafts run down in the view now (see steep_way).
func _shaft_way() -> Vector3:
	return steep_way(to_sun, PixelView.up, PixelView.squash, PixelView.slope)


## The way of the sun's light from `sun` (the way to the sun) as a shaft runs, in the
## view `up`, `squash`, `slope` (PixelView.set_view): the sun's own way when the
## picture draws it falling at least STEEP_PICTURE below the level, else the same way
## across the ground falling steeper, just so steep. The camera looks down from the
## south: the sun's own light either runs nearly level in the picture (a morning sun in
## the east), or away behind the crowns (a higher one), or up the picture (afternoon).
static func steep_way(sun: Vector3, up: Vector2, squash: float, slope: float) -> Vector3:
	var level := Vector2(-sun.x, -sun.z)
	var across := level.normalized() if level.length() > 0.001 else Vector2(0.0, 1.0)
	var rise := asin(clampf(sun.y, 0.05, 1.0))
	var way := Vector3.ZERO
	for i in STEEPEST:
		way = Vector3(across.x * cos(rise), -sin(rise), across.y * cos(rise))
		if picture_fall(way, up, squash, slope) >= STEEP_PICTURE:
			break
		rise = minf(rise + deg_to_rad(2.0), deg_to_rad(88.0))
	return way


## How far below the level, in degrees, the view `up`, `squash`, `slope`
## (PixelView.set_view) draws a light running `way`: 90 straight down the picture,
## 0 level across it, below 0 going up it.
static func picture_fall(way: Vector3, up: Vector2, squash: float, slope: float) -> float:
	var flat := Vector2(way.x, way.z)
	var drawn := flat + up * (flat.dot(up) * (squash - 1.0) + slope * way.y)
	if drawn.length() < 0.001:
		return 0.0
	return rad_to_deg(atan2(drawn.dot(-up), absf(drawn.dot(Vector2(-up.y, up.x)))))


## The picture in screen-plane world units, grown by MOVE (the player walks that far
## before the light is laid out again), and how far from the player a tree whose
## light reaches it can stand: Rect2 and the distance.
func _near(p: Vector3) -> Array:
	var half: Vector2 = Vector2(game.view.image_size) / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * MOVE
	var picture := Rect2(PixelView.screen_plane(p) - half, half * 2.0)
	return [picture, minf(FARTHEST, half.length() / minf(PixelView.squash, 1.0) + REACH)]


## How many trees stand within the distance of `near` (see _near) of the player:
## counted by chunk, so a change shows.
func _tree_count(near: Array) -> int:
	var n := 0
	for key: Vector2i in _chunks(near[1]):
		n += game.world.tree_chunks.get(key, {}).size()
	return n


func _chunks(reach: float) -> Array:
	var p: Vector3 = game.player.position
	var c0 := Vector2i(floori((p.x - reach) / CELL) >> WorldData.SHIFT, floori((p.z - reach) / CELL) >> WorldData.SHIFT)
	var c1 := Vector2i(floori((p.x + reach) / CELL) >> WorldData.SHIFT, floori((p.z + reach) / CELL) >> WorldData.SHIFT)
	var out := []
	for kz in range(c0.y, c1.y + 1):
		for kx in range(c0.x, c1.x + 1):
			out.append(Vector2i(kx, kz))
	return out


## The trunk columns within the distance of `near`, nearest to the player first.
func _trees_near(p: Vector3, near: Array) -> Array:
	var reach: float = near[1]
	var cols := []
	# Sorted as whole numbers: the distance squared (64ths of a unit) over the index.
	var keys := PackedInt64Array()
	for key: Vector2i in _chunks(reach):
		for col: Vector2i in game.world.tree_chunks.get(key, {}):
			var d := Vector2((col.x + 0.5) * CELL - p.x, (col.y + 0.5) * CELL - p.z).length_squared()
			if d < reach * reach:
				keys.append((int(d * 64.0) << 24) | cols.size())
				cols.append(col)
	keys.sort()
	var out := []
	out.resize(keys.size())
	for i in keys.size():
		out[i] = cols[keys[i] & 0xFFFFFF]
	return out


## The light of the tree with its trunk in column `col` for the sun now, wherever the
## picture is, worked out at once (see _plan, _shaft_step, _job_light).
func _tree_light(w, col: Vector2i) -> Array:
	var job := _plan(w, col)
	if job == null:
		return [_sun_turns]
	while not _shaft_step(w, job):
		pass
	return _job_light(job)


## The light of one tree being worked out (see _plan): what is known of it so far.
class TreeJob:
	var col: Vector2i
	## The sun's turn (_sun_turns) it is for.
	var turn := 0
	var foot := 0.0
	## The shafts still to be looked along: [top, look, where its two specks of dust
	## are along it (0..1)] each, and the next of them.
	var shafts := []
	var next := 0
	var shaft_data := PackedFloat32Array()
	var fleck_data := PackedFloat32Array()
	var dust := PackedVector3Array()
	var box := AABB()


## Starts the light of the tree with its trunk in column `col` for the sun now: the
## shafts' tops and looks; null without a crown. Its shafts'
## lengths are found by _shaft_step, and _job_light gives the light: [the sun's turn
## (_sun_turns), the shafts' and the flecks' instance data as MultiMesh.buffer has it
## (INSTANCE_FLOATS each), two specks of dust a shaft, the box (world) round all of it,
## and the screen-plane rectangle of that box with the view it was worked out for
## (see _shown_rect)].
func _plan(w, col: Vector2i) -> TreeJob:
	var crown := _crown(w, col)
	if crown.x <= -INF:
		return null
	var job := TreeJob.new()
	job.col = col
	job.turn = _sun_turns
	var foot := crown.x
	job.foot = foot
	var mid := Vector2((col.x + 0.5) * CELL, (col.y + 0.5) * CELL)
	job.box = AABB(Vector3(mid.x, foot, mid.y), Vector3.ZERO)
	var outline := _outline(w, col, crown)
	var rng := _rng
	rng.seed = hash(col)
	# Each shaft draws all its numbers first, so the rest of the tree's stay
	# the same whether this one is there or not.
	# Shafts come in bunches through one gap in the leaves: one wide among narrow ones,
	# bright ones beside pale ones, shimmering nearly together (phases close).
	for b in BUNCHES:
		var skip := rng.randf() < 0.25
		# From the middle plane, inside the crown's outline on it.
		var place := _in_outline(outline, rng.randf(), rng.randf(), WIDEST)
		var count := rng.randi_range(2, IN_BUNCH)
		var phase := rng.randf()
		var bright_first := rng.randf() < 0.5
		var bunch := []
		for i in IN_BUNCH:
			var wide := i == 0
			var width := rng.randf_range(0.45, WIDEST) if wide else rng.randf_range(THINNEST, 0.35)
			var bright := (i % 2 == 0) == bright_first
			var strength := rng.randf_range(0.75, 1.0) if bright else rng.randf_range(0.3, 0.55)
			var offset := rng.randf_range(-1.0, 1.0) * BUNCH_SPREAD
			var look := Color(width, 0.0, fposmod(phase + rng.randf_range(-0.08, 0.08), 1.0), strength)
			bunch.append([offset, look, Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)), rng.randf()])
		if skip or place.y <= -INF:
			continue
		for i in count:
			var look: Color = bunch[i][1]
			# Kept inside the level's outline.
			var x := clampf(place.x + bunch[i][0], place.z + look.r * 0.5, place.w - look.r * 0.5) \
				if place.z + look.r < place.w else place.x
			job.shafts.append([Vector3(mid.x + _across.x * x, foot + place.y, mid.y + _across.y * x), look, bunch[i][2], bunch[i][3]])
	return job


## Looks along the next shaft of `job` to the ground; true when it has none left.
func _shaft_step(w, job: TreeJob) -> bool:
	if job.next >= job.shafts.size():
		return true
	var shaft: Array = job.shafts[job.next]
	job.next += 1
	var top: Vector3 = shaft[0]
	var length := _length(w, top, job.foot)
	# Only where the ground it falls on shows in the picture (a glade), and a few
	# (HIDDEN_KEPT) where crowns nearer the camera hide it (a thick wood).
	var keep: float = shaft[3]
	if length >= 1.0 and length < LONGEST and keep >= HIDDEN_KEPT and not _seen(w, top + _down * length):
		length = 0.0
	if length >= 1.0:
		var look: Color = shaft[1]
		var motes_at: Vector2 = shaft[2]
		look.g = length * -_down.y
		_put(job.shaft_data, top, look)
		job.box = job.box.expand(top).expand(top + _down * length)
		job.dust.append(top + _down * (motes_at.x * length))
		job.dust.append(top + _down * (motes_at.y * length))
		# Its fleck where it meets the ground, in the crown's shadow (the shaft came
		# through the crown): none for a shaft that met no ground.
		if length < LONGEST:
			_put(job.fleck_data, top + _down * length, Color(look.r, 0.0, look.b, look.a))
	return job.next >= job.shafts.size()


## The light `job` worked out (see _plan).
func _job_light(job: TreeJob) -> Array:
	return [job.turn, job.shaft_data, job.fleck_data, job.dust, job.box, Rect2(), null]


## Adds one instance at `at` in `look` to MultiMesh data `data`: a transform (no turn)
## and a colour, as MultiMesh.buffer lays them out.
static func _put(data: PackedFloat32Array, at: Vector3, look: Color) -> void:
	data.append_array(PackedFloat32Array([1.0, 0.0, 0.0, at.x, 0.0, 1.0, 0.0, at.y, 0.0, 0.0, 1.0, at.z,
		look.r, look.g, look.b, look.a]))


## The screen-plane rectangle round the box of tree light `light` (see _tree_light),
## kept for the view `view` it was worked out for.
static func _shown_rect(light: Array, view: Array) -> Rect2:
	if light[6] == view:
		return light[5]
	var box: AABB = light[4]
	var rect := Rect2(PixelView.screen_plane(box.position), Vector2.ZERO)
	for i in range(1, 8):
		rect = rect.expand(PixelView.screen_plane(box.get_endpoint(i)))
	light[5] = rect
	light[6] = view
	return rect


## Lays the light of the trees near (as far as it is worked out) out in the picture
## round the player at `p`: the shafts and flecks that show in it, the nearest trees'
## first.
func _lay_out(p: Vector3, near: Array) -> void:
	_worked = false
	_shown_at = Time.get_ticks_msec()
	var picture: Rect2 = near[0]
	var shaft_data := PackedFloat32Array()
	var fleck_data := PackedFloat32Array()
	var dust := PackedVector3Array()
	var shaft_room := MAX_SHAFTS * INSTANCE_FLOATS
	var fleck_room := MAX_FLECKS * INSTANCE_FLOATS
	for col: Vector2i in _trees:
		var light: Array = _light.get(col, [])
		if light.size() < 7:
			continue
		# A tree whose light shows in the picture at all brings all of it (the shaders
		# draw nothing off the screen): one test a tree, its data copied whole.
		if not picture.intersects(_shown_rect(light, _laid_view).grow(1.0)):
			continue
		var shafts_of: PackedFloat32Array = light[1]
		if not shafts_of.is_empty() and shaft_data.size() + shafts_of.size() <= shaft_room:
			shaft_data.append_array(shafts_of)
			dust.append_array(light[3])
		var flecks_of: PackedFloat32Array = light[2]
		if not flecks_of.is_empty() and fleck_data.size() + flecks_of.size() <= fleck_room:
			fleck_data.append_array(flecks_of)
	_fill(shafts.multimesh, shaft_data, MAX_SHAFTS)
	_fill(flecks.multimesh, fleck_data, MAX_FLECKS)
	if dust.is_empty():
		dust.append(Vector3(p.x, -1000.0, p.z))
	motes.emission_points = dust


## Hands the instances in `data` (see _put) to MultiMesh `mm` of `most` instances at
## once, the rest of its buffer left as it was and not drawn.
static func _fill(mm: MultiMesh, data: PackedFloat32Array, most: int) -> void:
	var n := data.size() / INSTANCE_FLOATS
	if n > 0:
		data.resize(most * INSTANCE_FLOATS)
		mm.buffer = data
	mm.visible_instance_count = n


## The outline of the crown `crown` (see _crown) of the tree in column `col` on its
## middle plane, the upright one through the trunk along _across: for each level with
## leaves beside the trunk, Vector3(the level's middle over the foot, how far the
## leaves reach to one side (-) and the other (+)) in world units.
func _outline(w, col: Vector2i, crown: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var base := roundi(crown.x / CELL)
	var top := roundi(crown.y / CELL)
	var mid := Vector2(col.x + 0.5, col.y + 0.5)
	var reach := CROWN_REACH * 2
	for y in range(base, top):
		var ends := Vector2.ZERO
		for k in 2:
			var way := _across * (1.0 if k == 1 else -1.0)
			var last := 0
			for d in range(1, reach):
				if d - last > OUTLINE_GAP:
					break
				var c := mid + way * d
				if w.get_cell(floori(c.x), y, floori(c.y)) != Mat.AIR:
					last = d
			if last > 0:
				ends[k] = (last + 0.5) * CELL * (1.0 if k == 1 else -1.0)
		if ends != Vector2.ZERO:
			out.append(Vector3((y + 0.5) * CELL - crown.x, ends.x, ends.y))
	return out


## A point inside `outline` (see _outline) for a shaft `width` wide, picked by
## `pick` and `side` (0..1; the wider a level, the likelier): Vector4(how far along
## _across from the trunk, height over the foot, the level's two ends), y -INF when
## the outline is empty.
static func _in_outline(outline: PackedVector3Array, pick: float, side: float, width: float) -> Vector4:
	var total := 0.0
	for o in outline:
		total += o.z - o.y
	if total <= 0.0:
		return Vector4(0.0, -INF, 0.0, 0.0)
	var left := pick * total
	var at := outline[outline.size() - 1]
	for o in outline:
		left -= o.z - o.y
		if left <= 0.0:
			at = o
			break
	var a := at.y + width * 0.5
	var b := at.z - width * 0.5
	return Vector4(lerpf(a, b, side) if a < b else (at.y + at.z) * 0.5, at.x, at.y, at.z)


## How far a shaft from `top` runs along the light before it meets the ground (or
## water), LONGEST at most. Until it comes down near the height of the tree's foot
## `foot` only a hill can stop it, so it is looked at every COARSE units there and a
## unit at a time below; then halved down to a 16th of a unit, so the shaft ends on
## the ground. (A unit at a time all the way was 20-40 looks at the ground a shaft, up
## to a millisecond a tree on a PC: a phone's frame of 5-11 ms, 2026-11-15.)
func _length(w, top: Vector3, foot: float) -> float:
	var drop := -_down.y
	var level := (top.y - foot) / drop if drop > 0.01 else LONGEST
	var above := 0.0
	var length := 1.0
	while not _under(w, top + _down * length):
		above = length
		length += COARSE if length + COARSE < level - 1.0 else 1.0
		if length >= LONGEST:
			return LONGEST
	while length - above > 1.0 / 16.0:
		var half := (above + length) * 0.5
		if _under(w, top + _down * half):
			length = half
		else:
			above = half
	return length


## Ground at world point `p` shows in the picture: nothing stands over it on the way
## to the camera (the view now) up to SEEN_ABOVE world units higher.
func _seen(w, p: Vector3) -> bool:
	var run := PixelView.up * PixelView.slope / PixelView.squash
	var way := Vector3(-run.x, 1.0, -run.y) * CELL
	var at := p + way
	while at.y - p.y < SEEN_ABOVE:
		if w.get_cell(floori(at.x / CELL), floori(at.y / CELL), floori(at.z / CELL)) != Mat.AIR:
			return false
		at += way
	return true


## World point `p` is under the ground (or the water's top).
func _under(w, p: Vector3) -> bool:
	var ground := _ground(w, Vector2(p.x, p.z))
	return ground <= -INF or p.y <= ground


## The height of the ground a walker stands on at world point `at`, -INF over water.
func _ground(w, at: Vector2) -> float:
	var h: float = w.ground_height(at.x / CELL, at.y / CELL)
	return h * CELL if h >= 0.0 else -INF


## The crown of the tree with its trunk in column `col`: Vector3(the foot of the trunk,
## the top of the crown, how far it reaches from the trunk) in world units, x -INF
## when no trunk is there; looked for once.
func _crown(w, col: Vector2i) -> Vector3:
	if _crowns.has(col):
		return _crowns[col]
	if _crowns.size() > MAX_CROWNS:
		_crowns.clear()
	var found := Vector3(-INF, 0.0, 0.0)
	# The column's top is the trunk's (crowns are left out): down it to the foot.
	var base := floori(w.ground_height(col.x + 0.5, col.y + 0.5))
	if w.get_cell(col.x, base - 1, col.y) != Mat.LOG:
		base = -1
	while base > 0 and w.get_cell(col.x, base - 1, col.y) == Mat.LOG:
		base -= 1
	if base >= 0:
		var top := base
		while top < base + CROWN_LEVELS and w.get_cell(col.x, top, col.y) != Mat.AIR:
			top += 1
		var middle := (base + top) / 2
		var reach := 1
		for d in range(1, CROWN_REACH):
			if w.get_cell(col.x + d, middle, col.y) == Mat.AIR and w.get_cell(col.x - d, middle, col.y) == Mat.AIR \
					and w.get_cell(col.x, middle, col.y + d) == Mat.AIR and w.get_cell(col.x, middle, col.y - d) == Mat.AIR:
				break
			reach = d + 1
		found = Vector3(base * CELL, top * CELL, reach * CELL)
	_crowns[col] = found
	return found
