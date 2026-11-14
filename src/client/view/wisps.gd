extends Node3D
## Will-o'-the-wisps: on nights out of winter a few pale flames hang and wander over the
## murky water of swamps and bogs (WorldCells.murk) near the view. One comes near
## the player and it slips away, fading, and lights up again elsewhere later. Each is a
## small emitter of flickering specks (Effects' particle look), no light of its own.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldCells := preload("res://src/shared/world/world_cells.gd")
const ParticleShader := preload("res://shaders/particle.gdshader")
const Mat := preload("res://src/shared/content/materials.gd")

const CELL := WorldData.CELL
## How many may hang at once, and how far round the view (world units) they are looked
## for, by FIND_TRIES columns every FIND_EVERY seconds while fewer hang.
const WISPS := 4
const REACH := 14.0
const FIND_TRIES := 40
const FIND_EVERY := 2.0
## The player this near (world units) makes one slip away; it fades over FADE seconds.
const SHY := 2.5
const FADE := 1.5
## How high over the water one hangs (world units) and how far it wanders from its place.
const HOVER := Vector2(0.4, 1.0)
const WANDER := 0.6
const FLEE_SPEED := 2.5
const COLOR := Color(0.62, 0.92, 0.86)

## The world (WorldData) the water is looked at in.
var world
## Each: {"node": CPUParticles3D, "home": Vector3 (world), "phase": float, "fade": 0..1,
## "fleeing": Vector3 (the way away, zero while it hangs)}.
var wisps: Array = []
var _wait := 0.0
var _clock := 0.0
var rng := RandomNumberGenerator.new()


## `night` 0..1 (Sky: night_glow), `winter` true in winter; `view` the screen-plane
## middle, `player` the player's world position.
func update(delta: float, view: Vector2, player: Vector3, night: float, winter: bool, on := true) -> void:
	_clock += delta
	var wanted := on and night > 0.5 and not winter and world != null
	for i in range(wisps.size() - 1, -1, -1):
		var w: Dictionary = wisps[i]
		var p: CPUParticles3D = w.node
		var home: Vector3 = w.home
		var gone: bool = not wanted or PixelView.screen_plane(home).distance_to(view) > REACH * 1.5
		if not gone and w.fleeing == Vector3.ZERO and Vector2(home.x - player.x, home.z - player.z).length() < SHY:
			var away := Vector3(home.x - player.x, 0.0, home.z - player.z).normalized()
			w.fleeing = away if away != Vector3.ZERO else Vector3.RIGHT
		if w.fleeing != Vector3.ZERO:
			w.home = home + w.fleeing * FLEE_SPEED * delta
			gone = true
		w.fade = clampf(w.fade + (-delta if gone else delta) / FADE, 0.0, 1.0)
		if w.fade <= 0.0 and gone:
			p.queue_free()
			wisps.remove_at(i)
			continue
		var t: float = _clock * 0.4 + w.phase
		var at: Vector3 = w.home + Vector3(sin(t) * WANDER, sin(t * 1.7) * 0.15, cos(t * 0.8) * WANDER)
		p.position = at
		var flicker := 0.75 + 0.25 * sin(_clock * 9.0 + w.phase * 5.0)
		p.color = Color(COLOR.r, COLOR.g, COLOR.b, w.fade * flicker)
	if not wanted:
		_wait = 0.0
		return
	_wait -= delta
	if _wait <= 0.0 and wisps.size() < WISPS:
		_wait = FIND_EVERY
		_find(view, player)


## Looks for murky water near `view`, away from `player`, for one more wisp.
func _find(view: Vector2, player: Vector3) -> void:
	for i in FIND_TRIES:
		var x := floori((view.x + rng.randf_range(-REACH, REACH)) / CELL)
		var z := floori((view.y + player.y + rng.randf_range(-REACH, REACH)) / CELL)
		var y: int = WorldCells.top_level(world.water_col(x, z))
		if y < 0 or world.get_cell(x, y + 1, z) != Mat.AIR or world.murk(x, y, z) == 0:
			continue
		var home := Vector3((x + 0.5) * CELL, (y + 1) * CELL + rng.randf_range(HOVER.x, HOVER.y), (z + 0.5) * CELL)
		if Vector2(home.x - player.x, home.z - player.z).length() < SHY * 1.5:
			continue
		_add(home)
		return


func _add(home: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0 / 16.0, 2.0 / 16.0)
	var mat := ShaderMaterial.new()
	mat.shader = ParticleShader
	mat.set_shader_parameter("brightness", 1.3)
	mat.set_shader_parameter("sky_only", 1.0)
	quad.material = mat
	p.mesh = quad
	p.extra_cull_margin = 32.0
	p.position = home
	p.color = Color(COLOR.r, COLOR.g, COLOR.b, 0.0)
	p.emitting = true
	add_child(p)
	wisps.append({"node": p, "home": home, "phase": rng.randf() * TAU, "fade": 0.0, "fleeing": Vector3.ZERO})
