extends RefCounted
## A body on the cell grid: walks up and down slopes, jumps up onto a sheer step of one
## cell (8 px) but not of two, goes around cut corners of cliffs. It wades through
## shallow water, swims in deep water with its head above the surface, sinks to the
## waist in the mud of a bog and wades slowly through it, pulls itself out onto ground
## up to one level above the water, and walks on ice in winter. Out in
## the open the weather slows it (see weather_pace): deep snow, except on a trail, a
## strong head wind, and a blizzard or a sand storm that hide the way; a strong wind
## carries it sideways in a jump (air_drift). A
## position is the middle of the feet in world units, kept by whoever owns the body
## (the player's node on the client); the body moves in cells.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Body and motion in cells: a little narrower than a cell, a little under two tall.
## The sprite is a cell wide, so the body is nearly that, and as deep as it is wide: the
## camera turns, and whichever way it looks the sprite keeps out of the walls beside it.
## A gap of one cell still lets it through (ASSIST lines it up with it).
const HALF_WIDTH := 0.47
const HALF_DEPTH := 0.47
const HEIGHT := 1.8
const SPEED := 8.0
const GRAVITY := 44.0
## A jump rises about 1.45 cells: onto a block of one cell, not of two.
const JUMP_SPEED := 11.3
const MAX_FALL := 30.0
## Cells below the feet a falling body counts as on the ground already (see step).
const LAND_EPS := 0.002
## Walking into a wall with the middle of the body this close to the middle of a gap of
## one cell beside it slides the body sideways into line with the gap.
const ASSIST := 0.35
## Walking keeps the feet on the ground up and down slopes by up to this much per step;
## a sheer step of a whole cell is not walked up or down.
const STEP_UP := 0.5
const STEP_DOWN := 0.6
## A swimmer floats with the feet this deep under the surface, so water up to one
## cell deep is waded and deeper water is swum.
const SWIM_DEPTH := 0.9
## Speed in water up to the knees and deeper, while swimming and wading a bog,
## against walking.
const WADE := 0.65
const SWIM := 0.45
const MIRE := 0.5
## Water slows a fall to this many cells a second and lifts a sunk swimmer this fast.
const SINK_SPEED := 5.0
const FLOAT_SPEED := 4.0
## On ice the body picks up and loses speed this slowly (cells a second, per second),
## so it glides on after the stick is let go.
const ICE_GRIP := 14.0
## Snow lying (Clock.snow) slows walking from SNOW_DEEP.x, by up to SNOW_SLOW at
## SNOW_DEEP.y; a fresh trail takes TRAIL_EASE of that off. Trails last TRAIL_DAYS, and
## falling snow fills them faster.
const SNOW_DEEP := Vector2(0.5, 1.0)
const SNOW_SLOW := 0.2
const TRAIL_EASE := 0.75
const TRAIL_DAYS := 0.5
## Wind (Clock.storm_wind) is felt from WIND_FELT and is full at WIND_FULL; a full head
## wind takes HEAD_WIND off the pace and a full tail wind adds TAIL_WIND.
const WIND_FELT := 0.8
const WIND_FULL := 2.5
const HEAD_WIND := 0.25
const TAIL_WIND := 0.1
## Falling snow slows by up to SNOWFALL_SLOW, and a full blizzard or sand storm (wind
## and snow or sand together) by HIDDEN_WAY more: the way ahead is hard to see.
const SNOWFALL_SLOW := 0.05
const HIDDEN_WAY := 0.15
## The weather never takes the pace below this share.
const WEATHER_FLOOR := 0.5
## A full wind carries a body in the air this many cells a second along it (a jump in
## a blizzard lands about a cell downwind).
const AIR_DRIFT := 2.5
## A shove (see knock) dies away this fast, in cells a second per second.
const SHOVE_DRAG := 30.0

