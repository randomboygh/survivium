extends RefCounted
## The first part of Wildlife (wildlife.gd is the last and tells what the animals do): the
## numbers of how they live and move, the Animal itself, the world they are in, and what
## the other parts ask of the ground and of the list: the floor and the water under a
## point, an animal added, taken out and counted. The chain: wildlife_base ←
## wildlife_spawn ← wildlife_move ← wildlife_fight ← wildlife; a part calls only itself
## and the parts before it.

const Body := preload("res://src/shared/game/body.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## Every this many seconds the chunks made since get their animals (_populate_chunk) and
## those whose ground is forgotten go (_leave); every RESPAWN_EVERY the eaten are
## made up for (_refill).
const SETTLE_EVERY := 1.0
## The most chunks given their animals in a frame, and kinds made up for (_settle_new,
## _refill_some): a teleport or a respawn lets the animals of some hundred chunks come.
const SETTLE_MOST := 6
const REFILL_MOST := 2
const RESPAWN_EVERY := 15.0
const CELL := WorldData.CELL
## Animals walk slopes and hop up a sheer step of one cell, not of two.
const MAX_STEP := 0.55
## How near (cells) to a fence or a shut gate an animal comes (see _fenced): about half its
## body, so a fast one does not slip through the rails between two steps.
const FENCE_GAP := 0.25
## The square around each of the people where the eaten are made up for, in cells each
## way, and in world units (ROAM); the chunks within it are looked at for new ones made.
## A kind's `count` lives on each such square (ROAM_CHUNKS chunks).
const SPAWN_REACH := 80
const ROAM := SPAWN_REACH * CELL
const ROAM_CHUNKS := float(SPAWN_REACH * 2 * SPAWN_REACH * 2) / (WorldData.CHUNK * WorldData.CHUNK)
## Places tried for one animal to come.
const SPAWN_TRIES := 40
## How near the people no animal comes when its chunk is made (world units); those that
## make up for the eaten come past a screen (NEAR).
const START_AWAY := 8.0
## The biomes of a chunk are looked at on a grid of this many points each way.
const BIOME_SAMPLES := 2
## The eaten are made up for only while a kind is short by more than this.
const REFILL_SLACK := 1.0
## Animals no one looks at (`near` off) move and think in steps of FAR_STEP seconds
## instead of every frame: most of them are far away, and each step looks up the
## ground under them.
const FAR_STEP := 0.1
## World units from a player within which an animal is looked at (`near`, see
## look_from) when the player's screen is not known, and the most of a screen's half
## size taken: it moves every frame, the others step now and then. The screen of a phone
## or a desktop shows at most about 25 units from the player to a corner, so a circle of
## this radius holds what any screen shows and little else (the near ones cost: a frame
## each, and the jostle grows with their number).
const NEAR := 28.0
## The widest body's half width (see radius): past it no two animals meet.
const MOST_RADIUS := 0.6
## Flyers: how far they fly to another place, in world units, and how far from a
## threat; how high they fly above the ground and crowns, and over how much of the
## way's end they come down.
const FLIGHT := 14.0
const FLIGHT_AWAY := 12.0
const CRUISE := 2.5
const DESCENT := 4.0
## Chance a resting flyer flies over to another place each time it thinks.
const FLY_CHANCE := 0.05
## Chance a walker that likes some plants looks for them when it picks where to go.
const GRAZE_CHANCE := 0.3
## How far a climber looks for a tree to run up from a threat, in world units; how
## fast it goes up and down the trunk, in world units a second; and how many seconds
## it stays up there once the threat is gone, before it comes down.
const CLIMB_REACH := 6.0
const CLIMB_SPEED := 2.0
const STAY_UP := Vector2(4.0, 10.0)
## A swimmer keeps this far under the water surface, in cells.
const DIP := 0.35
## A flock keeps within this many world units of its lead.
const FLOCK_REACH := 1.5
const FLOCK_GAP := 4.0
## How fast bodies pick up and lose speed, in their speeds a second: on the ground and
## in the water (faster in flight from a threat), and in the air.
const GRIP := 3.0
const FLEE_GRIP := 6.0
const AIR_GRIP := 2.0
## A body slows down over the last this many seconds of its way at full speed, to a
## quarter of it.
const BRAKE := 0.4
## A flyer climbs at most this much for each unit flown, and up or down at this share
## of its speed.
const CLIMB := 0.6
const RISE := 0.6
## A wanderer that got where it went stands there this many seconds, half the times.
const LINGER := Vector2(1.5, 5.0)
## A swimmer that comes ashore keeps within this many world units of the water it was
## last in, and wanders this far at a time.
const SHORE := 4.0
const SHORE_WALK := 3.0
## The share of its wanderings it may go ashore in, for one that swims and one that hops.
const SHORE_SWIM := 0.15
const SHORE_HOP := 0.7
## A flyer that swims takes off only from a threat this near, in its sights; a farther
## one it swims away from. It flies over to another place this much less often.
const SWIM_SCARE := 0.4
const SWIM_FLY := 0.1
## A leap of one that hops: how long it takes, how high it goes (world units), how
## much faster than its speed it carries, and the rest between two (seconds, half that
## in flight).
const HOP_TIME := 0.35
const HOP_HIGH := 0.25
const HOP_BURST := 2.0
const HOP_REST := Vector2(0.3, 1.2)

## An animal came into the world, or was eaten and is gone.
signal born(a: Animal)
signal gone(a: Animal)
## A paw of animal `a` came down at `at` walking along `dir` (the left one or not);
## `size` is how big the print is, by the animal's mass.
signal stepped(a: Animal, at: Vector3, dir: Vector2, left: bool, size: float)
## Animal `a` bit `who`, one of the people (see _land_bite).
signal bit(a: Animal, who)


class Animal:
	## Its number in the world, by which a client's copy knows it (see Protocol.SNAP).
	var id := 0
	var kind := ""
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	var state := "wander"
	## Why it does what `state` says, for the AI's debug (mind): what it flees ("person",
	## "fire", "hurt", "alarm" — one of its flock fleeing — or the kind of the animal), what
	## it hunts (the kind), "graze", "lead", "owner"; "" for nothing in particular.
	var cause := ""
	var hunger := 0.0
	var think := 0.0
	var prey: Animal = null
	## The way it faces, 1 east and -1 west.
	var facing := 1.0
	## Way walked since the last footprint, and which foot made it.
	var stride := 0.0
	var left := false
	## Someone looks at it (within NEAR of one of the players, see look_from), so it
	## moves every frame; set by the owner before update().
	var near := true
	## Its body's half width on the ground (see radius), kept from the species.
	var radius := 0.0
	## Time gathered since the last step while not near (see FAR_STEP); 0 right after
	## a step.
	var away := 0.0
	## Time from the last step to the next one while not near: FAR_STEP, less what the
	## last one came late, so each animal keeps its own beat.
	var wait := FAR_STEP
	## It took a step this update (the client walks its picture).
	var moving := false
	## Its velocity over the ground (x east, y south), in world units a second.
	var vel := Vector2.ZERO
	## Seconds it stands where it came before it wanders on.
	var idle := 0.0
	## One that hops: how far into a leap it is, 0..1 (0 between leaps), the rest left
	## before the next one, and how high above `pos` the leap has it now.
	var hop := 0.0
	var hop_rest := 0.0
	var lift := 0.0
	## A swimmer that comes ashore: where it last was in the water.
	var home := Vector3.ZERO
	## Where its flight began: it climbs away from there.
	var from := Vector3.ZERO
	## Which of its species' tints it is drawn in.
	var tint := 0
	## A flyer is in the air, or sits in a tree crown (a climber too).
	var flying := false
	var perched := false
	## A climber on its way to the tree its target is on top of.
	var climb := false
	## A climber up a tree (perched): where it stood at the trunk's foot, which it
	## comes down to (INF: not up a tree), and its spot on top of the crown.
	var foot := Vector3.INF
	var crown := Vector3.ZERO
	## The one it follows in its flock, null for a lead or one alone, and its own
	## place in the flock around the lead.
	var lead: Animal = null
	var spot := Vector3.ZERO
	## Where the threat it flees from was, for its flock to take fright too.
	var fear := Vector3.ZERO
	## Hits of power 1 it takes yet (its species' `health`; 0: it cannot be hit).
	var health := 0
	## Seconds it keeps fleeing from where it was last hit (see hurt), and that place.
	var hurt := 0.0
	var hurt_from := Vector3.ZERO
	## Eaten or killed, out of the world.
	var gone := false
	## The frame of its picture drawn (on the client, see Creatures).
	var frame := 0
	## A flyer's last cell under it and the top of the ground or crown there (see
	## _canopy), looked up again only in a new cell.
	var over := Vector2i(1 << 30, 0)
	var below := 0.0
	## Where a walker last looked up the floor under it and what it found (see _move):
	## looking it up costs the most of a step, so it is kept for the next few.
	var looked := Vector3(INF, 0.0, INF)
	var floor_y := 0.0
	## Whether that floor is the water's (a swimmer swims there).
	var floor_wet := false
	## A fish lured by the float of a fishing line swims there and stays (Fishing sets
	## and clears it); INF none.
	var bait := Vector3.INF
	## Tamed (Taming): the number of its owner (Player.id), -1 for a wild one; where it
	## was told to stay (INF: it follows its owner); how many times a wild one was fed by
	## hand, when it last ate from a hand and when it was last shorn (days of the Clock).
	var owner := -1
	var stay := Vector3.INF
	var fed := 0
	var fed_at := -INF
	var shorn_at := 0.0
	## Attacks (see _fights): the one of the people it goes for (null: none), whether it
	## hunts them (else it defends itself or its ground), the seconds its fury lasts yet,
	## the seconds it leaves the people be after a fight, the seconds of its warning left,
	## the seconds of a bite left before it lands, the seconds before it may
	## bite again, the bites it landed in this fight, and who hit it last (null: no one of
	## the people).
	var foe = null
	var hunting := false
	var rage := 0.0
	var calm := 0.0
	var warn := 0.0
	var bite := 0.0
	var bite_wait := 0.0
	var bites := 0

	## Off the ground, out of reach of those that walk.
	func aloft() -> bool:
		return flying or perched


var world
## The things placed (Placed): its burning fires and lights set down keep the animals off
## (see _find_fires); null for none.
var placed
## The layout of the land (LandLayout: `lay_out`), for the biome of a column, where
## species keep to their biomes; null when any ground will do.
var gen
## The clock, for the daylight that sets who is active.
var clock
## The rules of play (Rules): `animal_attacks` lets the animals go for the people; null
## lets them.
var rules
## Those the animals see as people (threats to the wary, see AiRules.HUMAN): anything
## with a `position` in world units. The chunks around them get their animals (see _settle_new).
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
var _settle_timer := 0.0
## The chunks that got their animals: for each, by kind, its share of a kind's `count`
## (its share of ROAM_CHUNKS times the share of it that is the kind's biomes).
var _settled := {}
var _daylight := 1.0
## What each kind is to each (see _sees), worked out from AiRules once.
var _seen := {}
## The kinds each kind looks for (see _cares), and the animals by kind (see _kin) with
## the count of `animals` they were made for.
var _caring := {}
var _by_kind := {}
var _kin_of := -1
## What the people were pushed by the animals they ran into (see _jostle), in world
## units, one for each of `people` (on the client, the player's body takes it).
var pushes: Array[Vector3] = []
## The animals that stepped in the last update, in their order: only those can have
## moved since (the server's snapshots look at them, PlayerLink._snap).
var moved: Array[Animal] = []
## The number the last animal got (Animal.id).
var _next_id := 0
## What keeps the animals off now (see _find_fires): [middle, reach in world units,
## true for a light in a hand], and the seconds until it is looked for again.
var _fires: Array = []
var _fire_timer := 0.0
## Whether start ran, and the tamed animals of a save waiting for it (see add_tamed).
var _started := false
var _kept_tame: Array = []
## What the made up for is still to do (_plan_refill): [kind, share, around, cells].
var _refills: Array = []

## A walker looks the floor up again after this much of a cell walked within one
## cell: a slope under its feet is followed a step late, less than a pixel.
const LOOK_AGAIN := 0.2 * CELL

const PERSON_WEAK := 0.4
const ARMED := 1.3
const WINTER_BOLD := 1.25


static func _within(p: Vector3, around: Vector3, reach: float) -> bool:
	return absf(p.x - around.x) <= reach and absf(p.z - around.z) <= reach


func count(kind: String) -> int:
	var n := 0
	for a in animals:
		if a.kind == kind:
			n += 1
	return n


## How many of `kind` live around the people now: its `count`, or for one that comes
## after rain that share of it as there is water in the puddles (none in winter).
func wanted(kind: String) -> int:
	var spec: Dictionary = AiRules.SPECIES[kind]
	if not spec.after_rain:
		return spec.count
	if clock == null or clock.season == clock.WINTER:
		return 0
	return floori(spec.count * maxf(clock.wet, clock.puddles) + 0.5)


## The one of the people who owns tamed animal `a` (their `id`), null when they are not
## here.
func owner_of(a: Animal) -> Variant:
	for who in people:
		if int(who.get("id") if "id" in who else 0) == a.owner:
			return who
	return null


## A Vector3 of a list of three numbers read from a save, null for anything else.
static func _vector(v: Variant) -> Variant:
	if not v is Array or v.size() != 3:
		return null
	for n in v:
		if not (n is float or n is int) or not is_finite(float(n)):
			return null
	return Vector3(v[0], v[1], v[2])


## True for a flyer with no frames to hop on the ground (`hop` 0, a butterfly): it
## either flies or sits still where it landed, beating its wings (see Creatures); it
## neither hops about nor is shoved by those near it.
static func sits_still(spec: Dictionary) -> bool:
	return spec.flies and int(spec.get("hop", 0)) <= 0


## Whether the floor `a` last looked up (Animal.looked, floor_y) still serves at a world
## point: the same cell, within LOOK_AGAIN of where it looked.
func _looked(a: Animal, x: float, z: float) -> bool:
	return floori(x / CELL) == floori(a.looked.x / CELL) and floori(z / CELL) == floori(a.looked.z / CELL) \
			and absf(x - a.looked.x) + absf(z - a.looked.z) < LOOK_AGAIN


## Height of the ground at a world point, in world units; below 0 over open water.
func ground(x: float, z: float) -> float:
	return world.ground_height(x / CELL, z / CELL) * CELL


## The species read anew (a hot reload, Session.reread): what each kind looks for is
## worked out again, and the animals of a kind no longer loaded leave the world.
func reread() -> void:
	_caring = {}
	_seen = {}
	for a in animals.duplicate():
		if not AiRules.SPECIES.has(a.kind):
			_remove(a)
	_kin_of = -1


## Takes animal `a` out of the world (a fish pulled out on a line, Fishing).
func take(a: Animal) -> void:
	if not a.gone:
		_remove(a)


## Height of the water surface at a world point, in world units; -INF where the
## column's top is not open (unfrozen) water.
func water_top(x: float, z: float) -> float:
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	if world.surface_y(cx, cz) != -1:
		return -INF
	return (WorldData.top_level(world.water_col(cx, cz)) + WorldData.WATER_TOP) * CELL


## Where frozen water has open water under its ice, at a world point: the bottom of the
## ice (the top cell of the water frozen), in world units, where the water is two cells
## deep at least; -INF elsewhere, and where the water is not frozen.
func under_ice(x: float, z: float) -> float:
	if not world.water_frozen:
		return -INF
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	var bits: int = world.water_col(cx, cz)
	if bits == 0:
		return -INF
	var top := WorldData.top_level(bits)
	if top < 1 or world.surface_y(cx, cz) != top + 1 or world.get_cell(cx, top - 1, cz) != Mat.WATER:
		return -INF
	return top * CELL


## Whether species `spec` swims under the ice of frozen water (a fish: one that swims
## and neither flies nor comes ashore).
static func under_ice_swimmer(spec: Dictionary) -> bool:
	return spec.swims and not spec.flies and not spec.ashore


## Where an animal of species `spec` stands at a world point, in world units: the
## ground for a walker, DIP under the water surface for a swimmer (the ground out of
## the water for one that comes ashore), DIP under the ice for a fish in frozen water;
## 0 or below where it cannot be (water for the one, land for the other).
func _floor(spec: Dictionary, x: float, z: float) -> float:
	if spec.swims:
		var top := water_top(x, z)
		if top == -INF and spec.ashore:
			return _fenced(ground(x, z), x, z)
		if top == -INF and under_ice_swimmer(spec):
			top = under_ice(x, z)
		return top - DIP * CELL
	return _fenced(ground(x, z), x, z)


## The floor `y` (world units) at world point x, z, or one far over it where a thing
## over a cell and a half high stands there (a fence, a gate shut, a door: Placed, WorldData.blockers),
## within FENCE_GAP cells of the point: no step goes up it, so a fence keeps the animals in
## a pen and out of a yard. Lower things (a chest, a campfire) are walked through, as before.
func _fenced(y: float, x: float, z: float) -> float:
	if world.blockers.is_empty() or y <= 0.0:
		return y
	var px := x / CELL
	var pz := z / CELL
	var cx := floori(px)
	var cz := floori(pz)
	var fx := px - cx
	var fz := pz - cz
	# Over a cell and a half high: it stands into the cell over its own (WorldData.blocker_part).
	if world.blocker_part(cx, floori(y / CELL + 0.01) + 1, cz, fx - FENCE_GAP, fx + FENCE_GAP, fz - FENCE_GAP, fz + FENCE_GAP) > 0.5:
		return y + 4.0 * CELL
	return y


func _remove(a: Animal) -> void:
	var kept := _kin_of == animals.size()
	animals.erase(a)
	if kept:
		_by_kind[a.kind].erase(a)
		_kin_of = animals.size()
	a.gone = true
	# The first of its flock leads the rest from now on.
	var next: Animal = null
	for o in animals:
		if o.lead == a:
			if next == null:
				next = o
				o.lead = null
			else:
				o.lead = next
	gone.emit(a)


## Whether `pos` is within `away` of any of the people (on the ground).
func _near_people(pos: Vector3, away: float) -> bool:
	for who in people:
		var d: Vector3 = who.position - pos
		if Vector2(d.x, d.z).length() < away:
			return true
	return false


func _add(kind: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	_next_id += 1
	a.id = _next_id
	a.kind = kind
	a.pos = pos
	a.target = pos
	a.hunger = rng.randf() * 0.5
	a.think = rng.randf() * 0.5
	a.home = pos
	a.floor_wet = AiRules.SPECIES[kind].swims
	a.radius = radius(AiRules.SPECIES[kind])
	a.health = AiRules.SPECIES[kind].health
	var tints: Array = AiRules.SPECIES[kind].tints
	if tints.size() > 1:
		a.tint = rng.randi() % tints.size()
	# Those far away take their steps in different frames.
	a.away = rng.randf() * FAR_STEP
	if _kin_of == animals.size():
		_by_kind.get_or_add(kind, []).append(a)
		_kin_of += 1
	animals.append(a)
	born.emit(a)
	return a


## Marks the animals on one of the players' screens as looked at (`near`), the rest
## not: `from` has for each player [where they stand (Vector3), the way their screen's
## width lies over the ground (Vector2, unit) and half its width and height in world
## units (Vector2; see Character.view_half)]. A screen not told (zero) is a circle of
## NEAR; a screen is taken as at most NEAR each way.
func look_from(from: Array) -> void:
	# The screens unpacked once: this runs for every animal every frame.
	var near2 := NEAR * NEAR
	var n := from.size()
	var ats := PackedVector2Array()
	var rights := PackedVector2Array()
	var halves := PackedVector2Array()
	for view: Array in from:
		var at: Vector3 = view[0]
		var half: Vector2 = view[2]
		ats.append(Vector2(at.x, at.z))
		rights.append(view[1])
		# A screen not told is a circle (see below).
		halves.append(Vector2.ZERO if half == Vector2.ZERO else Vector2(minf(half.x, NEAR), minf(half.y, NEAR)))
	for a in animals:
		var near := false
		var px := a.pos.x
		var pz := a.pos.z
		for i in n:
			var dx := px - ats[i].x
			var dz := pz - ats[i].y
			var half := halves[i]
			if half == Vector2.ZERO:
				if dx * dx + dz * dz < near2:
					near = true
					break
				continue
			var right := rights[i]
			if absf(dx * right.x + dz * right.y) < half.x and absf(dz * right.x - dx * right.y) < half.y:
				near = true
				break
		a.near = near


## A body's half width on the ground, in world units, by its mass.
static func radius(spec: Dictionary) -> float:
	return clampf(0.12 * pow(spec.mass, 1.0 / 3.0), 0.05, 0.6)


static func _wester(a: Animal, b: Animal) -> bool:
	return a.pos.x < b.pos.x


## Looks up the floor of animal `a` at `at` (world units, its height unused) and keeps
## it: the level, whether it is water to swim in, and where an ashore swimmer last swam.
func _look_floor(a: Animal, spec: Dictionary, at: Vector3) -> float:
	var y := _floor(spec, at.x, at.z)
	a.looked = at
	a.floor_y = y
	a.floor_wet = spec.swims and (not spec.ashore or water_top(at.x, at.z) > -INF)
	if spec.ashore and a.floor_wet:
		a.home = at
	return y
