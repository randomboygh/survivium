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
## deaths, a red dot here kept at the edge while the sack is beyond it, and the
## player's markers (Markers), diamonds of their colour kept at the edge too, flags on the
## whole map. The ground is drawn through shaders/map_ground.gdshader: the corners of
## the explored land and of the frame are rounded. The regions are kept in the save
## (see save_region, load_regions), so the explored map comes back with the world.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const Markers := preload("res://src/client/game/markers.gd")
const GROUND_SHADER := preload("res://shaders/map_ground.gdshader")

## The map on screen, in UI pixels, and the cells per pixel.
const SIZE := 72
const STEP := 2
## The panel's frame round the map: its outline and highlight, then a sunken edge.
const FRAME := 4
## The radius of the map's rounded corners, in UI pixels.
const CORNER := 4
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
## Regions painted since they were last saved (see save_region).
var unsaved := {}
## The player's markers (set by Hud), or null.
var markers: Markers
## The player's column.
var player_cell := Vector2i.ZERO
## The things placed and the sacks, [middle column, item id or Items.SACK] each (see
## set_marks), and the colour of each item's mark by id.
var marks: Array = []
var _mark_colors := {}
var sea := 0
var top := 0
var _frame := UiStyle.panel()
## The ground in the sunken map, through the shader, and the marks and the player over it.
var _ground: Layer
var _top: Layer
## Asks for the whole map (see Hud).
signal open_map
## New ground was painted in (the whole map redraws).
signal painted


## A child Control that `paint` draws (given the layer); the ground's carries its shader.
class Layer extends Control:
	var paint: Callable

	func _init(p: Callable) -> void:
		paint = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		paint.call(self)


## A layer for the ground of the map, its shader clipping to its own rectangle with
## corners of `radius` (see place_ground).
static func ground_layer(p: Callable, radius: int) -> Layer:
	var l := Layer.new(p)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("radius", float(radius))
	l.material = m
	return l


## Puts a ground layer at `rect` of its parent.
static func place_ground(l: Layer, rect: Rect2) -> void:
	l.position = rect.position
	l.size = rect.size
	(l.material as ShaderMaterial).set_shader_parameter("clip", Vector4(0, 0, rect.size.x, rect.size.y))
	l.queue_redraw()


## Fills `rect` with `color`, its corners rounded by `radius` pixels as the shader
## rounds them (a pixel goes when its middle is outside the circle in the corner).
static func round_rect(canvas: CanvasItem, rect: Rect2, color: Color, radius: int) -> void:
	for y in radius:
		var cut := 0
		while cut < radius and Vector2(radius - cut - 0.5, radius - y - 0.5).length_squared() > radius * radius:
			cut += 1
		var row := Rect2(rect.position.x + cut, 0, rect.size.x - 2 * cut, 1)
		row.position.y = rect.position.y + y
		canvas.draw_rect(row, color)
		row.position.y = rect.end.y - 1 - y
		canvas.draw_rect(row, color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - 2 * radius), color)


func _init() -> void:
	custom_minimum_size = Vector2(SIZE + 2 * FRAME, SIZE + 2 * FRAME)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Карта (M)"
	_ground = ground_layer(func(l: Control) -> void:
		draw_ground(l, Rect2(Vector2.ZERO, l.size), Vector2(player_cell), 1.0), CORNER)
	add_child(_ground)
	place_ground(_ground, Rect2(FRAME, FRAME, SIZE, SIZE))
	_top = Layer.new(_draw_top)
	_top.position = Vector2(FRAME, FRAME)
	_top.size = Vector2(SIZE, SIZE)
	add_child(_top)


## Redraws the ground and everything over it.
func redraw() -> void:
	queue_redraw()
	_ground.queue_redraw()
	_top.queue_redraw()


## An empty map of a new world.
func setup(gen: WorldGen) -> void:
	sea = gen.world.sea_level
	top = gen.world.size_y
	regions.clear()
	unsaved.clear()
	redraw()


## Puts back the regions of a save (WorldStore.read_maps): their pixels by key.
func load_regions(saved: Dictionary) -> void:
	for key: Vector2i in saved:
		var data: PackedByteArray = saved[key]
		if data.size() != REGION_PX * REGION_PX * 4:
			continue
		regions[key] = {"image": Image.create_from_data(REGION_PX, REGION_PX, false, Image.FORMAT_RGBA8, data),
			"texture": null, "dirty": true}


## The pixels of region `key` for the save, and it is no longer unsaved.
func save_region(key: Vector2i) -> PackedByteArray:
	unsaved.erase(key)
	var r: Dictionary = regions.get(key, {})
	return PackedByteArray() if r.is_empty() else (r.image as Image).get_data()


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
	unsaved[Vector2i(key.x >> REGION_SHIFT, key.y >> REGION_SHIFT)] = true


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
	unsaved[rk] = true


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
		redraw()
		painted.emit()


## Marks the things placed (Props.placed: "item", "cell" the north-west of its two
## by two cells) and the sacks at `sacks` (world units) when they changed.
func set_marks(placed: Array, sacks: Array[Vector3] = []) -> void:
	var now := []
	for e: Dictionary in placed:
		var c: Vector3i = e.cell
		now.append([Vector2i(c.x + 1, c.z + 1), e.item])
	for p in sacks:
		now.append([Vector2i(floori(p.x / WorldData.CELL), floori(p.z / WorldData.CELL)), Items.SACK])
	if now != marks:
		marks = now
		_top.queue_redraw()
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
		redraw()