var world
## The weather the body walks in (Clock), null for none.
var clock
## Movement wish: x = east, y = south, length up to 1.
var move_input := Vector2.ZERO
## Playtest multiplier of the walking speed (Settings.PLAYER_SPEEDS).
var speed_scale := 1.0
## What the load and tiredness leave of the pace (see Character).
var load_scale := 1.0
## What the weather leaves of the pace (see weather_pace), set each step.
var weather_scale := 1.0
## Playtest switch: a press of jump in the air jumps again, to climb out of a deep
## pit by pressing it over and over.
var air_jumps := false
## Whether the last step started a jump.
var jumped := false
## Whether jump was held in the last step: an air jump needs a fresh press.
var _jump_was := false
var velocity_y := 0.0
var on_ground := false
var swimming := false
## How murky the water the body is in is (WorldData.murk): 0 clear or out of water,
## 1 a swamp's, 2 a bog's, which is waded slower (see MIRE).
var murk := 0
var in_bog := false
## How deep the feet are under the water surface, 0 out of water.
var water_depth := 0.0
## Height of that surface in cells, -INF out of water.
var water_level := -INF
## The velocity on the ground plane in cells a second (x east, y south); on ice it
## lags behind the wish.
var glide := Vector2.ZERO
## A shove the body got (see knock), in cells a second (x east, y south): it carries
## the body whatever the stick says and dies away by SHOVE_DRAG.
var shove := Vector2.ZERO
## How far something the body ran into (an animal, see Wildlife.pushes) pushes it
## back in the next step, in cells (x east, y south); used up by the step.
var nudge := Vector2.ZERO
## Where (world units) the last step tried to move the body and something was in
## the way, Vector3.INF if nothing was: what it pushed against (a fire burns).
var bumped := Vector3.INF
## Height the body pushed against while in water can pull itself up by this step.
var _pull_up := 0.0
## The column the feet were last in: walking off it leaves a trail in the snow.
var _col := Vector2i(1 << 30, 0)


## The pace the body at `at` (world units) walks at now, in cells a second: slower in
## water, and slower still swimming.
func speed_at(at: Vector3) -> float:
	var p := at / CELL
	var surface := _water_surface(p)
	if surface == -INF or world.water_frozen:
		return _pace(0.0)
	return _pace(maxf(0.0, surface - p.y), _bog(p))


## Moves the body standing at `at` (world units) for `delta` seconds by move_input,
## jumping when `jump` is held; returns where it is then.
func step(at: Vector3, delta: float, jump: bool) -> Vector3:
	var p := at / CELL
	# The ground under the body changed (a cell dug beside it reshaped the slopes) and
	# it is in the ground now: up onto it, so it is not stuck there.
	if _collides(p):
		var top := _ground_top(p, p.y, p.y + 1.0)
		if top > -INF and not _collides(Vector3(p.x, top, p.z)):
			p.y = top
	var surface := _water_surface(p)
	if surface > -INF and world.water_frozen:
		# The water froze around the body: stand on the ice.
		p.y = maxf(p.y, surface)
		surface = -INF
	water_depth = maxf(0.0, surface - p.y)
	water_level = surface if water_depth > 0.0 else -INF
	murk = world.murk(floori(p.x), floori(p.y + 0.001), floori(p.z)) if water_depth > 0.0 else 0
	in_bog = murk == 2
	var dir := move_input.limit_length(1.0)
	weather_scale = weather_pace(p, dir)
	var speed := _pace(water_depth, in_bog)
	# In water the body gets out onto ground up to one level above the water's cell.
	var reach := ceilf(surface) + 1.0 if surface > -INF else -INF
	_pull_up = 0.0
	bumped = Vector3.INF
	if on_ice(p):
		glide = glide.move_toward(dir * speed, ICE_GRIP * delta)
	else:
		glide = dir * speed
	var before := p
	p = _try_move(p, Vector3(glide.x * delta, 0.0, 0.0), reach)
	p = _try_move(p, Vector3(0.0, 0.0, glide.y * delta), reach)
	var drift := air_drift(p)
	if drift != Vector2.ZERO:
		p = _try_move(p, Vector3(drift.x * delta, 0.0, 0.0), reach)
		p = _try_move(p, Vector3(0.0, 0.0, drift.y * delta), reach)
	if shove != Vector2.ZERO:
		var bump := bumped
		p = _try_move(p, Vector3(shove.x * delta, 0.0, 0.0), reach)
		p = _try_move(p, Vector3(0.0, 0.0, shove.y * delta), reach)
		# What the shove pushed the body against is not what it pushed against itself.
		bumped = bump
		shove = shove.move_toward(Vector2.ZERO, SHOVE_DRAG * delta)
	if nudge != Vector2.ZERO:
		var bump := bumped
		p = _try_move(p, Vector3(nudge.x, 0.0, 0.0), reach)
		p = _try_move(p, Vector3(0.0, 0.0, nudge.y), reach)
		bumped = bump
		nudge = Vector2.ZERO
	# A wall stops the glide along it.
	if absf(p.x - before.x) < absf(glide.x * delta) * 0.5:
		glide.x = 0.0
	if absf(p.z - before.z) < absf(glide.y * delta) * 0.5:
		glide.y = 0.0
	# Down a slope or a step with the feet on it; standing still, gravity below finds
	# the ground (a frame of a body standing is most of what it costs).
	if on_ground and not jump and p != before:
		var below := _ground_top(p, p.y - STEP_DOWN, p.y)
		if below > -INF:
			p.y = below
	_leave_trail(p)
	jumped = jump and (on_ground or (air_jumps and not _jump_was))
	_jump_was = jump
	if jumped:
		velocity_y = JUMP_SPEED
	elif _pull_up > 0.0 and velocity_y <= 0.0:
		velocity_y = sqrt(2.0 * GRAVITY * (_pull_up + 0.2))
	var float_y := surface - SWIM_DEPTH
	swimming = velocity_y <= 0.0 and p.y <= float_y + 0.01
	if swimming:
		# Deep water holds the body up with its head above the surface.
		velocity_y = 0.0
		on_ground = false
		var fy := move_toward(p.y, float_y, FLOAT_SPEED * delta)
		if not _collides(Vector3(p.x, fy, p.z)) or _collides(p):
			p.y = fy
		return p * CELL
	velocity_y = maxf(velocity_y - GRAVITY * delta, -SINK_SPEED if water_depth > 0.0 else -MAX_FALL)
	var ny := p.y + velocity_y * delta
	# Falling, the ground a hair below counts as reached: at a high frame rate a body
	# standing still sinks less a frame than _collides lets pass (0.001), so it would
	# drop a frame and land the next, on and off the ground every other frame (and
	# tell the server so each time).
	var probe := ny - LAND_EPS if velocity_y < 0.0 else ny
	if _collides(Vector3(p.x, probe, p.z)):
		if velocity_y < 0.0:
			var ground := _ground_top(p, probe, p.y)
			p.y = ground if ground > -INF else floorf(ny) + 1.0
			on_ground = true
		velocity_y = 0.0
	else:
		p.y = ny
		on_ground = false
	return p * CELL


