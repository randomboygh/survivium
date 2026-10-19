extends SceneTree
## Draws the start world from above, one pixel per column, to check the layout of the
## island: godot --headless --path . --script res://tools/map.gd -- <file.png>
## Ground is coloured by its top and shaded by height, with a dark rim where it drops
## (cliffs) and a red tint over caves; water darkens with depth; the spawn is a white
## dot.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")

const COLORS := {
	Mat.GRASS: Color(0.36, 0.56, 0.24), Mat.DIRT: Color(0.5, 0.36, 0.22), Mat.STONE: Color(0.55, 0.55, 0.55),
	Mat.SAND: Color(0.86, 0.78, 0.52), Mat.CLAY: Color(0.6, 0.45, 0.38), Mat.COPPER_ORE: Color(0.6, 0.5, 0.4),
	Mat.LOG: Color(0.4, 0.28, 0.16), Mat.LEAVES: Color(0.16, 0.36, 0.14),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://map.png"
	var t0 := Time.get_ticks_msec()
	var w = WorldGen.generate(20261018)
	print("generated %dx%dx%d in %d ms" % [w.size_x, w.size_y, w.size_z, Time.get_ticks_msec() - t0])
	var sx: int = w.size_x
	var sz: int = w.size_z
	var img := Image.create(sx, sz, false, Image.FORMAT_RGB8)
	var tops := PackedInt32Array()
	tops.resize(sx * sz)
	for z in sz:
		for x in sx:
			var y: int = w.size_y - 1
			while y > 0 and w.get_cell(x, y, z) == Mat.AIR:
				y -= 1
			tops[z * sx + x] = y
	for z in sz:
		for x in sx:
			var y := tops[z * sx + x]
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
				var cave := false
				for yy in range(1, y - 1):
					if w.get_cell(x, yy, z) == Mat.AIR:
						cave = true
						break
				if cave:
					c = c.lerp(Color(0.8, 0.2, 0.2), 0.3)
			img.set_pixel(x, z, Color(c.r, c.g, c.b))
	var spawn: Vector3i = WorldGen.find_spawn(w)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		img.set_pixel(spawn.x + d.x, spawn.z + d.y, Color.WHITE)
	img.resize(sx * 2, sz * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("saved ", path)
	quit()
