extends "res://tests/unit/test_case.gd"
## The animals: who fears whom, how they come, wander, flee and hunt, flocks and birds.


func run() -> void:
	_test_ai_relations()
	_test_wildlife()


func _test_ai_relations() -> void:
	# The example from the design: a cat is food for a wolf, the wolf is a threat
	# to the cat, and the cat hunts squirrels, with no rule written for the cat.
	_check(AiRules.is_food("animals:wolf", "animals:cat"), "wolf sees a cat as food")
	_check(AiRules.is_threat("animals:cat", "animals:wolf"), "cat sees a wolf as a threat")
	_check(not AiRules.is_food("animals:cat", "animals:wolf"), "cat does not hunt wolves")
	_check(AiRules.is_food("animals:cat", "animals:squirrel"), "cat hunts squirrels")
	_check(AiRules.is_food("animals:cat", "animals:rabbit"), "cat hunts rabbits")
	_check(AiRules.is_threat("animals:squirrel", "animals:cat"), "squirrel fears a cat")
	_check(not AiRules.is_threat("animals:cat", "animals:deer"), "cat ignores deer")
	_check(not AiRules.is_food("animals:deer", "animals:rabbit"), "herbivores hunt nobody")
	_check(not AiRules.is_food("animals:wolf", "core:human"), "a lone wolf does not see a human as food")
	_check(AiRules.is_threat("animals:rabbit", "core:human"), "rabbit fears people")
	_check(AiRules.is_active("animals:wolf", 0.0) and not AiRules.is_active("animals:wolf", 1.0), "wolves are active at night")
	# Water and land: a walker does not hunt what swims, nor a swimmer what walks, but
	# a flyer gets at both.
	_check(not AiRules.is_food("animals:cat", "animals:perch"), "a cat does not hunt fish")
	_check(not AiRules.is_threat("animals:frog", "animals:cat"), "a frog does not fear a cat")
	_check(AiRules.is_food("animals:perch", "animals:frog"), "a perch hunts frogs")
	_check(AiRules.is_food("animals:owl", "animals:frog") and AiRules.is_food("animals:owl", "animals:sparrow"), "an owl hunts frogs and sparrows")
	_check(AiRules.is_threat("animals:sparrow", "animals:crow"), "a sparrow fears a crow")