## Where column `cell` falls on a map drawn in `rect` (see draw_ground).
static func to_screen(cell: Vector2, rect: Rect2, centre: Vector2, zoom: float) -> Vector2:
	return (rect.get_center() + (cell - centre) / STEP * zoom).floor()


## The column under point `p` of a map drawn in `rect` (see draw_ground).
static func to_cell(p: Vector2, rect: Rect2, centre: Vector2, zoom: float) -> Vector2:
	return centre + (p - rect.get_center()) / zoom * STEP


## Draws the explored ground on `canvas` (a ground layer) inside `rect` (its UI
## pixels), the column `centre` (in cells, may be fractional) in the middle, `zoom` UI
## pixels per map pixel.
func draw_ground(canvas: CanvasItem, rect: Rect2, centre: Vector2, zoom: float) -> void:
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


## Draws the marks of the things placed and the sacks over a map drawn as draw_ground
## does, as pictures with `pictures`.
func draw_marks(canvas: CanvasItem, rect: Rect2, centre: Vector2, zoom: float, pictures := false) -> void:
	var mid := rect.get_center()
	# Pictures overlap, the later on top, and part when the map is zoomed in. Dots of
	# things side by side share their dark outline: the outlines go first, then the
	# dots, so none hides another whole (the sacks, last, on top). A sack beyond the
	# edge is drawn at the edge, towards it.
	var dots: Array = []
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
		if not rect.encloses(box):
			continue
		canvas.draw_rect(box, UiStyle.DARK_INK)
		if pictures:
			canvas.draw_texture(tex, box.position + Vector2(1, 1))
		else:
			dots.append([box.grow(-1), _mark_color(m[1])])
	for d: Array in dots:
		canvas.draw_rect(d[0], d[1])


## Draws the markers over a map drawn as draw_ground does: dots kept at the edge, or
## flags (`flags`, the marker `lit` outlined in the accent) left out beyond it.
func draw_markers(canvas: CanvasItem, rect: Rect2, centre: Vector2, zoom: float, flags := false, lit := -1) -> void:
	if markers == null:
		return
	for i in markers.list.size():
		var m: Dictionary = markers.list[i]
		var p := to_screen(Vector2(m.cell), rect, centre, zoom)
		var color := Markers.color_of(m)
		if flags:
			var box := Rect2(p.x - 1, p.y - 11, 9, 12)
			if not rect.encloses(box):
				continue
			var ink := UiStyle.ACCENT if i == lit else UiStyle.DARK_INK
			# A pole from the spot up, the flag on its right, a dark outline round both.
			canvas.draw_rect(Rect2(p.x - 1, p.y - 11, 3, 12), ink)
			canvas.draw_rect(Rect2(p.x + 1, p.y - 11, 7, 6), ink)
			canvas.draw_rect(Rect2(p.x, p.y - 10, 1, 10), UiStyle.INK)
			canvas.draw_rect(Rect2(p.x + 1, p.y - 10, 6, 4), color)
			canvas.draw_rect(Rect2(p.x + 1, p.y - 7, 6, 1), color.darkened(0.3))
		else:
			# A diamond, not a square like the things placed.
			var box := Rect2(p - Vector2(3, 3), Vector2(7, 7))
			box.position = box.position.clamp(rect.position, rect.end - box.size)
			var c := box.position + Vector2(3, 3)
			for y in range(-3, 4):
				var half := 3 - absi(y)
				canvas.draw_rect(Rect2(c.x - half, c.y + y, 2 * half + 1, 1), UiStyle.DARK_INK)
				if half > 0 and absi(y) < 3:
					canvas.draw_rect(Rect2(c.x - half + 1, c.y + y, 2 * half - 1, 1), color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		open_map.emit()
		accept_event()


## In the frame of the panels and buttons beside it: the map sunk into it like a slot
## with rounded corners (the ground over it, see _ground), shaded along the top and
## left.
func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner := Rect2(FRAME, FRAME, SIZE, SIZE)
	round_rect(self, inner.grow(1), UiStyle.EDGE, CORNER + 1)
	round_rect(self, inner, UNSEEN, CORNER)


## Over the ground: the marks, the markers, the shade of the slot's top and left, and
## the player an amber dot outlined dark in the middle.
func _draw_top(l: Control) -> void:
	var inner := Rect2(Vector2.ZERO, l.size)
	draw_marks(l, inner, Vector2(player_cell), 1.0)
	draw_markers(l, inner, Vector2(player_cell), 1.0)
	l.draw_rect(Rect2(CORNER, 0, SIZE - 2 * CORNER, 1), UiStyle.WELL_SHADE)
	l.draw_rect(Rect2(0, CORNER, 1, SIZE - 2 * CORNER), UiStyle.WELL_SHADE)
	var mid := (inner.size * 0.5).floor()
	l.draw_rect(Rect2(mid - Vector2(2, 2), Vector2(5, 5)), UiStyle.EDGE)
	l.draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT)
	l.draw_rect(Rect2(mid, Vector2(1, 1)), UiStyle.INK)
