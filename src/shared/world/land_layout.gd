extends RefCounted
## The land laid out from noise, which WorldGen extends: for any window of columns,
## `lay_out` gives height, water, top material, biome and flags (see `_window` and
## `_layout_row`), the same wherever and whenever it is asked, so chunks, the maps, the
## setup screen and `find_place` all read the one landscape. Continents and oceans come
## from a very slow noise sampled on a lattice, mountains, plateaus and cliff coasts from
## slower and faster ones over the land, rivers run along the zero lines of a noise,
## stepping down mountains and parting into deltas, lakes fill its high spots, and the
## climate (warmth and moisture) is noise too; caves are cut into mountain sides
## (`_tunnels`). Nothing here writes cells: WorldGen fills the chunks from the layout.


const Mat := preload("res://src/shared/content/materials.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const CHUNK := WorldData.CHUNK
## Columns around a chunk the terrain stage lays out too, so banks, caves and trees
## can look at their neighbours.
const MARGIN := 3
const WINDOW := CHUNK + 2 * MARGIN
## Cells between the samples of the slow noises (continents, rivers, lakes), which are
## sampled exactly and interpolated with their slopes in between.
const LATTICE := 4
## The biome of a column is a byte index into Biomes.RECORDS (Biomes.NONE when no loaded
## biome fits): the relief decides the sea, beaches, bare rock, plateaus and swamps, the
## climate (warmth and moisture) the rest.
## Relief kinds of a column.
const PLAIN := 0
const MOUNTAIN := 1
const HIGHLAND := 2
const CLIFFS := 3
const SEA_FLOOR := 4
## Water of a column: none, the sea, a lake or a river (a canyon floor counts as river).
const DRY := 0
const OCEAN := 1
const LAKE := 2
const RIVER := 3
const CANYON := 4
## World settings, each a level from 0 (little) to 2 (much); 1 is the usual world.
## size: how large continents and islands are; water: the share of the ocean;
## mountains: how much of the land rises into mountains; rivers: how many rivers and
## lakes; biomes: how far one climate stretches; caves: how many caves there are under
## the ground, how many mouths open to them and how many are cut into mountain sides;
## relief: how mountains and plateaus are shaped, 0 domes and flat terraces, 1 ranges
## with gorges where it is cool and wet, mesas with canyons where it is hot and dry
## (see _ranges_and_mesas); climate: 0 warmth from one noise, so any climate can lie
## next to any other, 1 in zones (see ZONE_SPREAD). Here caves is 1, relief and climate
## 0, what worlds made before those settings have; «Новый мир» makes caves 0, relief and
## climate 1.
const DEFAULT_SETTINGS := {"size": 1, "water": 1, "mountains": 1, "rivers": 1, "biomes": 1, "caves": 1, "relief": 0,
	"climate": 0}
const SIZE_SCALE := [0.4, 1.0, 2.2]
const WATER_SHARE := [0.25, 0.4, 0.58]
## Where the mountain noise starts and ends raising mountains.
const MOUNTAIN_FROM := [0.5, 0.3, 0.12]
const RIVER_FROM := [0.1, -0.1, -0.3]
const LAKE_FROM := [0.66, 0.55, 0.45]
const BIOME_SCALE := [0.5, 1.0, 2.0]
## Climate 1: the warmth of a column is mostly that of its zone, a noise this many times
## slower than the old warmth's, and the old warmth noise only stirs it by ZONE_SPREAD,
## so the biomes of one zone (the tundra by the taiga, the steppe by the desert) lie
## side by side in patches and the zones follow one another, the cold far from the hot.
const ZONE_SLOWER := 2.5
const ZONE_SPREAD := 0.18
## Caves by the caves setting: the 3D noise level above which the ground is hollow
## (under a cave mouth and elsewhere; about 4%, 7.5% and 11% of the ground away from
## mouths), the level of the mouths noise above which a cave mouth opens, and the
## share of TUNNEL_GRID squares with a cave cut into a mountain side.
const CAVE_FROM := [0.5, 0.42, 0.36]
const MOUTH_CAVE_FROM := [0.36, 0.3, 0.24]
const MOUTH_FROM := [0.65, 0.55, 0.45]
const TUNNEL_CHANCE := [0.15, 0.45, 0.75]
## Column flags while laying out: the top keeps a sheer wall; a cave mouth is here
## (see _entrances), with bigger caves under it.
const SHEER_TOP := 1
const ENTRANCE := 2
## The water of the column is a bog's (WorldData.BOG), or a swamp's (WorldData.SWAMP).
const MIRE := 4
const MARSH := 8
## The column is on the wooded slope of a mountain: trees grow whatever its biome says.
const WOODS := 16
## The column's walls are banded (a mesa, see _fill_row).
const STRATA := 32
## A cave mouth opens sideways where its ground drops by WALL cells or more within
## three columns: a gallery ADIT cells high is cut in at the foot of the wall. On
## level ground it is a pit instead, up to PIT_DEPTH cells deep in its middle.
const WALL := 5
const ADIT := 4
const PIT_DEPTH := 12
## Cells of level sand along a flat coast (see _relief).
const FLAT_BEACH := 28.0
## Rivers widen towards the sea or a lake over this many cells, so they are brooks
## at their sources and broad at their mouths.
const MOUTH_REACH := 400.0
## Mountains: the smooth rise of the highest of them over the land around, and their
## ridges on top of it (see _relief); above ROCK_LINE levels over the sea their slopes
## are bare scree with sheer stone outcrops, and above WorldData.SNOW_LINE snow lies on
## them all year. Between the foot and the rock a mountain is wooded here and there.
const MOUNT_RISE := 15.0
const RIDGE_RISE := 5.0
const ROCK_LINE := 15
const MOUNT_WOODS := 7
## Relief 1 (see _ranges_and_mesas). Ranges: the rise of their feet and of their
## highest crests, the crags on the crests and the low ranges where plateaus were;
## gorges GORGE_WIDTH hundredths of the gorge noise wide; tors where the crag noise
## is above TOR_FROM. Mesas: from MESA_FROM over the plateau noise, tops MESA_TIERS
## levels over the land at the coast; canyon walls a tier lower every CANYON_STEP
## hundredths of the gorge noise; buttes where the crag noise is above BUTTE_FROM.
## The land is dry (mesas) where the warmth byte is over DRY_WARM and the moisture byte
## under DRY_WET, blending over DRY_BLEND either way.
const RANGE_FOOT := 4.0
const RANGE_RISE := 26.0
const CRAG_RISE := 3.0
const LOW_RANGE_RISE := 14.0
const GORGE_WIDTH := 3.5
const TOR_FROM := 0.7
const MESA_FROM := 0.18
const MESA_TIERS := [5.0, 9.0, 12.0, 17.0, 21.0]
const CANYON_STEP := 3.5
const BUTTE_FROM := 0.56
const DRY_WARM := 140.0
const DRY_WET := 135.0
const DRY_BLEND := 10.0
## What _ranges_and_mesas lays on a column: the floor of a gorge, of a canyon, a mesa
## (banded walls) or a tor.
const GORGE := 1
const CANYON_FLOOR := 2
const MESA := 3
const TOR := 4
## Rivers in the mountains run higher, climbing a fraction RIVER_CLIMB of the
## mountain's rise in steps (see _river_level): FALL_STEP levels apart, each a rapid of
## one level and then a waterfall of the rest. Boulders stand in the channel where it
## drops a level, a share BOULDERS of its cells.
const RIVER_CLIMB := 0.85
const FALL_STEP := 4
const RAPID_AT := 0.65
const BOULDERS := 0.12
## Within DELTA_REACH cells of the coast a river splits into a delta: two arms that part
## from the main channel up to DELTA_SPREAD cells to each side at the coast, and two
## more that part from those nearer the sea, with low sandy islands between.
const DELTA_REACH := 160.0
const DELTA_SPREAD := 16.0
## How steep the river noise must be per cell for the arms of a delta.
const DELTA_SLOPE := 0.001
## Rare caves in the side of a mountain: in a square of TUNNEL_GRID cells, now and then
## (TUNNEL_CHANCE by the caves setting), a gallery TUNNEL_LEN cells long is cut uphill
## into a slope, ending in a chamber over bigger caves (see _tunnels).
const TUNNEL_GRID := 48
const TUNNEL_LEN := 26

var world_seed: int
var settings: Dictionary
## The materials the generator lays by their roles (see Mat.ROLES): dirt or stone
## where no loaded mod gives one.
var beach: int
var bank: int
var scree: int
var snow: int
var ore: int
var size_y: int
var sea: int
## The continent noise's value at the coast: below it is the ocean.
var coast_level := 0.0
## The caves cut into mountains' sides by grid square (see _tunnel), as they are
## worked out.
var tunnels := {}
var n_hills: FastNoiseLite
var n_ridges: FastNoiseLite
var n_mount: FastNoiseLite
var n_shape: FastNoiseLite
var n_cliff: FastNoiseLite
var n_plateau: FastNoiseLite
var n_steep: FastNoiseLite
var n_soil: FastNoiseLite
var n_forest: FastNoiseLite
var n_gully: FastNoiseLite
var n_mouths: FastNoiseLite
var n_pools: FastNoiseLite
var n_temp: FastNoiseLite
var n_moist: FastNoiseLite
var n_swamp: FastNoiseLite
var n_flow: FastNoiseLite
var n_dunes: FastNoiseLite
var n_roll: FastNoiseLite
var n_peak: FastNoiseLite
var n_caves: FastNoiseLite
## Relief 1 only (see _ranges_and_mesas): the crests of the ranges (along the zero
## lines of n_range), the lines of gorges and canyons, crags, tors and buttes.
var n_range: FastNoiseLite
var n_gorge: FastNoiseLite
var n_crag: FastNoiseLite
var n_ores: FastNoiseLite
## Climate 1 only: the zones' warmth, and where it lies in window_noises (-1 without).
var n_zone: FastNoiseLite
var zone_grid := -1
## The slow noises sampled on the lattice: continents, rivers (along its zero lines)
## and lakes (over its high spots).
var n_land: FastNoiseLite
var n_river: FastNoiseLite
var n_lake: FastNoiseLite
## The 2D noises sampled for a window, in the order _layout_row reads them.
var window_noises: Array


# --- Noises ----------------------------------------------------------------------


func _noises() -> void:
	var size: float = SIZE_SCALE[settings.size]
	var biomes: float = BIOME_SCALE[settings.biomes]
	n_hills = _noise(0, 0.005, 4)
	n_ridges = _noise(1, 0.009, 3)
	n_mount = _noise(2, 0.0022 / sqrt(size), 2)
	n_shape = _noise(3, 0.012, 2)
	n_cliff = _noise(4, 0.006, 2)
	n_plateau = _noise(5, 0.0035, 2)
	n_steep = _noise(6, 0.045, 2)
	n_soil = _noise(7, 0.025, 2)
	n_forest = _noise(8, 0.015, 2)
	n_gully = _noise(9, 0.01, 1)
	n_mouths = _noise(10, 0.02, 1)
	n_pools = _noise(11, 0.07, 2)
	n_temp = _noise(12, 0.0005 / biomes, 1)
	n_moist = _noise(13, 0.0008 / biomes, 2)
	n_swamp = _noise(17, 0.006, 2)
	n_flow = _noise(18, 0.0009, 2)
	n_dunes = _noise(19, 0.035, 2)
	n_roll = _noise(23, 0.003, 2)
	n_peak = _noise(24, 0.0016, 1)
	n_caves = _noise(14, 0.03, 2)
	n_ores = _noise(15, 0.075, 1)
	n_land = _noise(20, 0.00028 / size, 4)
	n_river = _noise(21, 0.0018, 2)
	n_lake = _noise(22, 0.004, 2)
	n_range = _noise(25, 0.003, 1)
	n_gorge = _noise(26, 0.005, 2)
	n_crag = _noise(27, 0.06, 2)
	window_noises = [n_hills, n_ridges, n_mount, n_shape, n_cliff, n_plateau, n_steep, n_soil,
		n_forest, n_gully, n_mouths, n_pools, n_temp, n_moist, n_swamp, n_flow, n_dunes, n_roll, n_peak]
	if settings.relief >= 1:
		window_noises.append_array([n_range, n_gorge, n_crag])
	zone_grid = -1
	if settings.get("climate", 0) >= 1:
		n_zone = _noise(28, 0.0005 / biomes / ZONE_SLOWER, 1)
		zone_grid = window_noises.size()
		window_noises.append(n_zone)


func _noise(salt: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed + salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## The continent noise's value below which lies the ocean, so that about the share of
## the world the water setting asks for is sea.
func _coast_level() -> float:
	var values := PackedFloat32Array()
	n_land.offset = Vector3.ZERO
	var spread := 0.5 / n_land.frequency
	for i in 32:
		for j in 32:
			values.append(n_land.get_noise_2d((i - 16) * spread * 0.37, (j - 16) * spread * 0.41))
	values.sort()
	return values[int(values.size() * WATER_SHARE[settings.water])]


## Byte value of a noise level, as the sampled grids hold them (0..255 for -1..1).
static func _byte(v: float) -> int:
	return int((v * 0.5 + 0.5) * 255.0)


## A hash of a column, 0..2^24, different for each `salt` and world.
func _hash(x: int, z: int, salt: int) -> int:
	var h := (x * 374761393 + z * 668265263 + (world_seed + salt) * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFF


func _chance(x: int, z: int, salt: int) -> float:
	return _hash(x, z, salt) / float(1 << 24)


# --- Laying out columns ----------------------------------------------------------


## A window of columns to lay out: `w` by `h` columns `step` cells apart from column
## x0, z0. Its noises are sampled by _sample and _lattice, its rows laid out by
## _layout_row into one entry per column (j = lz * w + lx): height, water (the top
## water cell, -1 for none), top, flags, biome, relief kind, what water it is and
## whether a river drops there (1 rapids, 2 a waterfall), and by _entrances and
## _tunnels the floor of a cave mouth's gallery and the depth of its pit.
func _window(x0: int, z0: int, w: int, h: int, step := 1) -> Dictionary:
	var count := w * h
	var lay := {"x0": x0, "z0": z0, "w": w, "h": h, "step": step, "grids": []}
	for k: String in ["heights", "water"]:
		var a := PackedInt32Array()
		a.resize(count)
		lay[k] = a
	lay.water.fill(-1)
	for k: String in ["tops", "flags", "biome", "kind", "feature", "falls", "adit", "pit", "cut"]:
		var a := PackedByteArray()
		a.resize(count)
		lay[k] = a
	for k: String in ["land", "coast", "river", "side", "seaward", "lake"]:
		var a := PackedFloat32Array()
		a.resize(count)
		lay[k] = a
	return lay


## Samples window noise `k` over the window (bytes, see _byte).
func _sample(lay: Dictionary, k: int) -> void:
	var n: FastNoiseLite = window_noises[k]
	var step: int = lay.step
	var f := n.frequency
	# A grid of one sample every `step` cells: the noise runs `step` times faster.
	n.frequency = f * step
	n.offset = Vector3(lay.x0 / float(step), lay.z0 / float(step), 0.0)
	lay.grids.append(n.get_image(lay.w, lay.h, false, false, false).get_data())
	n.frequency = f
	n.offset = Vector3.ZERO


## The slow noises of the window on a lattice of points LATTICE cells apart (all over
## the world, so windows agree), which _lattice_row interpolates with their slopes row
## by row: the continent noise and how far a column is from the coast (cells, less than
## zero at sea), how far it is from the middle of a river (and on which side: `side`
## is the same distance with a sign), and how far inside a lake (less than zero
## outside).
func _lattice(lay: Dictionary) -> void:
	var step: int = lay.step
	var x0: int = lay.x0
	var z0: int = lay.z0
	var span := maxi(LATTICE, step)
	var gx0 := floori(x0 / float(span)) - 1
	var gz0 := floori(z0 / float(span)) - 1
	var gw := floori((x0 + (lay.w - 1) * step) / float(span)) + 3 - gx0
	var gh := floori((z0 + (lay.h - 1) * step) / float(span)) + 3 - gz0
	lay.lattice = [_grid(n_land, gx0, gz0, gw, gh, span), _grid(n_river, gx0, gz0, gw, gh, span),
		_grid(n_lake, gx0, gz0, gw, gh, span), gx0, gz0, gw, gh, span]


## The slow noises of row `lz` of a window, interpolated from the lattice: the land and
## the distances to the coast, to the middle of a river and to a lake shore.
func _lattice_row(lay: Dictionary, lz: int) -> void:
	var g: Array = lay.lattice
	var land: PackedFloat32Array = g[0]
	var river: PackedFloat32Array = g[1]
	var lake: PackedFloat32Array = g[2]
	var gx0: int = g[3]
	var gw: int = g[5]
	var gh: int = g[6]
	var span: int = g[7]
	var step: int = lay.step
	var x0: int = lay.x0
	var w: int = lay.w
	var out_land: PackedFloat32Array = lay.land
	var out_coast: PackedFloat32Array = lay.coast
	var out_river: PackedFloat32Array = lay.river
	var out_side: PackedFloat32Array = lay.side
	var out_seaward: PackedFloat32Array = lay.seaward
	var out_lake: PackedFloat32Array = lay.lake
	var lake_from: float = LAKE_FROM[settings.rivers]
	var z: int = lay.z0 + lz * step
	var gz0: int = g[4]
	var fz := z / float(span) - gz0
	var iz := clampi(floori(fz), 1, gh - 3)
	var tz := fz - iz
	for lx in w:
		var x := x0 + lx * step
		var fx := x / float(span) - gx0
		var ix := clampi(floori(fx), 1, gw - 3)
		var tx := fx - ix
		var j := lz * w + lx
		var cs := _slope(land, gw, ix, iz, tx, tz, span)
		var c := Vector2(cs.z, Vector2(cs.x, cs.y).length())
		out_land[j] = c.x
		out_coast[j] = (c.x - coast_level) / maxf(c.y, 1e-6)
		var rs := _slope(river, gw, ix, iz, tx, tz, span)
		var r := Vector2(rs.z, Vector2(rs.x, rs.y).length())
		# How straight a river here runs towards the coast: its noise slopes across
		# the land noise's (only wanted near the coast, see DELTA_REACH).
		if out_coast[j] > 0.0 and out_coast[j] < DELTA_REACH:
			out_seaward[j] = absf(cs.x * rs.y - cs.y * rs.x) / maxf(c.y * r.y, 1e-12)
		out_river[j] = absf(r.x) / maxf(r.y, 1e-6)
		# Where the noise is nearly flat its distances mean little: a delta's arms
		# would ring round the spot (see _layout_row).
		out_side[j] = r.x / r.y if r.y > DELTA_SLOPE else 1e6
		var l := _smooth(lake, gw, ix, iz, tx, tz, span)
		out_lake[j] = (l.x - lake_from) / maxf(l.y, 1e-6)


## Values of a noise at the lattice points gx0.., gz0.. (gw by gh), `span` cells apart.
static func _grid(n: FastNoiseLite, gx0: int, gz0: int, gw: int, gh: int, span: int) -> PackedFloat32Array:
	n.offset = Vector3.ZERO
	var out := PackedFloat32Array()
	out.resize(gw * gh)
	for j in gh:
		for i in gw:
			out[j * gw + i] = n.get_noise_2d((gx0 + i) * span, (gz0 + j) * span)
	return out


## The value of a lattice grid at (ix + tx, iz + tz) and the length of its slope per
## cell, both interpolated between the four points around.
static func _smooth(g: PackedFloat32Array, gw: int, ix: int, iz: int, tx: float, tz: float, span: int) -> Vector2:
	var s := _slope(g, gw, ix, iz, tx, tz, span)
	return Vector2(s.z, Vector2(s.x, s.y).length())


## The slope per cell of a lattice grid at (ix + tx, iz + tz) (x, y) and its value (z),
## all interpolated between the four points around.
static func _slope(g: PackedFloat32Array, gw: int, ix: int, iz: int, tx: float, tz: float, span: int) -> Vector3:
	var j := iz * gw + ix
	var v00 := g[j]
	var v10 := g[j + 1]
	var v01 := g[j + gw]
	var v11 := g[j + gw + 1]
	var v := lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), tz)
	# Slopes at the four points from their neighbours, interpolated the same way.
	var sx := lerpf(lerpf(g[j + 1] - g[j - 1], g[j + 2] - g[j], tx),
		lerpf(g[j + gw + 1] - g[j + gw - 1], g[j + gw + 2] - g[j + gw], tx), tz)
	var sz := lerpf(lerpf(g[j + gw] - g[j - gw], g[j + gw + 1] - g[j - gw + 1], tx),
		lerpf(g[j + 2 * gw] - g[j], g[j + 2 * gw + 1] - g[j + 1], tx), tz)
	return Vector3(sx / (2.0 * span), sz / (2.0 * span), v)


## Base height of the land at a column: the ocean floor deepening away from the coast,
## low coasts rising inland into plains of low hills, mountains, the terraces of a
## plateau and the raised rim of a cliff coast. A mountain rises from a gentle foot,
## steeper towards the top, with ridges along the zero lines of a noise; how high it
## gets is a slow noise of its own, so some reach nearly the top of the world and
## others stay low hills. Returns [height, kind, rise, mountain]: `rise` is the smooth
## part of a mountain's height, which the rivers climb (see _river_level), `mountain`
## how far up the mountain the column is (0 at its foot, 1 at the top); `coast` is the
## distance from the coast in cells.
func _relief(coast: float, hills: int, ridges: int, mount: int, shape: int, cliff: int, plateau: int, roll: int,
		peak: int, rng := 128, gorge := 128, crag := 128, warm := 128, wet := 128) -> Array:
	# A ragged coast: the distance wobbles with a faster noise.
	coast += (shape - 128) / 128.0 * 6.0
	var h := hills / 255.0
	# Where the cliff noise is low the coast is a flat beach: the land stays a level
	# above the sea for a band of FLAT_BEACH cells, and the sea floor slopes gently.
	var cl := cliff / 127.5 - 1.0
	var flat := 1.0 - smoothstep(-0.3, -0.05, cl)
	var inland := clampf((coast - FLAT_BEACH * flat) / 64.0, 0.0, 1.0)
	# The hills grow in further from the coast than the land rises, and only where
	# the rolling noise is high: elsewhere the plains lie nearly level.
	var rolling := 0.2 + 0.8 * smoothstep(-0.05, 0.4, roll / 127.5 - 1.0)
	var land := sea + 1.0 + inland * (1.0 + h * 7.0 * inland * rolling)
	# Off a beach the water stays shallow for a few cells, then deepens slowly.
	var floor_h := lerpf(sea - 2.0 - minf(5.0, -coast / 8.0), sea - 1.0 - minf(6.0, maxf(0.0, -coast - 6.0) / 12.0), flat)
	var kind := PLAIN
	var mask := smoothstep(-6.0, 6.0, coast)
	# Cliff coasts: the land keeps its height right up to the water and drops into
	# the sea in one sheer wall.
	var cliffy := smoothstep(0.35, 0.6, cl)
	if cliffy > 0.5 and coast < 48.0:
		mask = 1.0 if coast > 0.0 else 0.0
		land = maxf(land, sea + 4.0 + h * 3.0)
		kind = CLIFFS
	# Mountains inland where the mountain noise is high.
	var from: float = MOUNTAIN_FROM[settings.mountains]
	var mountain := smoothstep(from, from + 0.55, mount / 127.5 - 1.0) * smoothstep(24.0, 140.0, coast)
	var rise := 0.0
	if settings.relief >= 1:
		return _ranges_and_mesas(land, floor_h, mask, kind, coast, h, mount, plateau, peak, rng, gorge, crag,
			warm, wet)
	if mountain > 0.0:
		var ridge := 1.0 - absf(ridges / 127.5 - 1.0)
		var tall := 0.4 + 0.6 * smoothstep(-0.3, 0.3, peak / 127.5 - 1.0)
		# About the mountain to the power 1.8: a gentle foot, steeper higher up.
		rise = MOUNT_RISE * tall * mountain * mountain * (1.2 - 0.2 * mountain)
		land += rise + mountain * tall * (RIDGE_RISE * ridge * ridge + h * 3.0)
		if mountain > 0.15:
			kind = MOUNTAIN
	# Plateaus rise in terraces four cells apart, with sheer edges.
	var plat := plateau / 127.5 - 1.0
	if plat > 0.42 and coast > 64.0 and mountain < 0.3:
		land = sea + 6.0 + 4.0 * floorf(h * 3.0 + smoothstep(0.42, 0.7, plat) * 2.0)
		kind = HIGHLAND
	var height := clampi(int(round(lerpf(floor_h, land, mask))), 2, size_y - 4)
	if height < sea:
		kind = SEA_FLOOR
	return [height, kind, rise, mountain, 0]


## The relief of worlds made with the relief setting 1 (see _relief): in the cool and
## wet lands long ranges with sharp crests, crags on them and gorges cut across, low
## ranges where the plateaus were and stone tors at their feet; in the hot and dry
## lands mesas in tiers of uneven height with ragged edges, buttes beyond them and
## canyons through them in steps, their walls banded (STRATA). Over a band of climate
## between the two the heights blend. Returns [height, kind, rise, mountain, cut], `cut`
## what _layout_row lays on top: GORGE, CANYON_FLOOR, MESA or TOR, else 0.
func _ranges_and_mesas(land: float, floor_h: float, mask: float, kind: int, coast: float, h: float, mount: int,
		plateau: int, peak: int, rng: int, gorge: int, crag: int, warm: int, wet: int) -> Array:
	var from: float = MOUNTAIN_FROM[settings.mountains]
	var m := mount / 127.5 - 1.0
	var plat := plateau / 127.5 - 1.0
	if m <= from - 0.35 and plat <= -0.1:
		# Most of the land: no range, mesa, butte nor tor can rise here.
		var plain := clampi(int(round(lerpf(floor_h, land, mask))), 2, size_y - 4)
		return [plain, SEA_FLOOR if plain < sea else kind, 0.0, 0.0, 0]
	var c := crag / 127.5 - 1.0
	# How far into the gorge or canyon line a column is, in hundredths of the noise.
	var g := absf(gorge / 127.5 - 1.0) * 100.0
	var dry := smoothstep(-DRY_BLEND, DRY_BLEND, warm - DRY_WARM) * smoothstep(-DRY_BLEND, DRY_BLEND, DRY_WET - wet)
	var out := [land, kind, 0.0, 0.0, 0]
	var ranges := []
	var mesas := []
	if dry < 1.0:
		ranges = _ranges(land, kind, coast, h, m, c, plat, g, peak, rng, from)
		out = ranges
	if dry > 0.0:
		mesas = _mesas(land, kind, coast, h, m, c, plat, g, from)
		out = mesas
		if dry < 1.0:
			# Between the two the heights blend; the shape of the nearer one stays.
			out = (ranges if dry < 0.5 else mesas).duplicate()
			out[0] = lerpf(ranges[0], mesas[0], dry)
			if dry < 0.5:
				out[2] = ranges[2] * (1.0 - dry * 2.0)
	var height := clampi(int(round(lerpf(floor_h, out[0], mask))), 2, size_y - 4)
	out[0] = height
	if height < sea:
		out[1] = SEA_FLOOR
		out[4] = 0
	return out


## Ranges (see _ranges_and_mesas): [land, kind, rise, mountain, cut].
func _ranges(land: float, kind: int, coast: float, h: float, m: float, c: float, plat: float, g: float, peak: int,
		rng: int, from: float) -> Array:
	var rise := 0.0
	var mountain := 0.0
	var cut := 0
	# The ranges stretch wider than the old mountains; the ridged noise draws their
	# crests, the valleys between them stay low.
	var area := smoothstep(from - 0.35, from + 0.25, m) * smoothstep(24.0, 120.0, coast)
	# 1 on the zero line of the range noise, the crest: a broad shoulder and a sharp top.
	var near := 1.0 - absf(rng / 127.5 - 1.0)
	var near2 := near * near
	var crest := 0.5 * near2 + 0.5 * near2 * near2 * near2
	if area > 0.0:
		var tall := 0.45 + 0.55 * smoothstep(-0.3, 0.3, peak / 127.5 - 1.0)
		rise = (RANGE_FOOT + RANGE_RISE * crest * tall) * area
		land += rise + (c * CRAG_RISE * crest + h * 2.0) * area
		mountain = clampf(area * (0.3 + crest), 0.0, 1.0)
		if area > 0.25 and land > sea + 5.0:
			kind = MOUNTAIN
		# A gorge: a narrow cut along the zero line of its noise, down near the foot of
		# the range, with sheer walls.
		if area > 0.35 and g < GORGE_WIDTH and land > sea + 8.0:
			land = sea + 3.0 + area * 3.0 + maxf(0.0, g - GORGE_WIDTH * 0.45) * 2.0
			cut = GORGE
	# Where the plateaus were: low ranges of the same crests.
	var low := smoothstep(0.3, 0.6, plat) * smoothstep(48.0, 120.0, coast)
	if low > 0.0 and kind != MOUNTAIN:
		land += low * (3.0 + LOW_RANGE_RISE * crest + c * 2.0 * crest)
		if low > 0.5 and land > sea + 8.0:
			kind = MOUNTAIN
			mountain = maxf(mountain, low * 0.5)
	# Stone tors here and there at the feet of the ranges.
	if kind == PLAIN and cut == 0 and area + low > 0.05 and c > TOR_FROM and coast > 32.0:
		land += 3.0 + (c - TOR_FROM) * 40.0
		cut = TOR
	return [land, kind, rise * 0.5, mountain if kind == MOUNTAIN else 0.0, cut]


## Mesas (see _ranges_and_mesas): [land, kind, rise, mountain, cut].
func _mesas(land: float, kind: int, coast: float, h: float, m: float, c: float, plat: float, g: float,
		from: float) -> Array:
	var cut := 0
	# Mesas rise where the plateaus and where the mountains would; ragged at the edges.
	var near_plateau := plat + c * 0.12 - MESA_FROM
	var p := maxf(near_plateau, smoothstep(from - 0.1, from + 0.5, m) * 0.6 - 0.05)
	if p > 0.0 and coast > 48.0:
		var tier := clampi(int((smoothstep(0.0, 0.57, p) + (h - 0.5) * 0.35) * MESA_TIERS.size()), 0,
			MESA_TIERS.size() - 1)
		# A canyon through the mesas: a floor of sand a few cells wide, walls in steps
		# down from the tier the mesa stands at.
		if g < CANYON_STEP * MESA_TIERS.size():
			tier = mini(tier, int(g / CANYON_STEP) - 1)
		if tier < 0:
			land = sea + 2.0
			cut = CANYON_FLOOR
		else:
			land = sea + 2.0 + MESA_TIERS[tier]
			cut = MESA
		kind = HIGHLAND
	elif near_plateau > -0.16 and coast > 48.0 and c > BUTTE_FROM:
		# A butte: a lone pillar beyond the mesas.
		land = sea + 2.0 + MESA_TIERS[1 if c > BUTTE_FROM + 0.12 else 0]
		kind = HIGHLAND
		cut = MESA
	return [land, kind, 0.0, 0.0, cut]


## The warmth bytes of climate 1: the zone's warmth `zone`, stirred by ZONE_SPREAD of the
## local warmth `local`.
static func _zoned(zone: PackedByteArray, local: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(zone.size())
	for j in zone.size():
		var v := (zone[j] - 128) * (1.0 - ZONE_SPREAD) + (local[j] - 128) * ZONE_SPREAD
		out[j] = clampi(roundi(128 + v), 0, 255)
	return out


## How many levels above the sea a river runs where it has climbed `climb` levels up a
## mountain: in steps of FALL_STEP, each first a rapid of one level and then a
## waterfall of the rest.
static func _river_level(climb: float) -> int:
	var steps := climb / FALL_STEP
	var at := steps - floorf(steps)
	return FALL_STEP * int(steps) + (1 if at > RAPID_AT else 0)


## Lays out one row of the window: height, top, flags and biome of each column, with
## the sea, the lakes and the rivers cut in.
func _layout_row(lay: Dictionary, lz: int) -> void:
	_lattice_row(lay, lz)
	var grids: Array = lay.grids
	var hills: PackedByteArray = grids[0]
	var ridges: PackedByteArray = grids[1]
	var mount: PackedByteArray = grids[2]
	var shape: PackedByteArray = grids[3]
	var cliff: PackedByteArray = grids[4]
	var plateau: PackedByteArray = grids[5]
	var steep: PackedByteArray = grids[6]
	var soil: PackedByteArray = grids[7]
	var gully: PackedByteArray = grids[9]
	var mouths: PackedByteArray = grids[10]
	var pools: PackedByteArray = grids[11]
	var temp: PackedByteArray = grids[12]
	# How much colder a level up is: in zones, half as much, so the hills of a hot zone
	# are not tundra.
	var cooling := 0.006
	if zone_grid >= 0:
		temp = _zoned(grids[zone_grid], temp)
		cooling = 0.003
	var moist: PackedByteArray = grids[13]
	var swamp: PackedByteArray = grids[14]
	var flow: PackedByteArray = grids[15]
	var dunes: PackedByteArray = grids[16]
	var roll: PackedByteArray = grids[17]
	var coast: PackedFloat32Array = lay.coast
	var river: PackedFloat32Array = lay.river
	var lake: PackedFloat32Array = lay.lake
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var biome: PackedByteArray = lay.biome
	var kinds: PackedByteArray = lay.kind
	var features: PackedByteArray = lay.feature
	var w: int = lay.w
	var soil_t := _byte(0.25)
	var steep_t := _byte(0.4)
	var mouth_t := _byte(MOUTH_FROM[settings.caves])
	var rough_t := _byte(0.3)
	var pool_t := _byte(0.12)
	var mud_t := _byte(0.0)
	var swamp_t := _byte(0.35)
	var mire_reach := 36
	var mire_t := _byte(-0.2)
	var river_from: float = RIVER_FROM[settings.rivers]
	var side: PackedFloat32Array = lay.side
	var seaward: PackedFloat32Array = lay.seaward
	var forest: PackedByteArray = grids[8]
	var peak: PackedByteArray = grids[18]
	var falls: PackedByteArray = lay.falls
	var old_relief: bool = settings.relief < 1
	var ranges: PackedByteArray = grids[19] if not old_relief else PackedByteArray()
	var gorges: PackedByteArray = grids[20] if not old_relief else PackedByteArray()
	var crags: PackedByteArray = grids[21] if not old_relief else PackedByteArray()
	var x0: int = lay.x0
	var z0: int = lay.z0 + lz * lay.step
	for lx in w:
		var j := lz * w + lx
		var r := _relief(coast[j], hills[j], ridges[j], mount[j], shape[j], cliff[j], plateau[j], roll[j], peak[j]) \
			if old_relief else _relief(coast[j], hills[j], ridges[j], mount[j], shape[j], cliff[j], plateau[j], roll[j],
				peak[j], ranges[j], gorges[j], crags[j], temp[j], moist[j])
		var height: int = r[0]
		var kind: int = r[1]
		var f := 0
		var feature := DRY
		var top := Mat.GRASS
		var b := Biomes.NONE
		var watery := false
		var sheer := steep[j] >= steep_t or kind == CLIFFS or kind == HIGHLAND
		if kind == MOUNTAIN:
			# The foot and the woods of a mountain lie in slopes; only its rock has
			# sheer outcrops (see below).
			sheer = false
		var wt := -1
		# Rivers along the zero lines of the river noise, where the flow noise lets
		# them run, narrow at the source and wider towards the sea or a lake, higher
		# up in the mountains, where they rise: none comes over the top.
		var up: float = r[3]
		var flowing := smoothstep(river_from, river_from + 0.35, flow[j] / 127.5 - 1.0) * (1.0 - smoothstep(0.45, 0.9, up))
		var d := river[j]
		var mouth := 1.0 - smoothstep(0.0, MOUTH_REACH, minf(coast[j], -lake[j]))
		var rw := 0.6 + (1.6 + 4.4 * mouth) * flowing
		var wet_bed := flowing > 0.2
		var climb: float = r[2] * RIVER_CLIMB
		var level := sea + _river_level(climb) if climb > 0.0 and flowing > 0.0 else sea
		# Near the coast the river parts into the arms of a delta (see DELTA_REACH):
		# lines beside the river's middle at the same distance from it, so they leave
		# the main channel and spread towards the sea; `fan` is how far the outer arms
		# are, and `d` the distance to the nearest channel.
		var delta := (1.0 - smoothstep(0.0, DELTA_REACH, coast[j])) * flowing * smoothstep(0.5, 0.8, seaward[j]) \
			if flowing > 0.0 and height >= sea and coast[j] < DELTA_REACH else 0.0
		var fan := 0.0
		if delta > 0.0:
			var spread := DELTA_SPREAD * pow(delta, 1.5)
			var outer := spread + DELTA_SPREAD * pow(smoothstep(0.45, 1.0, delta), 1.5)
			var across := absf(side[j] + (shape[j] - 128) / 128.0 * 3.0 * delta)
			var arm := 0.6 + 2.8 * delta
			fan = outer + arm
			rw += 3.0 * delta
			if absf(across - spread) <= arm or absf(across - outer) <= arm:
				d = 0.0
			elif across < fan:
				d = minf(d, rw + 0.5)
		# The river's bed, also cut into the floor of the lake or the sea it flows
		# into, so the channel runs on without a step until the floor is deeper.
		var channel := level - (2 if d < rw - 1.0 else 1) if wet_bed and d <= rw else size_y
		if height < sea:
			wt = sea
			watery = true
			feature = OCEAN
			height = mini(height, channel)
		else:
			# Lakes over the high spots of the lake noise in the plains, with gentle
			# shores.
			var in_lake := lake[j]
			if kind == PLAIN and height <= sea + 8 and in_lake > -8.0:
				if in_lake > 0.0:
					height = mini(mini(height, sea - 1 - mini(4, int(in_lake / 3.0))), channel)
					wt = sea
					watery = true
					feature = LAKE
				else:
					# The shore at the water's level, so it slopes into the water.
					height = mini(height, sea + int(-in_lake))
			# Where the flow fades the valley rises and the river ends.
			if wt < 0 and flowing > 0.0:
				var bed := level if wet_bed else int(lerpf(height, level, flowing / 0.2))
				var canyon := kind == HIGHLAND or height > bed + 10
				var rf := rw + (3.5 if canyon else 1.5)
				if d <= rw and wet_bed:
					height = mini(height, channel)
					wt = level
					watery = true
					top = beach
					sheer = false
					feature = RIVER
					# Rapids: where the river drops a level, boulders in the channel
					# break the water.
					var at := fposmod(climb / FALL_STEP, 1.0)
					if climb > 0.0 and absf(at - RAPID_AT) < 0.06:
						falls[j] = 1
						if d < rw - 0.5 and _chance(x0 + lx * lay.step, z0, 9) < BOULDERS:
							height = level
							top = Mat.STONE
					elif climb > FALL_STEP * 0.5 and minf(at, 1.0 - at) < 0.06:
						falls[j] = 2
				elif d <= rf:
					if canyon:
						height = mini(height, bed)
						top = beach
						sheer = false
						feature = CANYON
					else:
						height = clampi(height, bed, bed + 1)
						sheer = false
				elif canyon and d <= rf + 2.0:
					# The canyon walls stay sheer.
					if height > bed + 2:
						sheer = true
				else:
					# A valley: the ground beyond the bank rises a cell per cell at most.
					height = mini(height, bed + 1 + int(d - rf))
			# The islands of a delta lie low between its arms.
			if wt < 0 and fan > 0.0:
				height = mini(height, sea + 1 + int(maxf(0.0, absf(side[j]) - fan) / 2.0))
		# How near water is, in steps of 16 cells: the coast, a lake or a river.
		var near := minf(coast[j], -lake[j])
		if flow[j] / 127.5 - 1.0 > river_from + 0.07:
			near = minf(near, river[j])
		var wet := clampi(int(near / 16.0), 0, 15)
		# Climate: warmth from the slow noise, colder up the hills; wetter near water.
		var t := clampf(0.5 + (temp[j] / 255.0 - 0.5) * 1.6, 0.0, 1.0) - (height - sea) * cooling
		var m := (moist[j] / 255.0) * 0.6 + 0.4 - mini(wet, 5) * 0.04
		# Ravines: narrow winding cuts along a noise's zero line, four to six cells
		# deep, through the dry hot lowland and the rolling hills only.
		var g := absi(gully[j] - 128)
		var rough := (t > 0.6 and m < 0.6) or roll[j] > rough_t
		if kind == PLAIN and rough and not sheer and wt < 0 and height > sea + 1 and wet >= 2 and g < 5 and feature == DRY:
			height -= 6 if g < 4 else 4
		# Bare rock: mountains above their rock line, which wavers a little, high
		# plateaus and cliff coasts.
		var cut: int = r[4]
		lay.cut[j] = cut
		var rocky := (height > sea + 12 and cut != CANYON_FLOOR and cut != MESA) or (kind == CLIFFS and height >= sea) \
			or cut == TOR
		if kind == MOUNTAIN:
			rocky = height >= sea + ROCK_LINE + (shape[j] - 128) / 48
		var climate := false
		if rocky and wt < 0:
			top = Mat.STONE
			b = _biome(Biomes.ROCK)
			if kind == MOUNTAIN:
				# Loose scree lies in slopes, stone juts out of it in sheer outcrops.
				sheer = steep[j] >= steep_t
				if not sheer:
					top = scree
			elif cut == TOR:
				sheer = true
		elif watery:
			b = _biome(Biomes.SEA)
			if feature != RIVER:
				top = beach if soil[j] < soil_t else bank
		elif feature == CANYON:
			b = _biome(Biomes.BEACH)
		elif cut == CANYON_FLOOR:
			# The floor of a canyon through mesas: sand.
			b = _biome(Biomes.BEACH)
			top = beach
			sheer = false
		elif cut == MESA:
			# A mesa: banded walls, its top sand or clay in the heat, grass else.
			b = _biome(Biomes.PLATEAU)
			f |= STRATA
			var hot := t > 0.55 and m < 0.62
			top = (beach if soil[j] < _byte(0.0) else bank) if hot else Mat.GRASS
			if hot and Biomes.pick(t, m) != Biomes.NONE:
				b = Biomes.pick(t, m)
		elif kind == HIGHLAND:
			b = _biome(Biomes.PLATEAU)
			top = Mat.STONE if height >= sea + 14 else Mat.GRASS
		elif height <= sea + 2 and wet <= 1:
			b = _biome(Biomes.BEACH)
			top = beach if soil[j] < soil_t else bank
		elif kind == PLAIN and height <= sea + 4 and swamp[j] > swamp_t and wet <= 4 and t > 0.3:
			# A swamp: flat wet ground a level or two above the sea, with pools.
			b = _biome(Biomes.SWAMP)
			height = sea + 1 + int(soil[j] > _byte(0.4))
			var p := pools[j]
			if p > pool_t or (p > pool_t - mire_reach and soil[j] > mire_t):
				# Pools, and mires along part of their shores and in hollows of their
				# own, all at one level, so the murky water of a pool runs into the
				# murkier, shallow water of a mire with no step.
				wt = sea + 1
				height = wt - (2 if p > pool_t + 20 else 1)
				top = bank
				f |= MARSH if p > pool_t else MIRE
			else:
				top = bank if p > mud_t else Mat.GRASS
			sheer = false
		else:
			# The climate's say: the loaded biome whose windows hold the warmth and the
			# moisture, with its ground (sand in dunes, stone and clay showing through).
			climate = true
			b = Biomes.pick(t, m)
			var rec := Biomes.of(b)
			top = Biomes.top(b, beach, bank, snow)
			if not rec.is_empty():
				if soil[j] < _byte(rec.stone_below):
					top = Mat.STONE
				elif soil[j] > _byte(rec.clay_above):
					top = bank
				if rec.dunes > 0.0 and kind == PLAIN and not sheer:
					height += int(dunes[j] / 255.0 * rec.dunes)
		# Some mountains are wooded between the foot and the rock, whatever grows below.
		if kind == MOUNTAIN and wt < 0 and climate and height >= sea + MOUNT_WOODS and forest[j] > _byte(-0.15):
			f |= WOODS
			top = Mat.GRASS
		if cut == GORGE and wt < 0:
			# The floor of a gorge: scree between sheer walls.
			top = scree
			b = _biome(Biomes.ROCK)
			sheer = false
		if sheer:
			f |= SHEER_TOP
		# Cave mouths here and there in the hills, more often in the mountains.
		if height > sea + 3 and mouths[j] > (mouth_t - 20 if rocky else mouth_t):
			f |= ENTRANCE
		heights[j] = height
		water[j] = wt
		tops[j] = top
		flags[j] = f
		biome[j] = b
		kinds[j] = kind
		features[j] = feature


## Where each cave mouth of the window opens (columns three in from its edge, which
## see the same neighbours in every window, before the banks are raised): beside a
## drop of WALL cells or more a gallery at the foot of the drop, else on rolling ground
## high enough a pit, deepest in the middle of the mouth. None within three columns of
## water.
func _entrances(lay: Dictionary) -> void:
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var flags: PackedByteArray = lay.flags
	var adit: PackedByteArray = lay.adit
	var pit: PackedByteArray = lay.pit
	var mouths: PackedByteArray = lay.grids[10]
	var w: int = lay.w
	var pit_t := _byte(MOUTH_FROM[settings.caves] + 0.13)
	# Pits only in the rolling half of the land.
	var roll: PackedByteArray = lay.grids[17]
	var pit_roll_t := _byte(0.1)
	for lz in range(3, lay.h - 3):
		for lx in range(3, w - 3):
			var j := lz * w + lx
			if flags[j] & ENTRANCE == 0:
				continue
			var hh := heights[j]
			var foot := hh
			var top := hh
			var dry := true
			for dz in range(-3, 4):
				var base := j + dz * w
				for dx in range(-3, 4):
					if water[base + dx] >= 0:
						dry = false
					foot = mini(foot, heights[base + dx])
					top = maxi(top, heights[base + dx])
			if not dry:
				continue
			if top - foot >= WALL:
				if hh > foot and foot > sea:
					adit[j] = foot + 1
			elif hh > sea + 5 and mouths[j] > pit_t and roll[j] > pit_roll_t:
				pit[j] = mini(mini(2 + (mouths[j] - pit_t) / 4, PIT_DEPTH), hh - 2)


## Water above the sea must not stand beside open air: the ground beside water rises
## to its level. Caves keep away from water on their own (see _fill_row).
func _banks(lay: Dictionary) -> void:
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var w: int = lay.w
	var h: int = lay.h
	var raised := PackedInt32Array()
	raised.resize(heights.size())
	for lz in range(1, h - 1):
		for lx in range(1, w - 1):
			var j := lz * w + lx
			if water[j] >= 0:
				continue
			var hh := heights[j]
			hh = maxi(hh, maxi(maxi(water[j - 1], water[j + 1]), maxi(water[j - w], water[j + w])))
			raised[j] = hh - heights[j]
	for j in heights.size():
		heights[j] += raised[j]


## Caves in the sides of mountains (see TUNNEL_GRID): a gallery ADIT cells high and
## three wide winds uphill from a spot on a slope, open to the sky where the slope is
## still low over it, and ends in a chamber over bigger caves. Each square of the grid
## decides on its own whether it has one and where, so every window cuts the same.
func _tunnels(lay: Dictionary) -> void:
	var x0: int = lay.x0
	var z0: int = lay.z0
	var w: int = lay.w
	var h: int = lay.h
	var heights: PackedInt32Array = lay.heights
	var flags: PackedByteArray = lay.flags
	var adit: PackedByteArray = lay.adit
	var reach := TUNNEL_LEN + 4
	for gz in range(floori((z0 - reach) / float(TUNNEL_GRID)), floori((z0 + h + reach) / float(TUNNEL_GRID)) + 1):
		for gx in range(floori((x0 - reach) / float(TUNNEL_GRID)), floori((x0 + w + reach) / float(TUNNEL_GRID)) + 1):
			var t := _tunnel(gx, gz)
			if t.is_empty():
				continue
			var mouth := Vector2(t[0], t[1])
			var dir: Vector2 = t[2]
			var floor_y: int = t[3]
			var bend := _chance(gx, gz, 10) * TAU
			for lz in h:
				for lx in w:
					var v := Vector2(x0 + lx, z0 + lz) + Vector2(0.5, 0.5) - mouth
					var along := v.dot(dir)
					if along < -0.5 or along > TUNNEL_LEN:
						continue
					var across := absf(v.cross(dir) - sin(along * 0.22 + bend) * 2.0)
					var room := along > TUNNEL_LEN - 7
					if across > (3.2 if room else 1.4):
						continue
					var j := lz * w + lx
					if heights[j] < floor_y:
						continue
					adit[j] = floor_y if adit[j] == 0 else mini(adit[j], floor_y)
					if room:
						flags[j] |= ENTRANCE


## The cave cut into a mountain's side from grid square gx, gz, if it has one:
## [x, z, the way in, the level of its floor], else empty.
func _tunnel(gx: int, gz: int) -> Array:
	var key := Vector2i(gx, gz)
	if not tunnels.has(key):
		tunnels[key] = _find_tunnel(gx, gz)
	return tunnels[key]


func _find_tunnel(gx: int, gz: int) -> Array:
	if _chance(gx, gz, 6) >= TUNNEL_CHANCE[settings.caves]:
		return []
	var x := gx * TUNNEL_GRID + 8 + _hash(gx, gz, 7) % (TUNNEL_GRID - 16)
	var z := gz * TUNNEL_GRID + 8 + _hash(gx, gz, 8) % (TUNNEL_GRID - 16)
	if n_mount.get_noise_2d(x, z) < MOUNTAIN_FROM[settings.mountains] + 0.1:
		return []
	# The slope around the spot, from the columns four cells to each side.
	var lay := lay_out(x - 4, z - 4, 3, 3, 4)
	var hh: PackedInt32Array = lay.heights
	if lay.kind[4] != MOUNTAIN or hh[4] <= sea + 4 or hh[4] >= size_y - 10:
		return []
	for k in 9:
		if lay.water[k] >= 0:
			return []
	var up := Vector2(hh[5] - hh[3], hh[7] - hh[1])
	if up.length() < 3.0:
		return []
	return [x + 0.5, z + 0.5, up.normalized(), hh[4]]


## The columns of a window laid out at once (tools, the spawn, the map).
func lay_out(x0: int, z0: int, w: int, h: int, step := 1) -> Dictionary:
	var lay := _window(x0, z0, w, h, step)
	for k in window_noises.size():
		_sample(lay, k)
	_lattice(lay)
	for lz in h:
		_layout_row(lay, lz)
	if step == 1 and w > 2 and h > 2:
		_entrances(lay)
		_banks(lay)
		_tunnels(lay)
	return lay


## True when no water lies within two columns of window column j.
static func _dry_around(water: PackedInt32Array, j: int) -> bool:
	for dz in range(-2, 3):
		var base := j + dz * WINDOW
		for dx in range(-2, 3):
			if water[base + dx] >= 0:
				return false
	return true


## A row of a 3D noise: `width` columns by every other level up to `depth`, as bytes
## (x + (y >> 1) * width), at the noise's offset.
static func _slice(n: FastNoiseLite, width: int, depth: int) -> PackedByteArray:
	# get_image_3d gives slices along z; a 1-deep volume with x along the row and y up.
	var imgs: Array = n.get_image_3d(width, depth / 2 + 1, 1, false, false)
	return (imgs[0] as Image).get_data()


# --- Places and the map ----------------------------------------------------------


## A column near `near` (in cells) that holds `what`: "lake", "river", "canyon" (a
## river between sheer walls), "swamp", "plateau", "cliffs" (a cliff coast), "beach",
## "mountain", "peak" (a snowy one), "waterfall", "rapids", "delta" (the arms of a
## river at its mouth), "pit" (a cave mouth in the plains), "adit" (one in the
## mountains),
## "forest", "taiga", "desert" or "tundra"; `near` itself when there is
## none within `reach` cells. Columns are laid out on a spiral `stride` cells apart.
## For tools and tests.
func find_place(what: String, near: Vector2i, reach := 6000, stride := 16) -> Vector2i:
	if _is_place(what, lay_out(near.x, near.y, 1, 1), 0):
		return near
	for r in range(1, reach / stride):
		# The ring of radius r: the rows north and south, the columns west and east.
		var a := r * stride
		for side: Array in [[-a, -a, 2 * r + 1, 1], [-a, a, 2 * r + 1, 1], [-a, -a + stride, 1, 2 * r - 1],
				[a, -a + stride, 1, 2 * r - 1]]:
			var x0: int = near.x + side[0]
			var z0: int = near.y + side[1]
			var lay := lay_out(x0, z0, side[2], side[3], stride)
			for j in side[2] * side[3]:
				if _is_place(what, lay, j):
					var w: int = side[2]
					return Vector2i(x0 + (j % w) * stride, z0 + (j / w) * stride)
	return near


func _is_place(what: String, lay: Dictionary, j: int) -> bool:
	var b: int = lay.biome[j]
	var kind: int = lay.kind[j]
	var feature: int = lay.feature[j]
	match what:
		"lake":
			return feature == LAKE and lay.lake[j] > 6.0
		"river":
			return feature == RIVER and kind == PLAIN
		"canyon":
			return feature == CANYON or (lay.cut[j] == CANYON_FLOOR and lay.heights[j] > sea)
		"gorge":
			return lay.cut[j] == GORGE and lay.heights[j] > sea + 2
		"mesa":
			return lay.cut[j] == MESA and lay.heights[j] > sea + 12
		"tor":
			return lay.cut[j] == TOR
		"swamp":
			return b == Biomes.SWAMP
		"plateau":
			return b == Biomes.PLATEAU
		"cliffs":
			return kind == CLIFFS and lay.heights[j] >= sea + 3 and lay.coast[j] < 6.0
		"beach":
			return b == Biomes.BEACH and feature == DRY and lay.coast[j] < 8.0 and kind == PLAIN
		"mountain":
			return b == Biomes.ROCK and kind == MOUNTAIN
		"peak":
			return kind == MOUNTAIN and lay.heights[j] >= sea + WorldData.SNOW_LINE + 3
		"waterfall":
			return lay.falls[j] == 2
		"rapids":
			return lay.falls[j] == 1
		"delta":
			return feature == RIVER and lay.coast[j] < 30.0 and lay.coast[j] > 10.0 and lay.river[j] > 8.0
		"pit":
			var mouths: PackedByteArray = lay.grids[10]
			return lay.flags[j] & ENTRANCE and kind == PLAIN and mouths[j] > _byte(0.7) and lay.heights[j] > sea + 7
		"adit":
			return lay.flags[j] & ENTRANCE and kind == MOUNTAIN
	# Any other name is a biome's ("forest", "desert"...), off the wooded slopes of
	# mountains, where trees grow whatever the biome.
	return b != Biomes.NONE and b == Biomes.named(what) and lay.flags[j] & WOODS == 0


## Colour of a laid-out column for a map of the world before it is walked: the sea by
## depth, lakes and rivers blue, land by biome, lighter higher up.
func column_color(lay: Dictionary, j: int) -> Color:
	var h: int = lay.heights[j]
	var wt: int = lay.water[j]
	if wt >= 0:
		var deep := clampf((wt - h - 1) / 6.0, 0.0, 1.0)
		return Color(0.36, 0.6, 0.68).lerp(Color(0.12, 0.24, 0.42), deep)
	var c := Biomes.color(lay.biome[j])
	return c * (0.75 + 0.5 * clampf((h - sea) / 24.0, 0.0, 1.0))


## The biome byte of a relief biome the loaded bundles may not give (-1): NONE then.
static func _biome(i: int) -> int:
	return i if i >= 0 else Biomes.NONE
