extends RefCounted
## The client's copy of the animals (Wildlife), fed by the server's events
## (Protocol.ANIMAL, ANIMAL_GONE, SNAP, STEP; Mirror): an Animal for each with the
## fields the views read (where it is, which way it faces, whether it flies, walks or
## leaps, its tint, its state for its voice), and the same signals (born, gone,
## stepped), so what draws them (Creatures), their shadows (FireShadows) and their
## voices (Voices) sees no difference. The animals think and move only on the server.
## Over a socket (`smooth`) their snapshots come about 10 times a second, unevenly: each animal
## glides from where it is drawn to where the last one put it, over the time since the
## one before (glide, called by Creatures each frame), so it walks smoothly.

const AiRules := preload("res://src/shared/content/ai_rules.gd")

## A snapshot farther than this (world units) from where the animal is drawn puts it
## there at once; a glide takes the time between two snapshots, within these bounds.
const GLIDE_MOST := 3.0
const GLIDE_SHORTEST := 0.05
const GLIDE_LONGEST := 0.3

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
	## The glide (see the top): from where, to where, when it began (seconds) and how
	## long it takes; the lift too.
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var lift_from := 0.0
	var lift_to := 0.0
	var since := 0.0
	var span := 0.0
	var gliding := false

	## Off the ground, out of reach of those that walk.
	func aloft() -> bool:
		return flying or perched


signal born(a: Animal)
signal gone(a: Animal)
signal stepped(a: Animal, at: Vector3, dir: Vector2, left: bool, size: float)

var animals: Array[Animal] = []
var _by_id := {}
## The snapshots come over a socket (Main sets it): the animals glide between them. Over
## the loop of one's own world one comes every frame, and each is taken as it is.
var smooth := false
## What the animals near have in mind (Protocol.MINDS, the AI's debug; AiDebug draws it):
## id -> the entry Wildlife.mind made; empty while the debug is off.
var minds := {}


## What the animals near have in mind (Protocol.MINDS): the entries of Wildlife.mind.
func take_minds(list: Array) -> void:
	minds = {}
	for m in list:
		if m is Array and m.size() == MIND_SIZE and m[0] is int and m[1] is String and m[2] is String:
			minds[m[0]] = m


## How many fields an entry of Protocol.MINDS has (Wildlife.mind).
const MIND_SIZE := 18


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
	a.since = Time.get_ticks_msec() * 0.001
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
		var now := Time.get_ticks_msec() * 0.001
		var to: Vector3 = s[1]
		if not smooth or to.distance_to(a.pos) > GLIDE_MOST:
			# Too far to walk (a leap of the server's, a teleport): there at once.
			a.pos = to
			a.lift = float(s[2])
			a.gliding = false
		else:
			a.from = a.pos
			a.lift_from = a.lift
			a.to = to
			a.lift_to = float(s[2])
			a.span = clampf(now - a.since, GLIDE_SHORTEST, GLIDE_LONGEST)
			a.since = now
			a.gliding = true
		a.facing = float(s[3])
		a.flying = bool(s[4])
		a.perched = bool(s[5])
		a.moving = bool(s[6])
		a.hop = float(s[7])
		a.left = bool(s[8])
		a.near = bool(s[9])
		a.state = s[10]
		a.fresh = true


## Moves each gliding animal to where it is now on its way (see the top).
func glide() -> void:
	var now := Time.get_ticks_msec() * 0.001
	for a: Animal in _by_id.values():
		if not a.gliding:
			continue
		var k := clampf((now - a.since) / a.span, 0.0, 1.0)
		a.pos = a.from.lerp(a.to, k)
		a.lift = lerpf(a.lift_from, a.lift_to, k)
		a.fresh = true
		a.gliding = k < 1.0


## A paw came down: [id, at, dir, left, size].
func take_step(args: Array) -> void:
	if args.size() != 5 or not _by_id.has(args[0]) or not (args[1] is Vector3) or not (args[2] is Vector2):
		return
	stepped.emit(_by_id[args[0]], args[1], args[2], bool(args[3]), float(args[4]))


## The animal numbered `id`, or null.
func by_id(id: int) -> Animal:
	return _by_id.get(id)