## Shoves the body along `dir` (x east, y south) at `speed` cells a second, with a
## little hop off the ground (a burn throws it back).
func knock(dir: Vector2, speed: float, hop: float) -> void:
	shove = dir.normalized() * speed
	if on_ground and velocity_y <= 0.0:
		velocity_y = hop


## True when the body at `p` (in cells) stands on frozen water.
func on_ice(p: Vector3) -> bool:
	if not on_ground or not world.water_frozen:
		return false
	# Ice lies at the water's surface, inside its cell.
	return world.get_cell(floori(p.x), floori(p.y - 0.01), floori(p.z)) == Mat.WATER


## The level of the cell the feet at `at` (world units) are in.
static func level_at(at: Vector3) -> int:
	return floori(at.y / CELL + 0.01)


## True if the body standing at `at` (world units) would overlap the cell.
static func overlaps(at: Vector3, cell: Vector3i) -> bool:
	var p := at / CELL
	return cell.x == clampi(cell.x, floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH)) \
		and cell.z == clampi(cell.z, floori(p.z - HALF_DEPTH), floori(p.z + HALF_DEPTH)) \
		and cell.y == clampi(cell.y, floori(p.y + 0.001), floori(p.y + HEIGHT))


## The pace with the feet `depth` cells under the water surface, of a bog if `mire`.
func _pace(depth: float, mire := false) -> float:
	var k := SWIM if swimming else (MIRE if mire and depth > 0.0 else (WADE if depth > 0.3 else 1.0))
	return SPEED * speed_scale * load_scale * weather_scale * k


## True when the water the body at `p` (in cells) stands in is a bog's.
func _bog(p: Vector3) -> bool:
	return world.is_bog(floori(p.x), floori(p.y + 0.001), floori(p.z))