## A forest chunk the player changed (a tree felled, a hole dug, a block placed, a bush
## gone) is saved, and a new run of the same world brings it back as it was, whatever
## order the chunks around are made in; its trees grow again into the chunks around.
## The animals live without the client: they come onto the grass around the people the
## same for the same seed, flee from people, rest outside their hours, hunt, and the
## ones no one looks at move in steps.
func _test_wildlife() -> void:
	var size := WorldData.CHUNK * 11
	var w := WorldData.new(8, Vector2i(size, size))
	for z in size:
		for x in size:
			w.set_cell(x, 5, z, Mat.GRASS)
	var person := Who.new()
	person.position = Vector3(size / 2.0, 6.0, size / 2.0) * WorldData.CELL
	var made := []
	for i in 2:
		var life := Wildlife.new()
		life.world = w
		life.clock = Clock.new()
		life.people = [person]
		var born := [0]
		life.born.connect(func(_a: Wildlife.Animal) -> void: born[0] += 1)
		life.start(7)
		made.append(life.animals.map(func(a: Wildlife.Animal) -> String: return "%s %v" % [a.kind, a.pos]))
		# The swimmers find no water here (see _test_swimmers).
		var all := 0
		for kind in AiRules.SPECIES:
			if kind != AiRules.HUMAN and not AiRules.SPECIES[kind].swims:
				all += AiRules.SPECIES[kind].count
		_check(life.animals.size() == all and born[0] == all, "as many animals come as their species say")
	_check(made[0] == made[1], "the same seed brings the same animals to the same places")

	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.people = [person]
	var at := person.position + Vector3(3.0, 0.0, 0.0)
	at.y = life.ground(at.x, at.z)
	var rabbit := _animal(life, "animals:rabbit", at)
	var prints := [0]
	life.stepped.connect(func(_a: Wildlife.Animal, _at: Vector3, _dir: Vector2, _left: bool, _size: float) -> void: prints[0] += 1)
	for i in 20:
		life.update(0.05)
	_check(rabbit.pos.distance_to(person.position) > 5.0 and rabbit.pos.x > at.x and prints[0] > 0,
		"a rabbit runs from a person, leaving prints")

	# Far from the people from now on.
	life.people = [Who.new()]
	life.animals.clear()
	life.clock.time_of_day = 0.5
	var wolf := _animal(life, "animals:wolf", at)
	life.update(0.05)
	_check(wolf.state == "rest" and wolf.pos == at, "a wolf rests by day")
	life.clock.time_of_day = 0.0
	wolf.hunger = 1.0
	wolf.think = 0.0
	rabbit = _animal(life, "animals:rabbit", at + Vector3(0.5, 0.0, 0.0))
	var eaten := []
	life.gone.connect(func(a: Wildlife.Animal) -> void: eaten.append(a))
	life.update(0.05)
	_check(eaten == [rabbit] and life.animals == [wolf] and wolf.hunger == 0.0, "a hungry wolf hunts a rabbit at night")

	wolf.near = false
	wolf.think = 100.0
	wolf.state = "wander"
	wolf.target = wolf.pos + Vector3(4.0, 0.0, 0.0)
	var from := wolf.pos
	life.update(0.05)
	_check(wolf.pos == from and is_equal_approx(wolf.away, 0.05), "an animal no one looks at waits for its step")
	life.update(0.06)
	_check(wolf.pos != from and wolf.away == 0.0, "and then takes it at once")
	_check(wolf.moving, "a walking animal walks its picture")
	_test_birds(w, person)
	_test_swimmers(w)
	_test_climbers(w, person)
	_test_biomes(w)
	_test_shore(w)
	_test_jostle(w)


## A walker that roosts in trees (the squirrel bundle) runs up a tree near it from a
## person, where a cat does not get it, and comes down once they are gone.
func _test_climbers(w: WorldData, person: Who) -> void:
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.clock.time_of_day = 0.5
	life.people = [person]
	var at := person.position + Vector3(2.0, 0.0, 0.0)
	at.y = life.ground(at.x, at.z)
	var tx := floori(at.x / WorldData.CELL) + 4
	var tz := floori(at.z / WorldData.CELL)
	w.set_cell(tx, 6, tz, Mat.LOG)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			w.set_cell(tx + dx, 7, tz + dz, Mat.LEAVES)
	w.add_tree(tx, tz, 0)
	var squirrel := _animal(life, "animals:squirrel", at)
	var cat := _animal(life, "animals:cat", at + Vector3(-1.0, 0.0, 0.0))
	cat.hunger = 1.0
	for i in 120:
		life.update(0.05)
		if squirrel.perched:
			break
	_check(squirrel.perched and squirrel.state == "flee" and is_equal_approx(squirrel.pos.y, 8 * WorldData.CELL)
		and life.animals.has(squirrel), "a squirrel runs up a tree from a person, out of a cat's reach")
	life.people = [Who.new()]
	life.animals.erase(cat)
	for i in 40:
		life.update(0.05)
	_check(not squirrel.perched and is_equal_approx(squirrel.pos.y, life.ground(squirrel.pos.x, squirrel.pos.z)),
		"and comes down when they are gone")
	w.remove_tree(tx, tz)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			w.set_cell(tx + dx, 7, tz + dz, Mat.AIR)
	w.set_cell(tx, 6, tz, Mat.AIR)


## A layout that says every column is one biome.
class OneBiome extends RefCounted:
	var biome := 0
	func lay_out(_x: int, _z: int, _w: int, _h: int, _step := 1) -> Dictionary:
		return {"biome": PackedByteArray([biome])}


