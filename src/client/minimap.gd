extends Control
## The minimap in a corner of the screen and the map of everything explored. The
## ground is drawn a pixel for every two cells, painted in as chunks are generated:
## the colour of the top from above, water by depth, dark green under a crown. The
## world has no edge, so the explored map is kept in square regions of REGION chunks,
## each an image sent to the renderer once a frame at most. The corner shows the ground
## around the player with the player as a dot in the middle; a tap on it (or M) opens
## the whole map (MapView), which draws the same regions. Things the player placed
## (a workbench, a campfire, chests) are marked on both: a dot of the colour of their
## picture here, the picture itself on the whole map.

const UiStyle := preload("res://src/client/ui_style.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const ItemIcons := preload("res://src/client/item_icons.gd")

## The map on screen, in UI pixels, and the cells per pixel.
const SIZE := 72
const STEP := 2
const FRAME := 2
## Chunks along a side of a region, and its pixels.
const REGION := 32
const REGION_SHIFT := 5
const REGION_PX := REGION * WorldData.CHUNK / STEP
const CHUNK_PX := WorldData.CHUNK / STEP
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

## The explored map by region (Vector2i): {"image", "texture", "dirty"}. Region r holds
## the columns r * REGION * CHUNK on, each pixel two by two cells.
var regions := {}
## The player's column.
var player_cell := Vector2i.ZERO
## The things placed, [middle column, item id] each (see set_marks), and the colour
## of each item's mark by id.
var marks: Array = []
var _mark_colors := {}
var sea := 0
var top := 0
## Asks for the whole map (see Hud).
signal open_map
## New ground was painted in (the whole map redraws).
signal painted


func _init() -> void:
	custom_minimum_size = Vector2(SIZE + 2 * FRAME, SIZE + 2 * FRAME)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Карта (M)"


## An empty map of a new world.
func setup(gen: WorldGen) -> void:
	sea = gen.world.sea_level
	top = gen.world.size_y
	regions.clear()
	queue_redraw()


func _region(key: Vector2i) -> Dictionary:
	if not regions.has(key):
		var img := Image.create_empty(REGION_PX, REGION_PX, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		regions[key] = {"image": img, "texture": null, "dirty": true}
	return regions[key]


## Draws the columns of a chunk (every STEP cells) once they are final.
func paint_chunk(w: WorldData, key: Vector2i) -> void:
	var data := PackedByteArray()
	data.resize(CHUNK_PX * CHUNK_PX * 4)
	var x0: int = key.x * WorldData.CHUNK
	var z0: int = key.y * WorldData.CHUNK
	var i := 0
	for z in range(z0, z0 + WorldData.CHUNK, STEP):
		for x in range(x0, x0 + WorldData.CHUNK, STEP):
			var c := _color(w, x, z)
			data[i] = c.r8
			data[i + 1] = c.g8
			data[i + 2] = c.b8
			data[i + 3] = 255
			i += 4
	var r := _region(Vector2i(key.x >> REGION_SHIFT, key.y >> REGION_SHIFT))
	var img: Image = r.image
	img.blit_rect(Image.create_from_data(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8, data),
		Rect2i(0, 0, CHUNK_PX, CHUNK_PX), Vector2i((key.x & (REGION - 1)) * CHUNK_PX, (key.y & (REGION - 1)) * CHUNK_PX))
	r.dirty = true


## Repaints the column of a changed cell.
func touch(w: WorldData, cell: Vector3i) -> void:
	var key := WorldData.chunk_key(cell.x, cell.z)
	var rk := Vector2i(key.x >> REGION_SHIFT, key.y >> REGION_SHIFT)
	if not regions.has(rk):
		return
	var x: int = cell.x & ~(STEP - 1)
	var z: int = cell.z & ~(STEP - 1)
	var span := REGION * WorldData.CHUNK
	var r: Dictionary = regions[rk]
	var img: Image = r.image
	img.set_pixel((x & (span - 1)) / STEP, (z & (span - 1)) / STEP, _color(w, x, z))
	r.dirty = true


## Colour of a column from above: water by depth, else the top shaded by its height,
## dark green under a crown.
func _color(w: WorldData, x: int, z: int) -> Color:
	var ch: WorldData.Chunk = w.chunk_at(x, z)
	if ch == null:
		return UNSEEN
	var col := WorldData.col_of(x, z)
	var air: int = ch.air[col]
	var water: int = ch.water[col]
	var leaf: int = ch.leaf[col]
	var y := WorldData.top_level(~(air | leaf | ch.logs[col]) & w.all_bits)
	if y < 0:
		return UNSEEN
	if water & (1 << y):
		var floor_y := WorldData.top_level(~(air | water) & w.all_bits)
		return SHALLOW.lerp(DEEP, clampf((y - floor_y - 1) / 6.0, 0.0, 1.0))
	var m: int = ch.cells[y * WorldData.LAYER + col]
	var c: Color = colors.get(m, Color(0.5, 0.5, 0.5))
	c = c * (0.7 + 0.6 * clampf((y - sea) / float(top - sea), 0.0, 1.0))
	if leaf != 0:
		c = c.lerp(LEAVES, 0.75)
	c.a = 1.0
	return c


## Sends the changed regions to the renderer.
func flush() -> void:
	var changed := false
	for r: Dictionary in regions.values():
		if r.dirty:
			r.dirty = false
			changed = true
			if r.texture == null:
				r.texture = ImageTexture.create_from_image(r.image)
			else:
				r.texture.update(r.image)
	if changed:
		queue_redraw()
		painted.emit()


## Marks the things placed (Props.placed: "item", "cell" the north-west of its two
## by two cells) when they changed.
func set_marks(placed: Array) -> void:
	var now := []
	for e: Dictionary in placed:
		var c: Vector3i = e.cell
		now.append([Vector2i(c.x + 1, c.z + 1), e.item])
	if now != marks:
		marks = now
		queue_redraw()
		painted.emit()


## The colour of item `id`'s mark: the mean of its picture's pixels.
func _mark_color(id: String) -> Color:
	if not _mark_colors.has(id):
		var c := UiStyle.INK
		var tex := ItemIcons.of_item(id)
		if tex != null:
			var img := tex.get_image()
			var sum := Color(0, 0, 0, 0)
			for y in img.get_height():
				for x in img.get_width():
					var p := img.get_pixel(x, y)
					sum += Color(p.r, p.g, p.b, 1.0) * p.a
			if sum.a > 0.0:
				c = Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a)
		_mark_colors[id] = c
	return _mark_colors[id]


func set_player(cell: Vector2i) -> void:
	if cell != player_cell:
		player_cell = cell
		queue_redraw()


## Draws the explored map on `canvas` inside `rect` (its UI pixels), the column
## `centre` (in cells, may be fractional) in the middle, `zoom` UI pixels per map pixel,
## and the marks of the things placed, as pictures with `pictures`.
func draw_map(canvas: CanvasItem, rect: Rect2, centre: Vector2, zoom: float, pictures := false) -> void:
	var span := REGION * WorldData.CHUNK
	var mid := rect.get_center()
	# The regions the rectangle shows.
	var half := rect.size * 0.5 / zoom * STEP
	var from := Vector2i(((centre - half) / span).floor())
	var to := Vector2i(((centre + half) / span).floor())
	for rz in range(from.y, to.y + 1):
		for rx in range(from.x, to.x + 1):
			var r: Dictionary = regions.get(Vector2i(rx, rz), {})
			if r.is_empty() or r.texture == null:
				continue
			var at := (mid + (Vector2(rx, rz) * span - centre) / STEP * zoom).floor()
			var full := Rect2(at, Vector2(REGION_PX, REGION_PX) * zoom)
			var shown := full.intersection(rect)
			if shown.size.x <= 0.0 or shown.size.y <= 0.0:
				continue
			canvas.draw_texture_rect_region(r.texture, shown, Rect2((shown.position - at) / zoom, shown.size / zoom))
	for m: Array in marks:
		var p := (mid + (Vector2(m[0]) - centre) / STEP * zoom).floor()
		if pictures:
			var tex := ItemIcons.of_item(m[1])
			if tex == null:
				continue
			var box := Rect2(p - (tex.get_size() * 0.5).floor() - Vector2(1, 1), tex.get_size() + Vector2(2, 2))
			if rect.encloses(box):
				canvas.draw_rect(box, UiStyle.DARK_INK)
				canvas.draw_texture(tex, box.position + Vector2(1, 1))
		else:
			var box := Rect2(p - Vector2(2, 2), Vector2(5, 5))
			if rect.encloses(box):
				canvas.draw_rect(box, UiStyle.DARK_INK)
				canvas.draw_rect(box.grow(-1), _mark_color(m[1]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		open_map.emit()
		accept_event()


func _draw() -> void:
	draw_style_box(UiStyle.panel(), Rect2(Vector2.ZERO, size))
	var inner := Rect2(FRAME, FRAME, SIZE, SIZE)
	draw_rect(inner, UNSEEN)
	draw_map(self, inner, Vector2(player_cell), 1.0)
	var mid := inner.position + (inner.size * 0.5).floor()
	draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
	draw_rect(Rect2(mid, Vector2(1, 1)), UiStyle.INK)
