extends RefCounted
## The client's copy of the animals (Wildlife), fed by the server's events
## (Protocol.ANIMAL, ANIMAL_GONE, SNAP, STEP; Mirror): an Animal for each with the
## fields the views read (where it is, which way it faces, whether it flies, walks or
## leaps, its tint, its state for its voice), and the same signals (born, gone,
## stepped), so what draws them (Creatures), their shadows (FireShadows) and their
## voices (Voices) sees no difference. The animals think and move only on the server.

const AiRules := preload("res://src/shared/content/ai_rules.gd")

## An animal as the client knows it (see Wildlife.Animal for what each field means).
class Animal:
	var id := 0
	var kind := ""
	var pos := Vector3.ZERO
	var lift := 0.0
	var facing := 1.0
	var flying := false
	var perched := false
	var moving := false
	var hop := 0.0
	var left := false
	var near := true
	var state := "wander"
	var tint := 0
	var gone := false
	## The frame of its picture drawn (Creatures).
	var frame := 0
	## The server moved it since it was last drawn (Creatures puts its picture again).
	var fresh := true

	## Off the ground, out of reach of those that walk.
	func aloft() -> bool:
		return flying or perched


signal born(a: Animal)
signal gone(a: Animal)
signal stepped(a: Animal, at: Vector3, dir: Vector2, left: bool, size: float)

var animals: Array[Animal] = []
var _by_id := {}


## An animal came into the world: [id, kind, tint, position]. One with a number known
## already is the same animal told again (a snapshot after a join): nothing happens.
func take_born(args: Array) -> void:
	if args.size() != 4 or not (args[0] is int) or not (args[1] is String) or not (args[2] is int) \
			or not (args[3] is Vector3) or _by_id.has(args[0]) or not AiRules.SPECIES.has(args[1]):
		return
	var a := Animal.new()
	a.id = args[0]
	a.kind = args[1]
	a.tint = args[2]
	a.pos = args[3]
	animals.append(a)
	_by_id[a.id] = a
	born.emit(a)


## An animal left the world: [id].
func take_gone(args: Array) -> void:
	if args.size() != 1 or not _by_id.has(args[0]):
		return
	var a: Animal = _by_id[args[0]]
	_by_id.erase(a.id)
	animals.erase(a)
	a.gone = true
	gone.emit(a)


## Where the animals that moved are (Protocol.SNAP): one entry each.
func take_snap(list: Array) -> void:
	for s in list:
		if not (s is Array) or s.size() != 11 or not _by_id.has(s[0]) or not (s[1] is Vector3) \
				or not (s[10] is String):
			continue
		var a: Animal = _by_id[s[0]]
		a.pos = s[1]
		a.lift = float(s[2])
		a.facing = float(s[3])
		a.flying = bool(s[4])
		a.perched = bool(s[5])
		a.moving = bool(s[6])
		a.hop = float(s[7])
		a.left = bool(s[8])
		a.near = bool(s[9])
		a.state = s[10]
		a.fresh = true


## A paw came down: [id, at, dir, left, size].
func take_step(args: Array) -> void:
	if args.size() != 5 or not _by_id.has(args[0]) or not (args[1] is Vector3) or not (args[2] is Vector2):
		return
	stepped.emit(_by_id[args[0]], args[1], args[2], bool(args[3]), float(args[4]))


## The animal numbered `id`, or null.
func by_id(id: int) -> Animal:
	return _by_id.get(id)