## A species that names its biomes comes only onto their ground: wolves (taiga, forest,
## tundra) on a forest, none on a meadow.
func _test_biomes(w: WorldData) -> void:
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	var person := Who.new()
	person.position = Vector3(40.0, 6.0, 40.0) * WorldData.CELL
	life.people = [person]
	var lay := OneBiome.new()
	life.gen = lay
	lay.biome = Biomes.index("biomes:forest")
	life.start(2)
	var wolves := life.count("animals:wolf")
	lay.biome = Biomes.index("biomes:meadow")
	life.animals.clear()
	life.start(2)
	_check(wolves == AiRules.SPECIES["animals:wolf"].count and life.count("animals:wolf") == 0
		and life.count("animals:rabbit") == AiRules.SPECIES["animals:rabbit"].count,
		"wolves come to a forest and not a meadow, rabbits to a meadow (%d, %d)" % [wolves, life.count("animals:wolf")])


## Swimmers (the perch bundle) keep to open water: one put into a pond stays a little
## under its surface, and stops at the shore when its way leads onto the land.
func _test_swimmers(w: WorldData) -> void:
	var px := 20
	var pz := 20
	var side := 80
	for z in range(pz, pz + side):
		for x in range(px, px + side):
			w.set_cell(x, 3, z, Mat.DIRT)
			w.set_cell(x, 4, z, Mat.WATER)
			w.set_cell(x, 5, z, Mat.WATER)
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.clock.time_of_day = 0.5
	life.people = [Who.new()]
	var at := Vector3(px + 3.0, 0.0, pz + 3.0) * WorldData.CELL
	var top := (5.0 + WorldData.WATER_TOP) * WorldData.CELL
	_check(is_equal_approx(life.water_top(at.x, at.z), top), "the water surface of a pond")
	var fish := _animal(life, "animals:perch", at)
	fish.pos.y = top - Wildlife.DIP * WorldData.CELL
	fish.state = "flee"
	fish.think = 100.0
	fish.target = at + Vector3(side + 10.0, 0.0, 0.0) * WorldData.CELL
	for i in 400:
		life.update(0.05)
	var swam := fish.pos.x > at.x + 1.0
	var in_water: bool = w.get_cell(floori(fish.pos.x / WorldData.CELL), 5, floori(fish.pos.z / WorldData.CELL)) == Mat.WATER
	_check(swam and in_water and fish.pos.x < (px + side) * WorldData.CELL and fish.target == fish.pos
		and is_equal_approx(fish.pos.y, top - Wildlife.DIP * WorldData.CELL),
		"a perch swims to the shore and no further (%v)" % fish.pos)
	life.animals.clear()
	life.people = [Who.new()]
	life.people[0].position = at
	life.start(5)
	var fishes := 0
	for a in life.animals:
		if a.kind == "animals:perch":
			fishes += 1
			if w.get_cell(floori(a.pos.x / WorldData.CELL), 5, floori(a.pos.z / WorldData.CELL)) != Mat.WATER:
				fishes = -100
	_check(fishes == AiRules.SPECIES["animals:perch"].count, "perches come into the water (%d)" % fishes)
	for z in range(pz, pz + side):
		for x in range(px, px + side):
			w.set_cell(x, 3, z, Mat.AIR)
			w.set_cell(x, 4, z, Mat.AIR)
			w.set_cell(x, 5, z, Mat.GRASS)


