extends Control
## The minimap in a corner of the screen: the ground around the player, a pixel for
## every two cells, drawn in as the world is generated around them, with the player
## as a dot in the middle. A tap on it (or M) shows the whole island instead, from the
## coarse layout of the generator, with the player's place marked. The map is kept as
## an image of the whole world and sent to the renderer once a frame at most.

const UiStyle := preload("res://src/client/ui_style.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")

## The map on screen, in UI pixels, and the cells per pixel of the near map.
const SIZE := 72
const STEP := 2
const FRAME := 2
## Colours of the ground by its top, shaded by height (a var: the materials are data
## of the core mod, not constants).
var colors: Dictionary = {
	Mat.GRASS: Color(0.38, 0.56, 0.26), Mat.DIRT: Color(0.5, 0.38, 0.24), Mat.STONE: Color(0.56, 0.56, 0.56),
	Mat.SAND: Color(0.84, 0.76, 0.5), Mat.CLAY: Color(0.6, 0.47, 0.38), Mat.COPPER_ORE: Color(0.62, 0.5, 0.4),
	Mat.LOG: Color(0.4, 0.28, 0.16), Mat.PLANKS: Color(0.6, 0.45, 0.25), Mat.BRICK: Color(0.6, 0.3, 0.25),
}
const LEAVES := Color(0.18, 0.38, 0.16)
const SHALLOW := Color(0.36, 0.6, 0.68)
const DEEP := Color(0.12, 0.24, 0.42)
const UNSEEN := Color(0.1, 0.1, 0.12)

var image: Image
var texture: ImageTexture
var island: ImageTexture
var island_scale := 1
var dirty := false
var whole := false
## The player's column and the map's size in cells.
var player_cell := Vector2i.ZERO
var cells := Vector2i.ZERO
var sea := 0
var top := 0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE + 2 * FRAME, SIZE + 2 * FRAME)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Карта (M): вокруг или весь остров"


## Makes the empty map of the world and the picture of the whole island.
func setup(gen: WorldGen) -> void:
	var w: WorldData = gen.world
	cells = Vector2i(w.size_x, w.size_z)
	sea = w.sea_level
	top = w.size_y
	image = Image.create_empty(ceili(w.size_x / float(STEP)), ceili(w.size_z / float(STEP)), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(image)
	var coarse := Image.create_empty(gen.gw, gen.gh, false, Image.FORMAT_RGB8)
	for j in gen.gh:
		for i in gen.gw:
			coarse.set_pixel(i, j, gen.coarse_color(i, j))
	island_scale = maxi(1, SIZE / maxi(gen.gw, gen.gh))
	island = ImageTexture.create_from_image(coarse)
	queue_redraw()


## Draws the columns of a chunk (every STEP cells) once they are final.
func paint_chunk(w: WorldData, key: Vector2i) -> void:
	if image == null:
		return
	var x0: int = key.x * WorldData.CHUNK
	var z0: int = key.y * WorldData.CHUNK
	for z in range(z0, mini(z0 + WorldData.CHUNK, w.size_z), STEP):
		for x in range(x0, mini(x0 + WorldData.CHUNK, w.size_x), STEP):
			image.set_pixel(x / STEP, z / STEP, _color(w, x, z))
	dirty = true


## Repaints the column of a changed cell.
func touch(w: WorldData, cell: Vector3i) -> void:
	if image == null or cell.x < 0 or cell.z < 0 or cell.x >= w.size_x or cell.z >= w.size_z:
		return
	var x: int = cell.x - cell.x % STEP
	var z: int = cell.z - cell.z % STEP
	image.set_pixel(x / STEP, z / STEP, _color(w, x, z))
	dirty = true


## Colour of a column from above: water by depth, else the top shaded by its height,
## dark green under a crown.
func _color(w: WorldData, x: int, z: int) -> Color:
	var col: int = z * w.size_x + x
	var air: int = w.air_cols[col]
	var water: int = w.water_cols[col]
	var y := WorldData.top_level(~(air | w.leaf_cols[col] | w.log_cols[col]) & w.all_bits)
	if y < 0:
		return UNSEEN
	if water & (1 << y):
		var floor_y := WorldData.top_level(~(air | water) & w.all_bits)
		return SHALLOW.lerp(DEEP, clampf((y - floor_y - 1) / 6.0, 0.0, 1.0))
	var m: int = w.cells[y * w.size_x * w.size_z + col]
	var c: Color = colors.get(m, Color(0.5, 0.5, 0.5))
	c = c * (0.7 + 0.6 * clampf((y - sea) / float(top - sea), 0.0, 1.0))
	if w.leaf_cols[col] != 0:
		c = c.lerp(LEAVES, 0.75)
	c.a = 1.0
	return c


## Sends the changed map to the renderer.
func flush() -> void:
	if dirty:
		dirty = false
		texture.update(image)
		queue_redraw()


func set_player(cell: Vector2i) -> void:
	if cell != player_cell:
		player_cell = cell
		queue_redraw()


func toggle() -> void:
	whole = not whole
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		toggle()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_style_box(UiStyle.panel(), Rect2(Vector2.ZERO, size))
	var inner := Rect2(FRAME, FRAME, SIZE, SIZE)
	draw_rect(inner, UNSEEN)
	if texture == null:
		return
	if whole:
		var island_size := Vector2(island.get_width(), island.get_height()) * island_scale
		var at := (inner.position + (inner.size - island_size) * 0.5).floor()
		draw_texture_rect(island, Rect2(at, island_size), false)
		var p := at + Vector2(player_cell) / float(WorldGen.COARSE) * island_scale
		draw_rect(Rect2(p.floor() - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
	else:
		# The part of the map around the player, clipped to the map.
		var centre := Vector2(player_cell) / STEP
		var src := Rect2(centre - inner.size * 0.5, inner.size).intersection(Rect2(0, 0, image.get_width(), image.get_height()))
		if src.size.x > 0 and src.size.y > 0:
			var dst := Rect2(inner.position + src.position - (centre - inner.size * 0.5), src.size)
			draw_texture_rect_region(texture, Rect2(dst.position.floor(), dst.size.ceil()), src)
		var mid := inner.position + (inner.size * 0.5).floor()
		draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
		draw_rect(Rect2(mid, Vector2(1, 1)), UiStyle.INK)