## What the weather leaves of the pace of the body at `p` (in cells) walking `dir`
## (x east, y south): 1 under a roof or with no clock. In the open deep snow (in
## winter, or all year on the high mountains, see WorldData.peak_snow) slows it
## unless the column is a fresh trail, the wind against it slows it and the wind
## behind it helps, and a blizzard or a sand storm slows it more.
func weather_pace(p: Vector3, dir: Vector2) -> float:
	if clock == null:
		return 1.0
	var x := floori(p.x)
	var z := floori(p.z)
	if world.roof_level(x, z) >= floori(p.y + 0.01):
		return 1.0
	var k := 1.0
	if on_ground and water_depth <= 0.0:
		var deep: float = smoothstep(SNOW_DEEP.x, SNOW_DEEP.y, maxf(clock.snow, world.peak_snow(p.y)))
		if deep > 0.0:
			var life: float = TRAIL_DAYS * (1.0 - 0.75 * clock.snowing)
			k -= SNOW_SLOW * deep * (1.0 - TRAIL_EASE * world.trail(x, z, clock.now(), life))
	var wind: float = clampf((clock.storm_wind - WIND_FELT) / (WIND_FULL - WIND_FELT), 0.0, 1.0)
	if wind > 0.0 and dir != Vector2.ZERO:
		var along: float = dir.normalized().dot(clock.wind_dir())
		k += wind * along * (TAIL_WIND if along > 0.0 else HEAD_WIND)
	var hidden: float = clampf(clock.storm_wind / WIND_FULL, 0.0, 1.0) * maxf(clock.snowing, clock.sand)
	k -= SNOWFALL_SLOW * clock.snowing + HIDDEN_WAY * hidden * hidden
	return maxf(k, WEATHER_FLOOR)


## How the wind carries the body at `p` (in cells) while it is in the air, in cells a
## second (x east, y south): along the wind as strong as it is felt (see WIND_FELT), none
## on the ground, in water or under a roof.
func air_drift(p: Vector3) -> Vector2:
	if clock == null or on_ground or swimming or water_depth > 0.0:
		return Vector2.ZERO
	var wind: float = clampf((clock.storm_wind - WIND_FELT) / (WIND_FULL - WIND_FELT), 0.0, 1.0)
	if wind <= 0.0 or world.roof_level(floori(p.x), floori(p.z)) >= floori(p.y + 0.01):
		return Vector2.ZERO
	return clock.wind_dir() * (AIR_DRIFT * wind)


## Walking off a column of snow leaves a trail in it (see WorldData.trodden).
func _leave_trail(p: Vector3) -> void:
	var col := Vector2i(floori(p.x), floori(p.z))
	if col == _col:
		return
	if clock != null and on_ground and maxf(clock.snow, world.peak_snow(p.y)) > SNOW_DEEP.x and _col.x != 1 << 30:
		world.tread(_col.x, _col.y, clock.now())
	_col = col


## Moves by `d` unless something is in the way. On the ground the body follows ground
## rising a little (a slope, not a sheer step); in water, ground up to `reach` ahead
## sets _pull_up for a climb out.
func _try_move(p: Vector3, d: Vector3, reach: float) -> Vector3:
	if d == Vector3.ZERO:
		return p
	var np := p + d
	if not _collides(np):
		return np
	if on_ground:
		var top := _ground_top(np, p.y, p.y + STEP_UP)
		if top > p.y:
			var up := Vector3(np.x, top, np.z)
			if not _collides(up) and not _collides(Vector3(p.x, top, p.z)):
				return up
	if reach > p.y:
		var top := _ground_top(np, p.y, reach)
		if top > p.y and not _collides(Vector3(np.x, top, np.z)):
			_pull_up = maxf(_pull_up, top - p.y)
	var slid := _line_up(p, d)
	if slid != p:
		return slid
	bumped = np * CELL
	return p


## The body at `p` stopped moving by `d` along one axis: moved sideways toward the middle
## of its column, by as much as `d`, when there the way on is open (a door, a gap of one
## cell between trunks or blocks); `p` otherwise.
func _line_up(p: Vector3, d: Vector3) -> Vector3:
	var along_x := d.x != 0.0
	var side := p.z if along_x else p.x
	var off := floorf(side) + 0.5 - side
	if is_zero_approx(off) or absf(off) > ASSIST:
		return p
	var lined := p + (Vector3(0.0, 0.0, off) if along_x else Vector3(off, 0.0, 0.0))
	if _collides(lined + d):
		return p
	var shift := signf(off) * minf(absf(off), d.length())
	var slid := p + (Vector3(0.0, 0.0, shift) if along_x else Vector3(shift, 0.0, 0.0))
	return p if _collides(slid) else slid


