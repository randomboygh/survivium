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
		var all := 0
		for kind in AiRules.SPECIES:
			if kind != AiRules.HUMAN:
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
	_test_birds(w, person)


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
	for i in 200:
		life.update(0.05)
	_check(high > 1.0 and not lead.flying and lead.pos.distance_to(person.position) > 8.0
		and absf(lead.pos.y - life.ground(lead.pos.x, lead.pos.z)) < 0.01,
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
func _animal(life: Wildlife, kind: String, at: Vector3) -> Wildlife.Animal:
	var a := Wildlife.Animal.new()
	a.kind = kind
	a.pos = at
	a.target = at
	life.animals.append(a)
	return a
