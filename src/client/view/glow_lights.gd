extends Node3D
## Small pools of light round things that shine by themselves: a few short lights stand
## at the spots nearest the view, the rest glow on their own without lighting the ground.
## Two sets of them (Effects): the glowing mushrooms (Foliage notes where each grows,
## ChunkStreamer hands them over chunk by chunk), teal, lit with the dark as the caps
## are (night_glow), under the sea's surface by day too (in a cave the dark is always
## there, as grass.gdshader's dark_glow), and gone under the snow; and the cells that
## cast light (`lit`: lava, crystals, Mat.lights, where ChunkMesher finds them showing to
## the air), lit always, each in its material's colour. Spots closer than APART share
## a light.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## How many lights a set gets: a phone pays for every light on every mesh it reaches,
## so the few nearest only.
const LIGHTS := 4
## How far round a spot its light reaches, in world units (a cell is half a unit).
const REACH := 1.6
## How bright a spot's light is: each its own, between these (a pale glow).
const ENERGY := Vector2(0.22, 0.45)
const COLOR := Color(0.35, 0.95, 0.8)
## How high over the spot the light hangs, in world units.
const LIFT := 0.3
## Spots closer than this (world units) share one light.
const APART := 2.0
## Spots farther than this from the middle of the view get no light.
const NEAR := 18.0
## How often the lights are handed to the nearest spots, in seconds.
const PICK_EVERY := 0.4
## The cells that cast light: farther, brighter and further apart than the mushrooms.
const LIT_REACH := 3.2
const LIT_ENERGY := Vector2(0.6, 0.9)
const LIT_APART := 3.0

## True for the set of the cells that cast light (lit always, in Mat.lights colours).
var lit := false
## The height of the sea's surface (world units): mushrooms below it glow by day too.
var sea_top := INF
## Where the spots of each shown chunk stand, by its key, and for `lit` the material of
## each.
var spots := {}
var mats := {}
var lights: Array[OmniLight3D] = []
## Where each light stands, its spot's place (world units), or INF while unused.
var places: Array[Vector3] = []
var _wait := 0.0
var _clock := 0.0


func _ready() -> void:
	for i in LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.omni_attenuation = 0.0
		light.light_energy = 0.0
		light.visible = false
		add_child(light)
		lights.append(light)
		places.append(Vector3.INF)


## Notes the spots of chunk `key` (none when it goes) and, for `lit`, their materials.
func set_spots(key: Vector2i, at: PackedVector3Array, of := PackedByteArray()) -> void:
	if at.is_empty():
		spots.erase(key)
		mats.erase(key)
	else:
		spots[key] = at
		mats[key] = of
	_wait = 0.0


## Lights the spots nearest the screen-plane point `view` as dark as `sky` (sky.gd)
## makes it and as the snow of `clock` (Clock) leaves them.
func update(delta: float, view: Vector2, sky, clock) -> void:
	var night := 1.0 if lit else smoothstep(0.6, 0.15, sky.daylight)
	var snow := 1.0 if lit else 1.0 - smoothstep(0.25, 0.4, clock.snow)
	if spots.is_empty() or (night <= 0.0 and sea_top == INF) or snow <= 0.0:
		for light in lights:
			light.visible = false
		_wait = 0.0
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = PICK_EVERY
		_pick(view, night)
	_clock += delta
	for i in LIGHTS:
		var light := lights[i]
		var p := places[i]
		light.visible = p != Vector3.INF
		if not light.visible:
			continue
		# Placed where the view draws it now (a turn of the view moves it), breathing
		# slowly as the caps do (lava a little quicker).
		light.position = PixelView.shear(p + Vector3(0.0, LIFT, 0.0))
		light.omni_range = PixelView.light_range(LIT_REACH if lit else REACH)
		var shown := maxf(night, _deep(p)) * snow
		light.light_energy = brightness(p, lit) * shown * (0.9 + 0.1 * sin(_clock * (1.7 if lit else 1.1) + float(i) * 1.7))


## How much the dark of the depths lights a mushroom at `p`: none above the sea's
## surface, fully a few levels below (where sea_bright has dimmed the day).
func _deep(p: Vector3) -> float:
	if lit or sea_top == INF:
		return 0.0
	return clampf((sea_top - p.y) / (WorldData.CELL * 4.0), 0.0, 1.0)


## How bright the light of the spot at `p` is: the same each time, but not the same as
## the next spot's.
static func brightness(p: Vector3, of_lit := false) -> float:
	var k := fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)
	var e := LIT_ENERGY if of_lit else ENERGY
	return lerpf(e.x, e.y, k)


## Hands the lights to the shown spots nearest `view`, one light a spot (and its
## neighbours within APART); `night` 0 leaves the mushrooms above the sea unlit.
func _pick(view: Vector2, night: float) -> void:
	var near: Array = []
	var span := WorldData.CHUNK * WorldData.CELL
	for key: Vector2i in spots:
		# Chunks far off east or west are passed over (north and south the height
		# shifts the screen plane).
		if absf((key.x + 0.5) * span - view.x) > NEAR + span:
			continue
		var at: PackedVector3Array = spots[key]
		var of: PackedByteArray = mats[key]
		for j in at.size():
			var p := at[j]
			if night <= 0.0 and _deep(p) <= 0.0:
				continue
			var d := PixelView.screen_plane(p).distance_squared_to(view)
			if d < NEAR * NEAR:
				near.append([d, p, of[j] if j < of.size() else -1])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var apart := LIT_APART if lit else APART
	var chosen: Array[Vector3] = []
	for e: Array in near:
		if chosen.size() >= LIGHTS:
			break
		var p: Vector3 = e[1]
		var alone := true
		for c in chosen:
			if c.distance_squared_to(p) < apart * apart:
				alone = false
				break
		if alone:
			if lit and e[2] >= 0 and e[2] < Mat.lights.size() and Mat.lights[e[2]] != null:
				lights[chosen.size()].light_color = Mat.lights[e[2]]
			chosen.append(p)
	for i in LIGHTS:
		places[i] = chosen[i] if i < chosen.size() else Vector3.INF
