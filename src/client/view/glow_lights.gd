extends Node3D
## The small pools of light round the glowing mushrooms at night: a few short teal
## lights stand at the groups nearest the view (Foliage notes where each mushroom
## grows, ChunkStreamer hands them over chunk by chunk); the rest glow on their own
## (grass.gdshader) without lighting the ground. Mushrooms closer than APART share a
## light. The lights fade in with the dark as the caps do (night_glow) and go under
## the snow with the mushrooms.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## How many lights the mushrooms get: a phone pays for every light on every mesh it
## reaches, so the few nearest only.
const LIGHTS := 4
## How far round a group its light reaches, in world units (a cell is half a unit).
const REACH := 1.6
const ENERGY := 0.9
const COLOR := Color(0.35, 0.95, 0.8)
## How high over the mushrooms the light hangs, in world units.
const LIFT := 0.3
## Mushrooms closer than this (world units) share one light.
const APART := 2.0
## Groups farther than this from the middle of the view get no light.
const NEAR := 18.0
## How often the lights are handed to the nearest groups, in seconds.
const PICK_EVERY := 0.4

## Where the glowing mushrooms of each shown chunk stand, by its key.
var spots := {}
var lights: Array[OmniLight3D] = []
## Where each light stands, its group's place (world units), or INF while unused.
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


## Notes the glowing mushrooms of chunk `key` (none when it goes).
func set_spots(key: Vector2i, at: PackedVector3Array) -> void:
	if at.is_empty():
		spots.erase(key)
	else:
		spots[key] = at
	_wait = 0.0


## Lights the groups nearest the screen-plane point `view` as dark as `sky` (sky.gd)
## makes it and as the snow of `clock` (Clock) leaves them.
func update(delta: float, view: Vector2, sky, clock) -> void:
	var night := smoothstep(0.6, 0.15, sky.daylight)
	var show := night * (1.0 - smoothstep(0.25, 0.4, clock.snow))
	if show <= 0.0 or spots.is_empty():
		for light in lights:
			light.visible = false
		_wait = 0.0
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = PICK_EVERY
		_pick(view)
	_clock += delta
	for i in LIGHTS:
		var light := lights[i]
		var p := places[i]
		light.visible = p != Vector3.INF
		if not light.visible:
			continue
		# Placed where the view draws it now (a turn of the view moves it), breathing
		# slowly as the caps do.
		light.position = PixelView.shear(p + Vector3(0.0, LIFT, 0.0))
		light.omni_range = PixelView.light_range(REACH)
		light.light_energy = ENERGY * show * (0.9 + 0.1 * sin(_clock * 1.1 + float(i) * 1.7))


## Hands the lights to the groups nearest `view`, one light a group.
func _pick(view: Vector2) -> void:
	var near: Array = []
	var span := WorldData.CHUNK * WorldData.CELL
	for key: Vector2i in spots:
		# Chunks far off east or west are passed over (north and south the height
		# shifts the screen plane).
		if absf((key.x + 0.5) * span - view.x) > NEAR + span:
			continue
		for p in spots[key] as PackedVector3Array:
			var d := PixelView.screen_plane(p).distance_squared_to(view)
			if d < NEAR * NEAR:
				near.append([d, p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen: Array[Vector3] = []
	for e: Array in near:
		if chosen.size() >= LIGHTS:
			break
		var p: Vector3 = e[1]
		var alone := true
		for c in chosen:
			if c.distance_squared_to(p) < APART * APART:
				alone = false
				break
		if alone:
			chosen.append(p)
	for i in LIGHTS:
		places[i] = chosen[i] if i < chosen.size() else Vector3.INF
