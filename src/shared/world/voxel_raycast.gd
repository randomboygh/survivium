extends RefCounted
## Ray cast through the cell grid (Amanatides & Woo). Cells above `max_level`
## are skipped because the level cutaway hides them.


## Returns {"cell": Vector3i, "normal": Vector3i} for the first solid cell, or {}.
static func cast(w, origin: Vector3, dir: Vector3, max_dist: float, max_level: int) -> Dictionary:
	var x := floori(origin.x)
	var y := floori(origin.y)
	var z := floori(origin.z)
	var step_x := 1 if dir.x > 0.0 else -1
	var step_y := 1 if dir.y > 0.0 else -1
	var step_z := 1 if dir.z > 0.0 else -1
	var t_max_x: float = ((x + (1 if dir.x > 0.0 else 0)) - origin.x) / dir.x if dir.x != 0.0 else INF
	var t_max_y: float = ((y + (1 if dir.y > 0.0 else 0)) - origin.y) / dir.y if dir.y != 0.0 else INF
	var t_max_z: float = ((z + (1 if dir.z > 0.0 else 0)) - origin.z) / dir.z if dir.z != 0.0 else INF
	var t_delta_x: float = absf(1.0 / dir.x) if dir.x != 0.0 else INF
	var t_delta_y: float = absf(1.0 / dir.y) if dir.y != 0.0 else INF
	var t_delta_z: float = absf(1.0 / dir.z) if dir.z != 0.0 else INF
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_dist:
		if y <= max_level and w.in_bounds(x, y, z) and w.is_solid(x, y, z):
			return {"cell": Vector3i(x, y, z), "normal": normal}
		if t_max_x < t_max_y and t_max_x < t_max_z:
			x += step_x
			t = t_max_x
			t_max_x += t_delta_x
			normal = Vector3i(-step_x, 0, 0)
		elif t_max_y < t_max_z:
			y += step_y
			t = t_max_y
			t_max_y += t_delta_y
			normal = Vector3i(0, -step_y, 0)
		else:
			z += step_z
			t = t_max_z
			t_max_z += t_delta_z
			normal = Vector3i(0, 0, -step_z)
	return {}
