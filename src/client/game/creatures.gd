extends Node3D
## The animals drawn (the rules are Wildlife, src/shared): a sprite for each, put where
## it walks and turned the way it faces, and the paw prints it leaves (see tracks.gd).
## Animals off the screen move in steps (Wildlife.FAR_STEP), and their sprites are
## put again only then.

const AiRules := preload("res://src/shared/content/ai_rules.gd")
const SpriteArt := preload("res://src/client/view/sprite_art.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")

## Animals off the screen by more than this many world units are not near (see
## Wildlife.Animal.near).
const FAR_MARGIN := 4.0

var wildlife
## Footprints (see tracks.gd); animals leave paw prints sized by their mass.
var tracks
## kind -> [mesh, material]
var looks := {}
var _sprites := {}


## Draws the animals of `w` (Wildlife) from now on, those there already and those to come.
func watch(w) -> void:
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var tex := SpriteArt.texture(AiRules.SPECIES[kind].sprite)
		looks[kind] = [PixelView.sprite_mesh(tex.get_width(), tex.get_height()),
			PlayerScript.sprite_material(SpriteShader, tex)]
	wildlife = w
	for a in w.animals:
		_on_born(a)
	w.born.connect(_on_born)
	w.gone.connect(_on_gone)
	w.stepped.connect(_on_stepped)


func _process(delta: float) -> void:
	if wildlife == null:
		return
	var seen := _seen()
	for a in wildlife.animals:
		a.near = seen.has_point(PixelView.screen_plane(a.pos))
	wildlife.update(delta)
	for a in wildlife.animals:
		if a.away == 0.0:
			var sprite: MeshInstance3D = _sprites[a]
			sprite.position = PixelView.snap(a.pos)
			# Facing east or west in the world, which way on the screen.
			sprite.scale.x = a.facing * (1.0 if PixelView.right.x >= 0.0 else -1.0)


## The screen-plane rectangle the camera shows, FAR_MARGIN larger all round (all of
## the plane without a camera).
func _seen() -> Rect2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var half := get_viewport().get_visible_rect().size / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * FAR_MARGIN
	var centre := PixelView.plane_of(Vector2(cam.global_position.x, cam.global_position.z))
	return Rect2(centre - half, half * 2.0)


func _on_born(a) -> void:
	var sprite := MeshInstance3D.new()
	sprite.mesh = looks[a.kind][0]
	sprite.material_override = looks[a.kind][1]
	sprite.extra_cull_margin = 24.0
	sprite.position = PixelView.snap(a.pos)
	add_child(sprite)
	_sprites[a] = sprite


func _on_gone(a) -> void:
	_sprites[a].queue_free()
	_sprites.erase(a)


func _on_stepped(_a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	if tracks != null:
		tracks.leave(at, dir, left, false, size)