## Height of the water surface in the column under the middle of the body when the
## feet are in water there, -INF otherwise. The surface is where it is drawn: below
## the top of its cell under open air, at the top under a ceiling.
func _water_surface(p: Vector3) -> float:
	var x := floori(p.x)
	var y := floori(p.y + 0.001)
	var z := floori(p.z)
	if world.get_cell(x, y, z) != Mat.WATER:
		return -INF
	while world.get_cell(x, y + 1, z) == Mat.WATER:
		y += 1
	return y + (WorldData.WATER_TOP if world.get_cell(x, y + 1, z) == Mat.AIR else 1.0)


func _collides(p: Vector3) -> bool:
	var x0 := floori(p.x - HALF_WIDTH)
	var x1 := floori(p.x + HALF_WIDTH)
	var z0 := floori(p.z - HALF_DEPTH)
	var z1 := floori(p.z + HALF_DEPTH)
	var y0 := floori(p.y + 0.001)
	var y1 := floori(p.y + HEIGHT)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var f := _footprint(x, z, p)
				if not world.blocks_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y):
					continue
				# A sloping cell only blocks below its surface under the feet, which may
				# lie below the cell where the slope goes on down.
				if p.y + 0.001 < y + _cell_top(x, y, z, p):
					return true
	return false


## Height of the highest ground the feet at `p` would stand on, among surfaces between
## `lo` and `hi`; -INF when there is none.
func _ground_top(p: Vector3, lo: float, hi: float) -> float:
	var best := -INF
	for y in range(floori(lo), floori(hi) + 1):
		for z in range(floori(p.z - HALF_DEPTH), floori(p.z + HALF_DEPTH) + 1):
			for x in range(floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH) + 1):
				var f := _footprint(x, z, p)
				if not world.ground_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y):
					continue
				var top := y + _cell_top(x, y, z, p)
				if top >= lo - 0.001 and top <= hi + 0.001:
					best = maxf(best, top)
	return best


## The part of the cell (x, z) under the footprint of a body at `p`, in 0..1 cell
## coordinates: position = (min x, min z), end = (max x, max z).
static func _footprint(x: int, z: int, p: Vector3) -> Rect2:
	var a := Vector2(clampf(p.x - HALF_WIDTH - x, 0.0, 1.0), clampf(p.z - HALF_DEPTH - z, 0.0, 1.0))
	var b := Vector2(clampf(p.x + HALF_WIDTH - x, 0.0, 1.0), clampf(p.z + HALF_DEPTH - z, 0.0, 1.0))
	return Rect2(a, b - a)


## Top of a solid cell under the footprint at `p` above its level: 1 for a cube, the
## top of a thing standing in it (see WorldData.blockers), the
## highest point of the slope under the feet otherwise (below 0 where the slope goes
## on down into the cell below).
func _cell_top(x: int, y: int, z: int, p: Vector3) -> float:
	if not world.blockers.is_empty():
		var f := _footprint(x, z, p)
		var thing: float = world.blocker_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y)
		if thing > 0.0:
			return thing
	var m: int = world.get_cell(x, y, z)
	if m == Mat.WATER:
		return world.ice_top(x, y, z)
	if not Mat.can_slope(m):
		return 1.0
	var mask: int = world.slope_mask(x, y, z)
	if mask == WorldData.FULL:
		return 1.0
	var patch: PackedFloat32Array = world.surface_patch(x, y, z)
	var ax := clampf(p.x - HALF_WIDTH - x, 0.0, 1.0)
	var bx := clampf(p.x + HALF_WIDTH - x, 0.0, 1.0)
	var az := clampf(p.z - HALF_DEPTH - z, 0.0, 1.0)
	var bz := clampf(p.z + HALF_DEPTH - z, 0.0, 1.0)
	var top := -INF
	for i in 3:
		for k in 3:
			top = maxf(top, WorldData.patch_height(patch, lerpf(ax, bx, i * 0.5), lerpf(az, bz, k * 0.5)))
	return top
