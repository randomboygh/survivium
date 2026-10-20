extends SceneTree
## Draws a whole world from above, one pixel per column, to check the generator's
## layout: godot --headless --path . --script res://tools/map.gd -- <file.png> [size]
## Ground is coloured by its top and shaded by height, with a light rim where it
## drops (cliffs) and a red tint over caves; tree crowns are dark green; water darkens
## with depth; the spawn is a white dot.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const WorldData := preload("res://src/shared/world_data.gd")

const COLORS := {
	Mat.GRASS: Color(0.36, 0.56, 0.24), Mat.DIRT: Color(0.5, 0.36, 0.22), Mat.STONE: Color(0.55, 0.55, 0.55),
	Mat.SAND: Color(0.86, 0.78, 0.52), Mat.CLAY: Color(0.6, 0.45, 0.38), Mat.COPPER_ORE: Color(0.6, 0.5, 0.4),
	Mat.LOG: Color(0.4, 0.28, 0.16), Mat.LEAVES: Color(0.16, 0.36, 0.14),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://map.png"
	var size: int = int(args[1]) if args.size() > 1 else 1024
	var t0 := Time.get_ticks_msec()
	var gen := WorldGen.new(20261018, size, 48, size)
	gen.generate_all()
	var w: WorldData = gen.world
	print("generated %dx%dx%d in %d ms: %d rivers, %d trees, %d bushes" % [w.size_x, w.size_y, w.size_z,
		Time.get_ticks_msec() - t0, gen.rivers.size(), w.trees.size(), w.bushes.size()])
	var sx: int = w.size_x
	var sz: int = w.size_z
	var img := Image.create(sx, sz, false, Image.FORMAT_RGB8)
	var tops := PackedInt32Array()
	tops.resize(sx * sz)
	var all: int = w.all_bits
	for col in sx * sz:
		tops[col] = maxi(0, WorldData.top_level(~(w.air_cols[col] | w.leaf_cols[col] | w.log_cols[col]) & all))
	for z in sz:
		for x in sx:
			var col := z * sx + x
			var y := tops[col]
			var m: int = w.get_cell(x, y, z)
			var c: Color
			if m == Mat.WATER:
				var depth := 0
				while w.get_cell(x, y - depth, z) == Mat.WATER:
					depth += 1
				c = Color(0.4, 0.66, 0.7).lerp(Color(0.1, 0.22, 0.4), clampf((depth - 1) / 6.0, 0.0, 1.0))
			else:
				c = COLORS.get(m, Color.MAGENTA)
				c = c * (0.75 + 0.5 * (y - w.sea_level) / float(w.size_y - w.sea_level))
				var north := tops[maxi(z - 1, 0) * sx + x]
				var west := tops[z * sx + maxi(x - 1, 0)]
				if y - north >= 2 or y - west >= 2:
					c = c.lightened(0.25)
				elif north - y >= 2 or west - y >= 2:
					c = c.darkened(0.35)
				if w.leaf_cols[col] != 0:
					c = c.lerp(COLORS[Mat.LEAVES], 0.7)
				if w.air_cols[col] & ((1 << y) - 1) != 0:
					c = c.lerp(Color(0.8, 0.2, 0.2), 0.3)
			img.set_pixel(x, z, Color(c.r, c.g, c.b))
	var spawn: Vector3i = WorldGen.find_spawn(w, gen.spawn_guess)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		img.set_pixel(spawn.x + d.x, spawn.z + d.y, Color.WHITE)
	if size <= 512:
		img.resize(sx * 2, sz * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()
