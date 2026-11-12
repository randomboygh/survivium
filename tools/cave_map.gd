extends SceneTree
## Draws the caves of a patch of land to judge their shape:
## godot --headless --path . --script res://tools/cave_map.gd -- <file.png> [cells] [seed] [place] [settings]
## Left: from above, each column shaded by how much cave air lies under it (brighter is
## more), the mouths red. Right: four slices from the side (x across, y up) at even
## steps of z: stone grey, other ground brown, cave air black, open air sky blue,
## water blue. Prints the cave cells, their share with no more than two air
## neighbours across (narrow), and the share with rock all round but one side.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://caves.png"
	var cells: int = int(args[1]) if args.size() > 1 else 128
	var seed_value: int = int(args[2]) if args.size() > 2 else 20261018
	var options := {}
	if args.size() > 4:
		for kv in args[4].split(","):
			options[kv.get_slice("=", 0)] = int(kv.get_slice("=", 1))
	var gen := WorldGen.new(seed_value, 48, options)
	var at := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	if args.size() > 3 and args[3].contains(","):
		at = Vector2i(int(args[3].get_slice(",", 0)), int(args[3].get_slice(",", 1)))
	elif args.size() > 3 and args[3] != "-":
		at = gen.find_place(args[3], at)
	var x0 := at.x - cells / 2
	var z0 := at.y - cells / 2
	var t0 := Time.get_ticks_msec()
	gen.generate_area(WorldData.chunk_key(x0, z0), WorldData.chunk_key(x0 + cells, z0 + cells) + Vector2i(1, 1))
	var gen_ms := Time.get_ticks_msec() - t0
	var w := gen.world
	var sy := w.size_y
	var lay := gen.lay_out(x0, z0, cells, cells)
	var tops := PackedInt32Array()
	tops.resize(cells * cells)
	# The ground's top as laid out (trees and their crowns stand over it).
	for j in cells * cells:
		tops[j] = lay.heights[j]
	var slices := 4
	var img := Image.create(cells * 2 + 8, maxi(cells, slices * (sy + 4)), false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	var cave := 0
	var narrow := 0
	var pocket := 0
	for lz in cells:
		for lx in cells:
			var n := 0
			var x := x0 + lx
			var z := z0 + lz
			for y in range(1, tops[lz * cells + lx]):
				if w.get_cell(x, y, z) != Mat.AIR:
					continue
				n += 1
				cave += 1
				var across := 0
				var solid := 0
				for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if w.get_cell(x + d.x, y, z + d.z) == Mat.AIR:
						across += 1
				for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
					if w.get_cell(x + d.x, y + d.y, z + d.z) != Mat.AIR:
						solid += 1
				narrow += 1 if across <= 2 else 0
				pocket += 1 if solid >= 5 else 0
			var c := Color(0.15, 0.3, 0.12).lerp(Color(1, 1, 0.85), clampf(n / 16.0, 0.0, 1.0)) if n > 0 else Color(0.15, 0.3, 0.12)
			if lay.flags[lz * cells + lx] & WorldGen.ENTRANCE:
				c = c.lerp(Color(1, 0.2, 0.1), 0.5)
			if lay.adit[lz * cells + lx] > 0 or lay.pit[lz * cells + lx] > 0:
				c = Color(1, 0.1, 0.1)
			img.set_pixel(lx, lz, c)
	for s in slices:
		var lz := (s * 2 + 1) * cells / (slices * 2)
		img.set_pixel(0, lz, Color.MAGENTA)
		img.set_pixel(1, lz, Color.MAGENTA)
		var oy := s * (sy + 4)
		for lx in cells:
			for y in sy:
				var m := w.get_cell(x0 + lx, y, z0 + lz)
				var c := Color.BLACK
				if y > tops[lz * cells + lx] and m != Mat.WATER:
					c = Color(0.55, 0.75, 0.95) if m == Mat.AIR else Color(0.3, 0.5, 0.3)
				elif m == Mat.AIR:
					c = Color(0.55, 0.75, 0.95) if y > tops[lz * cells + lx] else Color(0.02, 0.02, 0.02)
				elif m == Mat.WATER:
					c = Color(0.2, 0.35, 0.8)
				elif m == Mat.STONE:
					c = Color(0.5, 0.5, 0.52)
				else:
					c = Color(0.55, 0.4, 0.25)
				img.set_pixel(cells + 8 + lx, oy + sy - 1 - y, c)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("around %s: %d cave cells, narrow %.0f%%, pockets %.0f%%, generated in %d ms; saved %s" % [at, cave,
			100.0 * narrow / maxi(cave, 1), 100.0 * pocket / maxi(cave, 1), gen_ms, path])
	quit()
