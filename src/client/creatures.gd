extends Node3D
## Animals of the prototype. Each one only knows its species properties; who is
## food or a threat comes from AiRules. Animals wander, graze, rest outside their
## active hours, flee from threats and hunt when hungry.

const AiRules := preload("res://src/shared/ai_rules.gd")
const Mat := preload("res://src/shared/materials.gd")
const SpriteArt := preload("res://src/client/sprite_art.gd")
const PixelView := preload("res://src/client/pixel_view.gd")

const RESPAWN_EVERY := 15.0


class Creature:
	var kind := ""
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	var state := "wander"
	var hunger := 0.0
	var think := 0.0
	var prey: Creature = null
	var sprite: Sprite3D


var world
var player: Node3D
var daylight := 1.0
var cut_height := 1000.0
## Camera basis; sprites are snapped to its pixel grid.
var view_basis := Basis.IDENTITY
var creatures: Array[Creature] = []
var rng := RandomNumberGenerator.new()
var textures := {}
var respawn_timer := 0.0


func setup(w, p: Node3D, seed_value: int) -> void:
	world = w
	player = p
	rng.seed = seed_value
	for kind in AiRules.SPECIES:
		if kind == "human":
			continue
		textures[kind] = SpriteArt.texture(kind)
		for i in AiRules.SPECIES[kind].count:
			_spawn(kind, false)


func count(kind: String) -> int:
	var n := 0
	for c in creatures:
		if c.kind == kind:
			n += 1
	return n


func _process(delta: float) -> void:
	if world == null:
		return
	delta = minf(delta, 0.1)
	respawn_timer += delta
	if respawn_timer > RESPAWN_EVERY:
		respawn_timer = 0.0
		for kind in AiRules.SPECIES:
			if kind != "human" and count(kind) < AiRules.SPECIES[kind].count:
				_spawn(kind, true)
	var light := 0.35 + 0.65 * daylight
	for c in creatures.duplicate():
		if not creatures.has(c):
			continue
		var spec: Dictionary = AiRules.SPECIES[c.kind]
		c.hunger = minf(1.0, c.hunger + delta * 0.012)
		c.think -= delta
		if c.think <= 0.0:
			c.think = 0.4 + rng.randf() * 0.3
			_decide(c, spec)
		_move(c, spec, delta)
		var lift := c.sprite.texture.get_height() / (2.0 * PixelView.PIXELS_PER_UNIT)
		c.sprite.position = PixelView.snap(c.pos + Vector3(0.0, lift, 0.0), view_basis)
		c.sprite.modulate = Color(light, light, light)
		c.sprite.visible = c.pos.y <= cut_height


func _decide(c: Creature, spec: Dictionary) -> void:
	var sight: float = spec.sight
	var threat_pos: Variant = null
	var threat_d := INF
	if AiRules.is_threat(c.kind, "human"):
		var d := c.pos.distance_to(player.position)
		if d < sight * 0.6:
			threat_pos = player.position
			threat_d = d
	var prey: Creature = null
	var prey_d := INF
	for o in creatures:
		if o == c:
			continue
		var d := c.pos.distance_to(o.pos)
		if d > sight:
			continue
		if d < threat_d and AiRules.is_threat(c.kind, o.kind):
			threat_pos = o.pos
			threat_d = d
		elif d < prey_d and AiRules.is_food(c.kind, o.kind):
			prey = o
			prey_d = d
	if threat_pos != null:
		c.state = "flee"
		var away: Vector3 = c.pos - threat_pos
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		c.target = c.pos + away.normalized() * 6.0
		return
	if not AiRules.is_active(c.kind, daylight):
		c.state = "rest"
		c.target = c.pos
		return
	if prey != null and c.hunger > 0.5:
		c.state = "hunt"
		c.prey = prey
		c.target = prey.pos
		return
	if "plants" in spec.diet:
		c.hunger = maxf(0.0, c.hunger - 0.04)
	if c.state != "wander" or c.pos.distance_to(c.target) < 0.3 or rng.randf() < 0.05:
		c.state = "wander"
		c.target = c.pos + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))


func _move(c: Creature, spec: Dictionary, delta: float) -> void:
	var speed: float = spec.speed
	match c.state:
		"rest":
			speed = 0.0
		"wander":
			speed *= 0.3
	var to := c.target - c.pos
	to.y = 0.0
	if speed > 0.0 and to.length() > 0.1:
		var step := to.normalized() * minf(speed * delta, to.length())
		var np := c.pos + step
		var gx := floori(np.x)
		var gz := floori(np.z)
		var ny: int = world.surface_y(gx, gz)
		if ny > 0 and ny < world.size_y and absi(ny - roundi(c.pos.y)) <= 1:
			c.pos = Vector3(np.x, lerpf(c.pos.y, float(ny), minf(1.0, delta * 12.0)), np.z)
			if absf(step.x) > 0.001:
				c.sprite.flip_h = step.x < 0.0
		else:
			c.target = c.pos
	if c.state == "hunt" and c.prey != null:
		if not creatures.has(c.prey):
			c.prey = null
			c.state = "wander"
		elif c.pos.distance_to(c.prey.pos) < 0.7:
			_remove(c.prey)
			c.prey = null
			c.hunger = 0.0
			c.state = "wander"


func _remove(c: Creature) -> void:
	creatures.erase(c)
	c.sprite.queue_free()


func _spawn(kind: String, away_from_player: bool) -> void:
	for attempt in 40:
		var x := rng.randi_range(2, world.size_x - 3)
		var z := rng.randi_range(2, world.size_z - 3)
		var y: int = world.surface_y(x, z)
		if y <= world.sea_level or y >= world.size_y or world.get_cell(x, y - 1, z) != Mat.GRASS:
			continue
		var pos := Vector3(x + 0.5, y, z + 0.5)
		if away_from_player and pos.distance_to(player.position) < 20.0:
			continue
		var c := Creature.new()
		c.kind = kind
		c.pos = pos
		c.target = pos
		c.hunger = rng.randf() * 0.5
		c.think = rng.randf() * 0.5
		c.sprite = Sprite3D.new()
		PixelView.setup_sprite(c.sprite, textures[kind])
		add_child(c.sprite)
		creatures.append(c)
		return
