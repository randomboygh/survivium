extends SceneTree
## Draws the land around the spawn from above to check the generator:
## godot --headless --path . --script res://tools/map.gd -- <file.png> [cells] [step] [seed]
## With step 1 (the default for up to 512 cells) the chunks are generated and drawn a
## pixel per column: ground coloured by its top and shaded by height, a light rim where
## it drops (cliffs), a red tint over caves, tree crowns dark green, water darker with
## depth. With a larger step only the layout is drawn, a pixel every `step` cells,
## coloured by biome (WorldGen.column_color), so thousands of cells take seconds. The
## spawn is a white dot.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const WorldData := preload("res://src/shared/world_data.gd")

var colors: Dictionary = {
	Mat.GRASS: Color(0.36, 0.56, 0.24), Mat.DIRT: Color(0.5, 0.36, 0.22), Mat.STONE: Color(0.55, 0.55, 0.55),
	Mat.SAND: Color(0.86, 0.78, 0.52), Mat.CLAY: Color(0.6, 0.45, 0.38), Mat.COPPER_ORE: Color(0.6, 0.5, 0.4),
	Mat.LOG: Color(0.4, 0.28, 0.16), Mat.LEAVES: Color(0.16, 0.36, 0.14),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://map.png"
	var cells: int = int(args[1]) if args.size() > 1 else 512
	var step: int = int(args[2]) if args.size() > 2 else (1 if cells <= 512 else maxi(1, cells / 1024))
	var seed_value: int = int(args[3]) if args.size() > 3 else 20261018
	var t0 := Time.get_ticks_msec()
	var gen := WorldGen.new(seed_value)
	var at: Vector3i = gen.spawn_guess
	var x0 := at.x - cells / 2
	var z0 := at.z - cells / 2
	var px := cells / step
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	if step == 1:
		_draw_cells(gen, img, x0, z0, px)
	else:
		for row in px:
			var lay := gen.lay_out(x0, z0 + row * step, px, 1, step)
			for i in px:
				img.set_pixel(i, row, gen.column_color(lay, i))
	print("%d cells around (%d, %d) at %d cells a pixel: %d ms" % [cells, at.x, at.z, step, Time.get_ticks_msec() - t0])
	var spawn: Vector3i = WorldGen.find_spawn(gen.world, at) if step == 1 else at
	var s := Vector2i((spawn.x - x0) / step, (spawn.z - z0) / step)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		if Rect2i(0, 0, px, px).has_point(s + d):
			img.set_pixel(s.x + d.x, s.y + d.y, Color.WHITE)
	if px <= 512:
		img.resize(px * 2, px * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()


func _draw_cells(gen: WorldGen, img: Image, x0: int, z0: int, n: int) -> void:
	var from := Vector2i(x0 >> WorldData.SHIFT, z0 >> WorldData.SHIFT)
	var to := Vector2i((x0 + n - 1) >> WorldData.SHIFT, (z0 + n - 1) >> WorldData.SHIFT) + Vector2i.ONE
	gen.generate_area(from, to)
	var w: WorldData = gen.world
	print("%d chunks, %d trees, %d bushes" % [w.chunks.size(), w.trees.size(), w.bushes.size()])
	var all: int = w.all_bits
	var tops := PackedInt32Array()
	tops.resize(n * n)
	for z in n:
		for x in n:
			tops[z * n + x] = maxi(0, WorldData.top_level(~(w.air_col(x0 + x, z0 + z) | w.leaf_col(x0 + x, z0 + z)
				| w.log_col(x0 + x, z0 + z)) & all))
	for z in n:
		for x in n:
			var wx := x0 + x
			var wz := z0 + z
			var y := tops[z * n + x]
			var m: int = w.get_cell(wx, y, wz)
			var c: Color
			if m == Mat.WATER:
				var depth := 0
				while w.get_cell(wx, y - depth, wz) == Mat.WATER:
					depth += 1
				c = Color(0.4, 0.66, 0.7).lerp(Color(0.1, 0.22, 0.4), clampf((depth - 1) / 6.0, 0.0, 1.0))
			else:
				c = colors.get(m, Color.MAGENTA)
				c = c * (0.75 + 0.5 * (y - w.sea_level) / float(w.size_y - w.sea_level))
				var north := tops[maxi(z - 1, 0) * n + x]
				var west := tops[z * n + maxi(x - 1, 0)]
				if y - north >= 2 or y - west >= 2:
					c = c.lightened(0.25)
				elif north - y >= 2 or west - y >= 2:
					c = c.darkened(0.35)
				if w.leaf_col(wx, wz) != 0:
					c = c.lerp(colors[Mat.LEAVES], 0.7)
				if w.air_col(wx, wz) & ((1 << y) - 1) != 0:
					c = c.lerp(Color(0.8, 0.2, 0.2), 0.3)
			img.set_pixel(x, z, Color(c.r, c.g, c.b))
