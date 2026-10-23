extends Control
## The minimap in a corner of the screen and the map of everything explored. The
## ground is drawn a pixel for every two cells, painted in as chunks are generated:
## the colour of the top from above, water by depth, dark green under a crown. The
## world has no edge, so the explored map is kept in square regions of REGION chunks,
## each an image sent to the renderer once a frame at most. The corner shows the ground
## around the player with the player as a dot in the middle; a tap on it (or M) opens
## the whole map (MapView), which draws the same regions. Things the player placed
## (a workbench, a campfire, chests) are marked on both: a dot of the colour of their
## picture here, the picture itself on the whole map. So are the sacks of the player's
## deaths, a red dot here kept at the edge while the sack is beyond it.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

## The map on screen, in UI pixels, and the cells per pixel.
const SIZE := 72
const STEP := 2
## The panel's frame round the map: its outline and highlight, then a sunken edge.
const FRAME := 4
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
	Mat.SCREE: Color(0.6, 0.58, 0.55),
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
## The things placed and the sacks, [middle column, item id or Items.SACK] each (see
## set_marks), and the colour of each item's mark by id.
var marks: Array = []
var _mark_colors := {}
var sea := 0
var top := 0
var _frame := UiStyle.panel()
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
## by two cells) and the sacks at `sacks` (world units) when they changed.
func set_marks(placed: Array, sacks: Array[Vector3] = []) -> void:
	var now := []
	for p in sacks:
		now.append([Vector2i(floori(p.x / WorldData.CELL), floori(p.z / WorldData.CELL)), Items.SACK])
	for e: Dictionary in placed:
		var c: Vector3i = e.cell
		now.append([Vector2i(c.x + 1, c.z + 1), e.item])
	if now != marks:
		marks = now
		queue_redraw()
		painted.emit()


## The colour of item `id`'s mark: the mean of its picture's pixels (from the
## picture's rows: reading a texture back is slow in the browser).
func _mark_color(id: String) -> Color:
	if id == Items.SACK:
		return UiStyle.DANGER
	if not _mark_colors.has(id):
		var c := UiStyle.INK
		var item := ItemIcons.Items.get_item(id)
		var rows: Array = ItemIcons.PICTURES.get(item.get("icon", ""), [])
		var sum := Color(0, 0, 0, 0)
		for row: String in rows:
			for ch in row:
				if ItemIcons.PALETTE.has(ch):
					var p: Color = ItemIcons.PALETTE[ch]
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
## and the marks of the things placed and the sacks, as pictures with `pictures`.
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
	# Dots of things placed side by side would cover each other: the first placed is
	# drawn (the sacks come first). Pictures overlap, the later on top, and part when
	# the map is zoomed in. A sack beyond the edge is drawn at the edge, towards it.
	var drawn: Array[Rect2] = []
	for m: Array in marks:
		var p := (mid + (Vector2(m[0]) - centre) / STEP * zoom).floor()
		var sack: bool = m[1] == Items.SACK
		var tex: Texture2D = null
		if pictures:
			tex = ItemIcons.picture("sack") if sack else ItemIcons.of_item(m[1])
			if tex == null:
				continue
		var box := Rect2(p - Vector2(2, 2), Vector2(5, 5))
		if pictures:
			box = Rect2(p - (tex.get_size() * 0.5).floor() - Vector2(1, 1), tex.get_size() + Vector2(2, 2))
		if sack and not rect.encloses(box):
			box.position = box.position.clamp(rect.position, rect.end - box.size)
		if not rect.encloses(box) or (not pictures and drawn.any(func(b: Rect2) -> bool: return b.intersects(box))):
			continue
		drawn.append(box)
		canvas.draw_rect(box, UiStyle.DARK_INK)
		if pictures:
			canvas.draw_texture(tex, box.position + Vector2(1, 1))
		else:
			canvas.draw_rect(box.grow(-1), _mark_color(m[1]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		open_map.emit()
		accept_event()


## In the frame of the panels and buttons beside it: the map sunk into it like a slot,
## shaded along the top and left, the player an amber dot outlined dark.
func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner := Rect2(FRAME, FRAME, SIZE, SIZE)
	draw_rect(inner.grow(1), UiStyle.EDGE)
	draw_rect(inner, UNSEEN)
	draw_map(self, inner, Vector2(player_cell), 1.0)
	draw_rect(Rect2(inner.position, Vector2(SIZE, 1)), UiStyle.WELL_SHADE)
	draw_rect(Rect2(inner.position, Vector2(1, SIZE)), UiStyle.WELL_SHADE)
	var mid := inner.position + (inner.size * 0.5).floor()
	draw_rect(Rect2(mid - Vector2(2, 2), Vector2(5, 5)), UiStyle.EDGE)
	draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
	draw_rect(Rect2(mid, Vector2(1, 1)), UiStyle.INK)
