extends RefCounted
## A tree species drawn as pictures (`picture` in trees.yaml): the approved drawing of the
## tree from the 8 sides the camera turns to, in a few looks (sizes and variants), and the
## shape of each look's crown in cells. The pictures are made from the mockup the drawing
## was approved in (survivium-builds/trees-redraw, integration/pr1/src/pack_pr1.py); this
## reads their `look.yaml`. Growth grows such a tree's trunk and crown cells from its look
## (Growth.look_of), the client draws it (TreeSprites).

const Content := preload("res://src/shared/content/content.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

## How many variants each size has (the looks are size by size, a variant each in turn).
const VARIANTS := 2


## The looks of species record `s`, from its `picture` file (a path in its bundle): a
## Dictionary {leaves: [Color], bark: [Color], looks: [look], frames, bare (paths)}, each
## look {size, variant, x, y, w, h, ax, ay, trunk, crown: [x0, z0, nx, ny, nz],
## cells: PackedByteArray of nx * ny * nz bits, x fastest, then y, then z}; empty when it
## has none or it cannot be read.
static func read(s: Dictionary) -> Dictionary:
	var file: String = s.get("picture", "")
	if file == "":
		return {}
	var path := Content.asset(s, file)
	var yaml := Yaml.new()
	var data: Variant = yaml.parse(Content.text(path), path)
	if yaml.error != "" or not data is Dictionary or not data.get("looks") is Array:
		push_warning("tree pictures: cannot read %s %s" % [path, yaml.error])
		return {}
	var out := {"leaves": [], "bark": [], "looks": [],
		"frames": path.get_base_dir().path_join("frames.png"), "bare": path.get_base_dir().path_join("bare.png")}
	for c in data.get("leaves", []):
		out.leaves.append(Color(str(c)))
	for c in data.get("bark", []):
		out.bark.append(Color(str(c)))
	for l: Dictionary in data.looks:
		var c: Array = l.crown
		var look := {}
		for k in ["x", "y", "w", "h", "ax", "ay", "trunk", "variant"]:
			look[k] = int(l[k])
		look.size = float(l.size)
		look.crown = [int(c[0]), int(c[1]), int(c[2]), int(c[3]), int(c[4])]
		look.cells = Marshalls.base64_to_raw(str(c[5]))
		out.looks.append(look)
	return out


## Whether the crown of `look` has a cell at x, y, z of the tree's own frame (cells east,
## up from the foot's cell, south, the trunk at 0, 0).
static func crown_has(look: Dictionary, x: int, y: int, z: int) -> bool:
	var c: Array = look.crown
	var ix := x - int(c[0])
	var iz := z - int(c[1])
	if ix < 0 or y < 0 or iz < 0 or ix >= c[2] or y >= c[3] or iz >= c[4]:
		return false
	var i: int = (iz * int(c[3]) + y) * int(c[2]) + ix
	var bytes: PackedByteArray = look.cells
	return (bytes[i >> 3] >> (i & 7)) & 1 == 1


## The tree's own frame turned by `turn` eighths: where a world offset (dx, dz) from the
## trunk lies in it. The camera turned `c` eighths shows the tree's own drawing of turn
## c + turn (PixelView.view_of: a turn `a` looks with right = (cos a, -sin a)).
static func to_own(dx: float, dz: float, turn: int) -> Vector2:
	var a := -turn * PI / 4.0
	return Vector2(dx * cos(a) - dz * sin(a), dx * sin(a) + dz * cos(a))