## Birds (the sparrow bundle of the animals mod) come in flocks around a lead, fly off from a person together
## and come down again away from them, out of a cat's reach while in the air, and
## sleep in the crowns at night.
func _test_birds(w: WorldData, person: Who) -> void:
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.clock.time_of_day = 0.5
	life.people = [person]
	life.start(3)
	var flocked: bool = life.count("animals:sparrow") == AiRules.SPECIES["animals:sparrow"].count
	var leads := 0
	for a in life.animals:
		if a.kind != "animals:sparrow":
			continue
		if a.lead == null:
			leads += 1
		elif a.lead.kind != a.kind or a.pos.distance_to(a.lead.pos) > Wildlife.FLOCK_REACH * 2.0:
			flocked = false
	_check(flocked and leads >= 2 and leads <= 5, "sparrows come in flocks (%d)" % leads)

	life.animals.clear()
	var at := person.position + Vector3(2.0, 0.0, 0.0)
	at.y = life.ground(at.x, at.z)
	var lead := _animal(life, "animals:sparrow", at + Vector3(1.0, 0.0, 0.0))
	var mate := _animal(life, "animals:sparrow", at + Vector3(6.0, 0.0, 0.0))
	mate.lead = lead
	life.update(0.05)
	_check(lead.flying and lead.state == "flee", "a sparrow takes off from a person")
	var cat := _animal(life, "animals:cat", lead.pos)
	cat.hunger = 1.0
	# Each bird thinks on its own beat (0.4..0.7 s): the lead must notice the cat, then
	# the mate the lead's fright.
	var high := 0.0
	for i in 60:
		life.update(0.05)
		high = maxf(high, lead.pos.y - at.y)
		if mate.state == "flee":
			break
	_check(mate.flying and mate.state == "flee", "its flock takes fright with it")
	_check(cat.state != "hunt" and life.animals.has(lead), "a cat does not hunt a bird in the air")
	# It lands (it may fly over again later, on its own).
	var landed := false
	for i in 200:
		life.update(0.05)
		if not lead.flying and lead.pos.distance_to(person.position) > 8.0 \
				and absf(lead.pos.y - life.ground(lead.pos.x, lead.pos.z)) < 0.01:
			landed = true
			break
	_check(high > 1.0 and landed,
		"it flies up and comes down away from the person (%.1f high, %.1f away)" % [high, lead.pos.distance_to(person.position)])

	# A tree away from everyone, and night.
	life.people = [Who.new()]
	life.animals.clear()
	var tx := floori(at.x / WorldData.CELL) + 6
	var tz := floori(at.z / WorldData.CELL)
	w.set_cell(tx, 6, tz, Mat.LOG)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			w.set_cell(tx + dx, 7, tz + dz, Mat.LEAVES)
	w.add_tree(tx, tz, 0)
	life.clock.time_of_day = 0.0
	var bird := _animal(life, "animals:sparrow", at)
	for i in 100:
		life.update(0.05)
	_check(bird.perched and bird.state == "rest" and is_equal_approx(bird.pos.y, 8 * WorldData.CELL),
		"a sparrow sleeps in a tree crown at night")
	w.remove_tree(tx, tz)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			w.set_cell(tx + dx, 7, tz + dz, Mat.AIR)
	w.set_cell(tx, 6, tz, Mat.AIR)


## Puts an animal of `kind` at `at` into `life`, about to think.
## Ducks and frogs (swimmers that come ashore) keep to their pond and its shore: a duck
## paddles about and walks the bank, flies seldom and lands on the water again; a frog
## comes out only after rain and goes on land in leaps.
func _test_shore(w: WorldData) -> void:
	var px := 20
	var pz := 20
	var side := 12
	for z in range(pz, pz + side):
		for x in range(px, px + side):
			w.set_cell(x, 3, z, Mat.DIRT)
			w.set_cell(x, 4, z, Mat.WATER)
			w.set_cell(x, 5, z, Mat.WATER)
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.clock.time_of_day = 0.5
	life.people = [Who.new()]
	life.people[0].position = Vector3(150.0, 6.0, 150.0) * WorldData.CELL
	var pond := Rect2(px, pz, side, side)
	var at := Vector3(px + side * 0.5, 0.0, pz + side * 0.5) * WorldData.CELL
	life.rng.seed = 7
	var duck := _animal(life, "animals:duck", at)
	duck.pos.y = life.water_top(at.x, at.z) - Wildlife.DIP * WorldData.CELL
	duck.home = duck.pos
	duck.floor_wet = true
	var aloft := 0
	var ashore := 0
	var far := 0.0
	var steps := 2400
	for i in steps:
		life.update(0.05)
		if duck.flying:
			aloft += 1
		var cell := Vector2(duck.pos.x, duck.pos.z) / WorldData.CELL
		if not pond.has_point(cell):
			ashore += 1
			far = maxf(far, maxf(maxf(pond.position.x - cell.x, cell.x - pond.end.x), maxf(pond.position.y - cell.y, cell.y - pond.end.y)))
	_check(aloft < steps / 5 and ashore > 0 and far < Wildlife.SHORE / WorldData.CELL + 1.0,
		"a duck paddles, walks the bank near its pond and flies seldom (%d of %d aloft, %d ashore, %.1f cells out)" % [aloft, steps, ashore, far])
	_check(life.wanted("animals:frog") == 0, "no frogs while it is dry")
	life.clock.puddles = 1.0
	_check(life.wanted("animals:frog") == AiRules.SPECIES["animals:frog"].count, "frogs come out after rain")
	life.animals.clear()
	var bank := Vector3(px - 2.0, 0.0, pz + 2.0) * WorldData.CELL
	bank.y = life.ground(bank.x, bank.z)
	var frog := _animal(life, "animals:frog", bank)
	frog.home = Vector3(px + 0.5, 0.0, pz + 2.0) * WorldData.CELL
	frog.think = 100.0
	frog.target = bank + Vector3(0.0, 0.0, 1.5)
	var leapt := 0.0
	for i in 100:
		life.update(0.05)
		leapt = maxf(leapt, frog.lift)
	_check(leapt > 0.1 and frog.pos.distance_to(frog.target) < 0.05, "a frog hops along on land (%.2f high, %.2f to go)" % [leapt, frog.pos.distance_to(frog.target)])
	for z in range(pz, pz + side):
		for x in range(px, px + side):
			w.set_cell(x, 3, z, Mat.AIR)
			w.set_cell(x, 4, z, Mat.AIR)
			w.set_cell(x, 5, z, Mat.GRASS)


## Bodies on the ground push each other apart, and a heavy one pushes a person back.
func _test_jostle(w: WorldData) -> void:
	var life := Wildlife.new()
	life.world = w
	life.clock = Clock.new()
	life.clock.time_of_day = 0.5
	var person := Who.new()
	person.position = Vector3(100.0, 6.0, 100.0) * WorldData.CELL
	life.people = [person]
	var at := Vector3(40.0, 0.0, 120.0) * WorldData.CELL
	at.y = life.ground(at.x, at.z)
	var one := _animal(life, "animals:deer", at)
	var two := _animal(life, "animals:deer", at + Vector3(0.05, 0.0, 0.0))
	one.think = 100.0
	two.think = 100.0
	for i in 5:
		life.update(0.05)
	var apart := Wildlife.radius(AiRules.SPECIES["animals:deer"]) * 2.0
	_check(one.pos.distance_to(two.pos) > apart * 0.95, "two deer do not stand in one another (%.2f)" % one.pos.distance_to(two.pos))
	life.animals.clear()
	var bear := _animal(life, "animals:bear", person.position + Vector3(0.1, 0.0, 0.0))
	bear.pos.y = life.ground(bear.pos.x, bear.pos.z)
	bear.think = 100.0
	life.update(0.05)
	_check(life.pushes[0].x < -0.1, "a bear pushes a person back (%v)" % life.pushes[0])


func _animal(life: Wildlife, kind: String, at: Vector3) -> Wildlife.Animal:
	var a := Wildlife.Animal.new()
	a.kind = kind
	a.pos = at
	a.target = at
	a.radius = Wildlife.radius(AiRules.SPECIES[kind])
	life.animals.append(a)
	return a
