extends "res://tests/unit/test_case.gd"
## The character: the bag, tool wear, vitals, the change log and death.

const DeathScreen := preload("res://src/client/ui/death_screen.gd")


func run() -> void:
	_test_inventory()
	_test_wear()
	_test_gear()
	_test_torch()
	_test_spoil()
	_test_vitals()
	_test_warmth()
	_test_thirst()
	_test_good_food()
	_test_sleep()
	_test_changes()
	_test_death()
	_test_fall()
	_test_sack_ends()
	_test_graves()
	_test_bed_respawn()
	_test_poultice()


func _test_inventory() -> void:
	var inv := Inventory.new(3)
	var log_stack := Items.stack_size("resources:log")
	_check(inv.add("resources:branch", 5) == 5 and inv.count("resources:branch") == 5, "items go into the bag")
	_check(inv.add("resources:branch", 3) == 3 and inv.slots[1] == null, "a stack is topped up before a new slot")
	_check(inv.add("resources:log", log_stack * 3) == log_stack * 2, "only what fits goes in")
	_check(inv.room_for("resources:log") == 0 and inv.room_for("resources:branch") == Items.stack_size("resources:branch") - 8, "room is counted by stacks")
	var w := 8 * Items.weight("resources:branch") + log_stack * 2 * Items.weight("resources:log")
	_check(is_equal_approx(inv.weight(), w), "the bag weighs its items")
	_check(inv.remove("resources:log", 1) == 1 and inv.count("resources:log") == log_stack * 2 - 1, "items come out of the bag")
	var heavy := Inventory.new()
	_check(heavy.speed_factor() == 1.0, "an empty bag does not slow")
	heavy.add("resources:stone", ceili(Inventory.WEIGHT_LIMIT * 1.25 / Items.weight("resources:stone")))
	var f := heavy.speed_factor()
	_check(heavy.overloaded() and f < 1.0 and f > Inventory.OVERLOAD_PACE, "overload slows the pace")
	heavy.add("resources:stone", 200)
	_check(heavy.speed_factor() == Inventory.OVERLOAD_PACE, "heavy overload almost stops")
	heavy.heavy = false
	_check(heavy.speed_factor() == 1.0 and not heavy.overloaded(), "with overload off a full bag does not slow")
	var copy := Inventory.new(3)
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(copy.count("resources:branch") == 8 and copy.count("resources:log") == inv.count("resources:log"), "the bag survives a save as JSON")
	copy.from_dict({"slots": [["core:nothing", 3], ["resources:branch", 2]]})
	_check(copy.slots[0] == null and copy.count("resources:branch") == 2, "unknown items are left out on load")
	var all := inv.take_all()
	_check(inv.is_empty() and all.size() == 3, "a death empties the bag into a sack")
	_check(Items.category("tools:stone_axe") == "tools" and Items.category("tools:workbench") == "stations"
		and Items.category("plants:raspberry") == "food" and Items.category("plants:grain") == "plants"
		and Items.category("resources:stone") == "blocks" and Items.category("resources:fiber") == "materials",
		"an item's kind follows from what it does")
	var mess := Inventory.new(8)
	mess.slots = [["resources:fiber", 1], null, ["resources:stone", 3], ["resources:fiber", 2], null, ["tools:stone_axe", 1, 5],
		["plants:raspberry", 4], ["resources:fiber", 4]]
	mess.sort("kind", 1)
	_check(mess.slots[0] == ["resources:fiber", 1] and mess.slots[1] == ["tools:stone_axe", 1, 5]
		and mess.slots[2] == ["resources:fiber", 6] and mess.slots[3] == ["resources:stone", 3]
		and mess.slots[4] == ["plants:raspberry", 4] and mess.slots[5] == null and mess.slots[7] == null,
		"sorting by kind tops up stacks, keeps a worn tool apart and leaves the first slots alone")
	mess.sort("weight")
	_check(mess.slots[0] == ["resources:stone", 3] and mess.slots[1] == ["tools:stone_axe", 1, 5] and mess.count("resources:fiber") == 7,
		"sorting by weight puts the heaviest stacks first")
	var box := Inventory.new(2)
	mess.slots = [["resources:fiber", 7], ["resources:stone", 3], null]
	mess.put_into(0, mess, 2)
	_check(mess.slots[0] == null and mess.slots[2] == ["resources:fiber", 7], "a stack moves to an empty slot")
	mess.put_into(1, mess, 2)
	_check(mess.slots[1] == ["resources:fiber", 7] and mess.slots[2] == ["resources:stone", 3], "two stacks swap")
	box.slots = [["resources:fiber", Items.stack_size("resources:fiber") - 2], null]
	mess.put_into(1, box, 0)
	_check(box.count("resources:fiber") == Items.stack_size("resources:fiber") and mess.slots[1] == ["resources:fiber", 5],
		"onto a stack of the same item, as much as it takes")
	# A chest taken up with things in it keeps them and weighs them.
	var chest := Inventory.new(4)
	chest.nests = false
	chest.add("resources:stone", 5)
	var bag := Inventory.new(4)
	_check(bag.add("tools:chest", 1, 0, chest.to_dict()) == 1 and bag.contents(0) != null, "a chest goes into the bag with what it holds")
	_check(is_equal_approx(bag.weight(), Items.weight("tools:chest") + 5 * Items.weight("resources:stone")), "and weighs it too")
	_check(bag.add("tools:chest", 1) == 1 and bag.slots[1] != null and bag.slots[1].size() == 2, "an empty chest takes a slot of its own")
	_check(bag.remove("tools:chest", 2) == 1 and bag.contents(0) != null, "a chest with things in it is not used up")
	_check(bag.move_slot(0, chest) == 0, "a chest with things in it does not go into a chest")
	var kept := Inventory.new(4)
	kept.from_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	var inner := Inventory.new(4)
	inner.from_dict(kept.contents(0))
	_check(inner.count("resources:stone") == 5, "the chest's things survive a save")
	var old_bag := Inventory.new(4)
	old_bag.from_dict({"slots": [["core:branch", 3], ["core:stone", 2, 0], ["nobody:thing", 1]]})
	_check(old_bag.count("resources:branch") == 3 and old_bag.count("resources:stone") == 2 and old_bag.slots[2] == null,
		"a bag saved with the old ids of the base items comes back with the new ones")
	_check(not bag.put_into(0, chest, 1) and bag.contents(0) != null and chest.slots[1] == null,
		"nor is it moved into a chest's slot")
	var put = bag.take_slot(0, 1)
	_check(put.size() == 4 and put[3] is Dictionary and bag.is_empty(), "a chest taken out of the bag brings its things")
	var spread := Inventory.new(4)
	spread.slots = [["resources:fiber", 3], ["resources:stone", 2], ["resources:fiber", 4], null]
	var into := Inventory.new(4)
	_check(spread.move_all(into, 1) == 6 and spread.slots[0] == ["resources:fiber", 3] and spread.slots[1] == null
		and into.count("resources:fiber") == 4 and into.count("resources:stone") == 2, "«all into the chest» leaves the first slots be")


func _test_wear() -> void:
	var inv := Inventory.new(4)
	var d: int = Items.get_item("tools:stone_axe").durability
	_check(d > 0 and Items.get_item("tools:stone_axe").repair.has("resources:flint"), "tools wear and are repaired with materials")
	inv.add("tools:stone_axe", 1)
	for i in d - 1:
		inv.wear_tool("tools:stone_axe", d)
	_check(inv.worn(0) == d - 1 and inv.count("tools:stone_axe") == 1, "a tool wears with each swing")
	var copy := Inventory.new(4)
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(copy.worn(0) == d - 1, "wear survives a save")
	var chest := Inventory.new(4)
	_check(copy.move_slot(0, chest) == 1 and chest.worn(0) == d - 1, "a worn tool keeps its wear in the chest")
	inv.add("tools:stone_axe", 1)
	_check(inv.slots[1] != null and inv.worn(1) == 0, "a new tool does not join a worn one")
	_check(inv.wear_tool("tools:stone_axe", d) and inv.count("tools:stone_axe") == 1, "a worn-out tool breaks")
	inv.wear_tool("tools:stone_axe", d)
	var at := inv.slots.find(inv.slots.filter(func(x) -> bool: return x != null)[0])
	inv.mend(at)
	_check(inv.worn(at) == 0, "a repaired tool is as good as new")


## Bags worn on the back: more slots, taken off with what they hold, swapped, saved.
func _test_gear() -> void:
	var inv := Inventory.new()
	_check(Items.wear_on("tools:wicker_bag") == "back" and Items.bag_slots("tools:wicker_bag") == 8
		and Items.bag_slots("tools:leather_bag") == 16 and Items.bag_slots("tools:canvas_backpack") == 24,
		"the bags add 8, 16 and 24 slots")
	_check(Items.category("tools:wicker_bag") == "gear", "a thing worn is of its own kind")
	inv.add("tools:wicker_bag", 1)
	_check(inv.wear(1) == "empty" and inv.wear(0) == "" and inv.slots.size() == Inventory.SLOTS + 8
		and inv.gear.back == "tools:wicker_bag" and inv.slots[0] == ["tools:wicker_bag", 1] and inv.worn_on(0) == "back",
		"a bag put on adds its slots and stays in its own")
	_check(is_equal_approx(inv.weight(), Items.weight("tools:wicker_bag")), "what is worn weighs once")
	inv.slots[Inventory.SLOTS + 2] = ["resources:fiber", 5]
	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(copy.slots.size() == Inventory.SLOTS + 8 and copy.gear.back == "tools:wicker_bag" and copy.worn_slot("back") == 0
		and copy.slots[Inventory.SLOTS + 2] == ["resources:fiber", 5], "the bag worn and its slots survive a save")
	inv.add("tools:leather_bag", 1)
	_check(inv.wear(1) == "" and inv.slots.size() == Inventory.SLOTS + 16 and inv.gear.back == "tools:leather_bag"
		and inv.slots[0][0] == "tools:wicker_bag" and inv.contents(0) != null and inv.count("resources:fiber") == 0
		and inv.worn_slot("back") == 1, "a new bag goes on in place of the old, which keeps what its slots held")
	inv.slots[Inventory.SLOTS + 15] = ["tools:wicker_bag", 1]
	_check(inv.wear(Inventory.SLOTS + 15) == "inside", "a bag is not put on from its own slots")
	_check(not inv.put_into(1, inv, Inventory.SLOTS + 3) and inv.worn_slot("back") == 1, "the bag worn does not go into its own slots")
	inv.slots[Inventory.SLOTS + 15] = null
	_check(inv.wear(0) == "" and inv.gear.back == "tools:wicker_bag" and inv.slots[Inventory.SLOTS + 2] == ["resources:fiber", 5]
		and inv.slots.size() == Inventory.SLOTS + 8, "a bag put on again brings back what it held")
	_check(inv.take_off("back") == "" and inv.slots.size() == Inventory.SLOTS and not inv.gear.has("back")
		and inv.slots[1] == ["tools:leather_bag", 1] and inv.contents(0) != null and inv.count("resources:fiber") == 0,
		"a bag taken off stays where it lies and takes its things with it")
	# A backpack worn holding a bag that holds things: taken off, all of it weighs as before.
	var pack := Inventory.new()
	pack.add("tools:canvas_backpack", 1)
	pack.wear(0)
	pack.slots[Inventory.SLOTS + 3] = ["tools:wicker_bag", 1, 0, {"slots": [["resources:stone", 3], ["resources:fiber", 2]]}]
	var kg := pack.weight()
	_check(pack.take_off("back") == "" and pack.contents(0) != null and is_equal_approx(pack.weight(), kg)
		and kg > Items.weight("tools:canvas_backpack") + 3.0 * Items.weight("resources:stone"),
		"a bag taken off weighs as it did worn, with a bag in it and what that holds: %.2f, %.2f" % [kg, pack.weight()])
	inv.wear(1)
	inv.slots[Inventory.SLOTS + 4] = ["resources:stone", 2]
	var chest := Inventory.new(4)
	_check(inv.move_slot(1, chest) == 1 and not inv.gear.has("back") and inv.slots.size() == Inventory.SLOTS
		and chest.contents(0) != null and inv.count("resources:stone") == 0, "a bag worn put away comes off with its things")
	var full := Inventory.new(1)
	full.gear = {"back": "tools:wicker_bag"}
	full.slots[0] = ["resources:stone", 1]
	_check(full.apart() == ["back"] and full.take_off("back") == "full" and full.gear.has("back"),
		"a bag of an old save worn apart is not taken off with no free slot for it")
	var old := Inventory.new()
	old.from_dict({"slots": [["resources:stone", 1]], "gear": {"body": "tools:grass_cape"}})
	_check(old.slots[1] == ["tools:grass_cape", 1] and old.worn_on(1) == "body" and old.apart().is_empty(),
		"a thing an old save wore apart goes back into the bag, worn")
	_check(old.take_slot(1, 1) != null and not old.gear.has("body"), "a thing worn comes off when it leaves the bag")
	old.add("tools:grass_cape", 1)
	old.wear(1)
	old.sort("weight")
	var cape: int = old.worn_slot("body")
	_check(cape >= 0 and old.slots[cape] == ["tools:grass_cape", 1] and old.take_off("body") == "" and old.slots[cape] == ["tools:grass_cape", 1],
		"sorting moves what is worn too, still worn; taken off, it stays where it lies")
	var w := Survivor.new()
	w.inventory.add("tools:canvas_backpack", 1)
	w.inventory.add("tools:grass_cape", 1)
	_check(w.wear(0) and w.wear(1) and w.inventory.slots.size() == Inventory.SLOTS + 24, "the character puts a backpack and a cape on")
	w.inventory.slots[30] = ["resources:fiber", 3]
	w.inventory.slots[5] = ["resources:stone", 3]
	var lost := w.inventory.take_all()
	_check(w.inventory.gear.back == "tools:canvas_backpack" and w.inventory.gear.body == "tools:grass_cape"
		and lost.size() == 2 and w.inventory.count("resources:stone") == 0 and w.inventory.count("tools:grass_cape") == 1,
		"what is worn stays on through a death")


func _test_torch() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var ch := Survivor.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.at = Vector3(4.5, 1.0, 5.5) * WorldData.CELL
	# Torches burn for longer than a body lasts without water.
	ch.vitals.thirst = false
	var d := Items.burns("tools:torch")
	_check(Items.get_item("tools:torch").light > 0.0 and d > 0.0 and Items.get_item("tools:torch").durability == 0,
		"a torch gives light and burns for a while, it does not wear")
	_check(Items.category("tools:torch") == "light", "a torch is a light in the bag, not a tool")
	ch.give("tools:torch", 1)
	_check(ch.light_held() == "", "a torch in the bag gives no light")
	ch.hands = ["tools:torch", "tools:torch"]
	_check(ch.lights_held().size() == 1, "one torch in both hands lights once")
	ch.hands = ["tools:torch", ""]
	_check(ch.light_held() == "tools:torch", "a torch in either hand does")
	for i in 30:
		ch.update(0.5)
	_check(is_equal_approx(ch.burning["tools:torch"][0], 15.0) and ch.inventory.slots[0] == ["tools:torch", 1],
		"it burns while held, the bag keeps it whole")
	ch.body.swimming = true
	ch.update(5.0)
	_check(ch.light_held() == "tools:torch" and is_equal_approx(ch.burning["tools:torch"][0], 20.0),
		"in water it is held up and keeps burning")
	ch.body.swimming = false
	ch.hands = ["", ""]
	ch.update(5.0)
	_check(is_equal_approx(ch.burning["tools:torch"][0], 20.0), "put away, it waits with what it has burned")
	var saved := ch.to_dict()
	var copy := Survivor.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(is_equal_approx(copy.burning.get("tools:torch", [0.0])[0], 20.0) and is_equal_approx(copy.burn_left("tools:torch"), 1.0 - 20.0 / d),
		"what has burned is kept in the save")
	ch.give("tools:torch", 1)
	ch.hands = ["tools:torch", "tools:torch"]
	ch.update(1.0)
	_check(ch.lights_held().size() == 2 and is_equal_approx(ch.burning["tools:torch"][0], 21.0)
		and is_equal_approx(ch.burning["tools:torch"][1], 1.0) and ch.inventory.slots[0] == ["tools:torch", 2],
		"two torches, one in each hand, both burn, and they stack")
	ch.hands = ["tools:torch", ""]
	for i in ceili(d):
		ch.update(1.0)
	_check(ch.inventory.count("tools:torch") == 1, "burned out, one of the stack is gone")
	_check(ch.burning["tools:torch"].size() == 1 and ch.burning["tools:torch"][0] < 25.0, "and the next one is lit")
	ch.inventory.remove("tools:torch", 1)
	ch.update(1.0)
	_check(not ch.burning.has("tools:torch"), "thrown away, its burning goes with it")
	var bag := Inventory.new(4)
	bag.add("tools:torch", 5)
	_check(bag.slots[0] == ["tools:torch", 5], "torches stack by five")
	bag.add("tools:torch", 1, 40)
	_check(bag.slots[0] == ["tools:torch", 5] and bag.slots[1] == ["tools:torch", 1], "one burned by wear in an old save comes back whole")


func _test_warmth() -> void:
	const Warmth := preload("res://src/shared/game/warmth.gd")
	var v := Vitals.new()
	v.warm(1.0, 18.0)
	_check(is_equal_approx(v.warmth, Vitals.COMFORT), "mild air keeps the body comfortable")
	v.warm(1.0, -5.0)
	_check(v.warmth < Vitals.COLD and v.health < Vitals.MAX and v.hurt_by == "cold", "a freezing night chills and then hurts")
	_check(v.stamina_cap() < Vitals.MAX, "the cold lowers stamina")
	var hp := v.health
	v.step(0.0, 0.5, false)
	_check(v.health <= hp, "a cold body does not heal")
	v.warm(1.0, 20.0)
	_check(v.warmth > Vitals.COLD, "warmth comes back by a fire")
	v.warm(1.0, 40.0)
	_check(v.warmth > Vitals.HOT and v.stamina_cap() <= Vitals.HOT_CAP, "heat tires")
	var off := Vitals.new()
	off.cold = false
	off.warm(1.0, -30.0)
	_check(off.warmth == Vitals.COMFORT and off.health == Vitals.MAX, "with the cold off the body feels nothing")
	var w := Vitals.new()
	w.warm(0.1, 15.0, 1.0)
	_check(w.wet > 0.5, "rain wets")
	w.warm(0.0, 15.0, 0.0, 0.0, true)
	_check(w.wet == 1.0, "swimming soaks")
	var by_fire := Vitals.new()
	by_fire.wet = 1.0
	w.warm(0.05, 15.0)
	by_fire.warm(0.05, 30.0, 0.0, 0.0, false, false, 20.0)
	_check(by_fire.wet < w.wet, "a fire dries faster than the air")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	_check(is_equal_approx(copy.warmth, v.warmth), "warmth survives a save")
	_check(Warmth.feel(0.0, 0.0, 10.0, 0.0, false, false) > Warmth.feel(0.0, 0.0, 10.0, 1.0, false, false),
		"wet clothes warm less")
	_check(Warmth.feel(0.0, 20.0, 0.0, 0.0, false, false) == 20.0, "a fire warms")
	_check(Warmth.feel(30.0, 20.0, 10.0, 0.0, false, true) < 30.0, "water chills a swimmer")
	_check(Warmth.clothes({"head": "tools:fiber_hat", "body": "tools:grass_cape"}) == 7.0, "clothes add their warmth")
	var summer := Clock.new()
	var winter := Clock.new()
	winter.season = Clock.WINTER
	_check(Warmth.air(null, winter, Vector3.ZERO) < Warmth.air(null, summer, Vector3.ZERO), "winter is colder")


## Good food (roasted meat) heals a little and quenches thirst besides filling; the
## fullness of bags and chests in the bag.
func _test_good_food() -> void:
	var w := Survivor.new()
	w.vitals.satiety = 20.0
	w.vitals.water = 20.0
	w.vitals.health = 50.0
	w.inventory.add("animals:roasted_meat", 1)
	_check(w.eat(0) and w.vitals.satiety > 20.0 and w.vitals.water > 20.0 and w.vitals.health > 50.0,
		"roasted meat fills, heals and quenches thirst")
	var inv := Inventory.new()
	inv.add("tools:wicker_bag", 1)
	inv.add("resources:stone", 1)
	_check(inv.fullness(1) < 0.0 and inv.fullness(0) == 0.0, "a bag shows how full it is, a stone does not")
	inv.wear(0)
	inv.slots[Inventory.SLOTS + 1] = ["resources:fiber", 2]
	inv.slots[Inventory.SLOTS + 5] = ["resources:fiber", 2]
	_check(is_equal_approx(inv.fullness(0), 2.0 / 8.0), "the bag worn: its slots taken")
	inv.take_off("back")
	_check(is_equal_approx(inv.fullness(0), 2.0 / 8.0), "taken off, what it holds")


func _test_thirst() -> void:
	var v := Vitals.new()
	v.water = 30.0
	v.step(0.0, 20.0 / Vitals.THIRST_PER_DAY, false)
	_check(is_equal_approx(v.water, 10.0) and v.stamina_cap() < Vitals.MAX, "thirst empties water and tires")
	var hp := v.health
	v.step(0.0, 0.5, false)
	_check(v.water == 0.0 and v.health < hp and v.hurt_by == "thirst", "with no water health goes down")
	_check(v.drink(40.0) and v.water == 40.0, "a drink fills water")
	v.water = Vitals.MAX
	_check(not v.drink(10.0), "a full body does not drink")
	var off := Vitals.new()
	off.thirst = false
	off.step(0.0, 3.0, false)
	_check(off.water == 80.0, "with thirst off water stays")
	var hot := Vitals.new()
	var mild := Vitals.new()
	hot.warmth = Vitals.HOT + 5.0
	hot.step(0.0, 0.1, false)
	mild.step(0.0, 0.1, false)
	_check(hot.water < mild.water, "heat makes thirstier")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	_check(copy.water == Vitals.MAX, "water survives a save")
	var w := Survivor.new()
	w.vitals.water = 20.0
	w.give("tools:waterskin_full", 1)
	var at := w.inventory.slots.find_custom(func(st) -> bool: return st != null and st[0] == "tools:waterskin_full")
	_check(w.eat(at) and w.vitals.water == 80.0 and w.inventory.count("tools:waterskin") == 1 and w.inventory.count("tools:waterskin_full") == 0,
		"a full waterskin is drunk and becomes empty")
	_check(Tools.use_of("tools:waterskin_full") == "eat" and Items.get_item("tools:waterskin").fills_to == "tools:waterskin_full",
		"a full waterskin is drunk from the hand, an empty one is filled")


func _test_sleep() -> void:
	var v := Vitals.new()
	v.thirst = false
	v.hunger = false
	v.energy = 30.0
	v.step(0.0, 10.0 / Vitals.TIRE_PER_DAY, false)
	_check(is_equal_approx(v.energy, 20.0) and v.stamina_cap() < Vitals.MAX, "awake the body tires and sleepiness lowers stamina")
	_check(v.sleep(true) == "" and v.asleep, "a sleepy body lies down")
	v.step(0.0, 0.1, false)
	_check(is_equal_approx(v.energy, 20.0 + Vitals.SLEEP_GAIN * 0.1), "asleep, energy comes back")
	v.sleep_rate = 2.0
	v.step(0.0, 0.1, false)
	_check(is_equal_approx(v.energy, 20.0 + Vitals.SLEEP_GAIN * 0.3), "bedding rests faster")
	v.sleep(false)
	v.energy = Vitals.MAX
	_check(v.sleep(true) == "rested" and not v.asleep, "a rested body does not sleep")
	v.energy = 0.0
	_check(v.speed_factor() < 1.0, "with no energy the body walks slowly")
	var off := Vitals.new()
	off.fatigue = false
	off.thirst = false
	off.step(0.0, 3.0, false)
	_check(off.energy == 80.0, "with fatigue off energy stays")
	var swimmer := Vitals.new()
	swimmer.fatigue = false
	var health_was := swimmer.health
	var stamina_was := swimmer.stamina
	swimmer.step(600.0, 0.0, true)
	_check(swimmer.stamina == stamina_was and swimmer.health == health_was, "with fatigue off a swimmer neither tires nor drowns")
	_check(swimmer.spend("dig") and swimmer.stamina == stamina_was, "with fatigue off work costs no stamina")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	_check(copy.energy == 0.0, "energy survives a save")
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var ch := Survivor.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.at = Vector3(4.5, 1.0, 5.5) * WorldData.CELL
	var plain := ch.sleep_rate(ch.at)
	ch.give("tools:fur_bedroll", 1)
	_check(is_equal_approx(ch.sleep_rate(ch.at), plain), "bedding in the bag does not count")
	var beds := Placed.new()
	beds.world = w
	beds.read_footprints()
	ch.placed = beds
	var bed: Dictionary = beds.put("tools:fur_bedroll", Vector3i(8, 1, 8))
	_check(Placed.is_bed(bed) and not Placed.is_bed(beds.put("tools:workbench", Vector3i(12, 1, 12))), "a bedroll set down is a bed")
	ch.vitals.energy = Vitals.MAX
	_check(not ch.lie_in(bed) and ch.back_at == Vector3.ZERO and not ch.vitals.asleep and beds.things.has(bed),
		"a rested body does not lie down, and the bed stays (taken up in the build mode)")
	ch.vitals.energy = 10.0
	_check(ch.lie_in(bed) and ch.vitals.asleep, "a sleepy body lies down in the bed")
	var spot := beds.lying_spot(bed)
	_check(ch.back_at == spot and spot.y > 1.0 * WorldData.CELL and spot.y < 1.5 * WorldData.CELL
		and is_equal_approx(spot.x, 9.0 * WorldData.CELL), "the body is put on top of the bed's middle")
	_check(is_equal_approx(ch.sleep_rate(spot), plain * 2.0) and beds.bed_under(ch.at).is_empty(),
		"lying in the bed rests by its bedding, not beside it")
	ch.vitals.sleep(false)
	ch.back_at = Vector3.ZERO
	ch.at = Vector3(4.5, 1.0, 5.5) * WorldData.CELL
	_check(ch.sleep(true) and ch.vitals.asleep and ch.back_at == spot, "the sleep button takes the body to a bed near")
	ch.vitals.sleep(false)
	ch.back_at = Vector3.ZERO
	ch.at = Vector3(0.5, 1.0, 0.5) * WorldData.CELL
	_check(ch.sleep(true) and ch.vitals.asleep and ch.back_at == Vector3.ZERO,
		"a bed further than %d cells is left: the body sleeps where it is" % Survivor.BED_REACH)
	ch.vitals.sleep(false)
	ch.at = spot
	ch.vitals.energy = Vitals.MAX - 1.0
	ch.vitals.asleep = true
	ch.clock.time_of_day = 0.5
	ch.update(1.0)
	_check(not ch.vitals.asleep, "rested by day, the body wakes")
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	s.players = [ch]
	_check(s.sleep_speed() == 1.0, "awake players keep time")
	ch.vitals.asleep = true
	_check(s.sleep_speed() == Session.SLEEP_SPEED, "with everyone asleep the night goes by fast")


func _test_vitals() -> void:
	var v := Vitals.new()
	v.thirst = false
	v.satiety = 30.0
	v.step(0.0, 20.0 / Vitals.HUNGER_PER_DAY, false)
	_check(is_equal_approx(v.satiety, 10.0) and v.health == Vitals.MAX, "hunger empties satiety over game days")
	v.hunger = false
	v.step(0.0, 5.0, false)
	_check(is_equal_approx(v.satiety, 10.0), "with hunger off satiety stays")
	v.hunger = true
	v.step(0.0, 0.5, false)
	_check(v.health < Vitals.MAX and v.hurt_by == "hunger", "only starving hurts")
	_check(v.stamina_cap() < Vitals.MAX, "hunger lowers stamina")
	_check(v.eat(40.0) and v.satiety == 40.0, "food fills satiety")
	v.satiety = Vitals.MAX
	_check(not v.eat(5.0), "a full character does not eat")
	v.health = 50.0
	_check(v.heal(Items.heal("plants:bandage")) and v.health > 50.0 and Tools.use_of("plants:bandage") == "heal", "a bandage heals")
	v.health = Vitals.MAX
	_check(not v.heal(10.0), "a bandage is not used up on a healthy body")
	v.health = 60.0
	var h := v.health
	v.step(0.0, 0.2, false)
	_check(v.health > h, "a well fed body heals")
	v.stamina = 2.0
	_check(not v.spend("chop") and v.stamina == 2.0, "a tired body cannot chop a tree")
	v.step(1.0, 0.0, false)
	_check(v.stamina > 2.0 and v.speed_factor() < 1.0 or v.stamina >= Vitals.TIRED, "stamina comes back at rest")
	v.stamina = 0.0
	h = v.health
	v.step(1.0, 0.0, true)
	_check(v.health < h and v.hurt_by == "water", "a swimmer out of breath loses health")
	v.health = 0.0
	_check(v.is_dead(), "no health is death")
	v.revive(0.5)
	_check(v.health == Vitals.MAX * 0.5 and v.stamina == Vitals.MAX, "a revived body starts afresh")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	_check(copy.health == v.health and copy.satiety == v.satiety, "the body survives a save as JSON")


## «Что нового» shows when each change was merged, in the device's time zone.
func _test_changes() -> void:
	var menu: GDScript = load("res://src/client/ui/settings_menu.gd")
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var shown: String = menu.merged_at({"merged": "2026-10-23T18:32:05Z", "date": "2026-10-23"})
	var want := Time.get_datetime_string_from_unix_time(
		Time.get_unix_time_from_datetime_string("2026-10-23T18:32:05") + bias * 60, true).left(16)
	_check(shown == want and shown.length() == 16, "a change shows the date and time it was merged")
	_check(menu.merged_at({"date": "2026-10-22"}) == "2026-10-22", "an older build shows the date alone")
	# The page makes its changes a step at a time as it is scrolled, not all 500 at once.
	var page: Control = menu.new(null)
	page._ready()
	var many := []
	for i in 2 * menu.CHANGES_STEP + 5:
		many.append({"pr": 500 - i / 3, "date": "2026-11-04", "kind": "new", "text": "change %d" % i})
	page.page = "changes"
	page._add_changes(many)
	var made := func() -> int: return page._list.get_children().filter(func(c: Node) -> bool: return c is HBoxContainer).size()
	_check(made.call() == menu.CHANGES_STEP and page._changes_left.size() == menu.CHANGES_STEP + 5,
		"the changes page makes the first step of changes")
	page._more_changes()
	page._more_changes()
	_check(made.call() == many.size() and page._changes_left.is_empty(), "scrolling makes the rest, a step at a time")
	page.free()


## A character dies without the client: the bag goes into a sack on the ground where
## they fell, the death is kept in the save, and they come back with half their health.
func _test_death() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var ch := Survivor.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.at = Vector3(4.5, 1.0, 5.5) * WorldData.CELL
	ch.update(0.1)
	ch.clock.time_of_day += 0.25
	ch.at = Vector3(5.5, 1.0, 5.5) * WorldData.CELL
	ch.update(0.1)
	ch.give("resources:branch", 3)
	_check(ch.act("dig") and ch.act("dig"), "the character digs twice")
	ch.vitals.satiety = 0.0
	ch.vitals.health = 0.0
	ch.update(0.1)
	var sack: Array = []
	for d: Array in w.drops.get(WorldData.chunk_key(5, 5), []):
		if d[0] == Items.SACK:
			sack = d
	_check(ch.is_dead() and ch.inventory.count("resources:branch") == 0 and not sack.is_empty()
		and ch.death.lost == [["resources:branch", 3]] and ch.death.cause == "hunger", "a death leaves the bag in a sack where they fell")
	_check(ch.sacks.size() == 1 and ch.sacks[0].is_equal_approx(sack[1]), "the character knows where the sack lies (the maps mark it)")
	WorldActions.new(w, ch.clock, Rules.new()).pick_up_near(ch)
	_check(ch.inventory.is_empty() and w.drops.get(WorldData.chunk_key(5, 5), []).has(sack),
		"the dead do not take their sack back by themselves")
	var again := Survivor.new()
	again.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())))
	_check(ch.fell_at.is_equal_approx(Vector3(5.5, 1.0, 5.5) * WorldData.CELL) and again.fell_at.is_equal_approx(ch.fell_at),
		"the place of the last death is kept, in the save too")
	_check(again.is_dead() and again.death.lost == [["resources:branch", 3]] and again.sacks.size() == 1
		and again.sacks[0].is_equal_approx(sack[1]), "the death and the sack's place are kept in the save")
	var lived: Dictionary = ch.death.life
	_check(is_equal_approx(lived.walked, WorldData.CELL) and lived.dug == 2.0 and lived.got == 3.0
		and absf(lived.days - 0.25) < 0.01 and ch.death.deaths == 1, "the death screen knows what the life did")
	_check(again.death.life.dug == 2.0 and again.deaths == 1 and absf(again.best_days - 0.25) < 0.01,
		"and the statistics are kept in the save")
	ch.revive(Vector3(2.5, 1.0, 2.5) * WorldData.CELL)
	_check(not ch.is_dead() and is_equal_approx(ch.vitals.health, Vitals.MAX * Survivor.REVIVE_HEALTH) and ch.back_at.x > 0.0,
		"and they come back with half their health at the respawn point")
	_check(ch.life.is_empty() and ch.deaths == 1, "a new life counts from nothing")
	_check(ch.fell_at.is_finite(), "and the place of the last death is not forgotten")
	ch.at = sack[1]
	WorldActions.new(w, ch.clock, Rules.new()).pick_up_near(ch)
	_check(ch.inventory.count("resources:branch") == 3 and ch.sacks.is_empty(), "the sack taken back is no longer marked")
	# What lies at the feet flies into the bag only as far as the weight limit goes, so
	# digging with the button held does not leave the body too heavy to jump.
	ch.at = ch.back_at
	var heap := Vector3(ch.at.x, 1.0 * WorldData.CELL, ch.at.z)
	w.heap_drop("resources:stone", heap, 30, 0.0)
	WorldActions.new(w, ch.clock, Rules.new()).pick_up_near(ch)
	var left := 0
	for d: Array in w.drops.get(WorldData.chunk_key(floori(heap.x / WorldData.CELL), floori(heap.z / WorldData.CELL)), []):
		left += WorldActions.count(d) if d[0] == "resources:stone" else 0
	_check(ch.inventory.count("resources:stone") > 0 and not ch.inventory.overloaded() and left > 0
		and ch.inventory.count("resources:stone") + left == 30, "things are taken up by themselves only up to the weight limit")
	WorldActions.new(w, ch.clock, Rules.new()).pick_up_near(ch, WorldActions.PICKUP_ALL, true)
	_check(ch.inventory.count("resources:stone") == 30 and ch.inventory.overloaded(), "or past it when the setting says so")
	ch.inventory.take_all()
	var spot := Vector3(ch.at.x, 1.0 * WorldData.CELL, ch.at.z)
	var food := ""
	for id: String in Items.IDS:
		if Items.food(id) > 0.0 and food == "":
			food = id
	w.heap_drop("core:stick", spot, 2, 0.0)
	w.heap_drop("resources:branch", spot, 2, 0.0)
	w.heap_drop(food, spot, 1, 0.0)
	ch.inventory.add("resources:branch", 1)
	var acts := WorldActions.new(w, ch.clock, Rules.new())
	acts.pick_up_near(ch, WorldActions.PICKUP_NONE)
	_check(ch.inventory.count("resources:branch") == 1 and ch.inventory.count(food) == 0, "pickup «ничего» takes nothing")
	acts.pick_up_near(ch, WorldActions.PICKUP_FOOD)
	_check(ch.inventory.count(food) == 1 and ch.inventory.count("resources:branch") == 1, "pickup «еду» takes only food")
	acts.pick_up_near(ch, WorldActions.PICKUP_KNOWN)
	_check(ch.inventory.count("resources:branch") == 3 and ch.inventory.count("core:stick") == 0,
		"pickup «что есть» takes only what the bag already has")
	acts.pick_up_near(ch, WorldActions.PICKUP_ALL)
	_check(ch.inventory.count("core:stick") == 2, "pickup «всё» takes the rest")


## Food spoils with game time, stacks of it join at their age together, cold and a roof
## slow it, and what has gone off turns into rot; a tool's wear is not freshness.
func _test_spoil() -> void:
	var meat := "animals:raw_meat"
	var days := Items.spoils(meat)
	_check(days > 0.0 and Items.rots_to(meat) == "core:rot", "raw meat spoils into rot")
	var inv := Inventory.new()
	inv.add(meat, 2)
	_check(inv.freshness(0) == 1.0 and inv.freshness(1) == -1.0, "fresh meat is fresh; an empty slot is no food")
	inv.spoil(days * 0.5)
	_check(absf(inv.freshness(0) - 0.5) < 0.01 and inv.worn(0) == 0, "half its days later it is half fresh, and not worn")
	inv.add(meat, 2)
	_check(inv.slots[0][1] == 4 and absf(inv.freshness(0) - 0.75) < 0.01, "fresh meat joins the stack at the age of both")
	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(absf(copy.freshness(0) - 0.75) < 0.01, "how fresh it is is saved")
	var cold := Inventory.new()
	cold.add(meat, 1)
	cold.spoil(days * 0.5, Inventory.spoil_rate(true, true))
	_check(absf(cold.freshness(0) - 1.0 + 0.5 * Inventory.WINTER_RATE * Inventory.ROOF_RATE) < 0.01,
		"in a winter cellar it keeps much longer")
	inv.add("tools:stone_axe", 1)
	inv.spoil(days)
	_check(inv.count(meat) == 0 and inv.count("core:rot") == 4 and inv.count("tools:stone_axe") == 1,
		"gone off, the meat is rot; the axe is untouched")
	var tiny := Inventory.new()
	tiny.add(meat, 1)
	_check(not tiny.spoil(Inventory.SPOIL_STEP * 0.5) and tiny.freshness(0) == 1.0, "a moment is gathered, not put on at once")


## A fall past Vitals.FALL_SAFE levels hurts by its height from the ground last stood on,
## a jump does not add to it, deep water takes it all and shallow water half, and a
## teleport or a new life starts the count again.
func _test_fall() -> void:
	var w := WorldData.new(16, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	for y in range(1, 9):
		w.set_cell(2, y, 2, Mat.STONE)
	w.set_cell(12, 1, 12, Mat.WATER)
	for y in range(1, 3):
		w.set_cell(12, y, 2, Mat.WATER)
	var ch := Survivor.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.body.world = w
	var drop := func(from: Vector3, to: Vector3) -> float:
		ch.vitals.health = Vitals.MAX
		ch.forget_fall()
		ch.at = from * WorldData.CELL
		ch.update(0.05)
		# Off the edge and over in short steps, then down a level a step, as a body
		# falls (not a teleport).
		var over := Vector3(to.x, from.y, to.z)
		for k in range(1, 21):
			ch.at = from.lerp(over, k / 20.0) * WorldData.CELL
			ch.update(0.05)
		var y := from.y
		while y > to.y:
			y = maxf(to.y, y - 1.0)
			ch.at = Vector3(to.x, y, to.z) * WorldData.CELL
			ch.update(0.05)
		ch.update(0.05)
		return Vitals.MAX - ch.vitals.health
	_check(drop.call(Vector3(2.5, 5.0, 2.5), Vector3(4.5, 1.0, 4.5)) == 0.0, "a fall of 4 levels does not hurt")
	var hurt: float = drop.call(Vector3(2.5, 9.0, 2.5), Vector3(4.5, 1.0, 4.5))
	_check(absf(hurt - (8.0 - Vitals.FALL_SAFE) * Vitals.FALL_PER_LEVEL) < 0.5 and ch.vitals.hurt_by == "fall",
		"a fall of 8 levels hurts for the 4 past the safe 4 (%.0f)" % hurt)
	_check(drop.call(Vector3(2.5, 9.0, 2.5), Vector3(12.5, 1.0, 2.5)) == 0.0, "deep water takes the whole fall")
	var soft: float = drop.call(Vector3(2.5, 9.0, 2.5), Vector3(12.5, 1.0, 12.5))
	_check(absf(soft - hurt * 0.5) < 0.5, "shallow water takes half of it (%.0f)" % soft)
	ch.vitals.health = Vitals.MAX
	ch.forget_fall()
	ch.at = Vector3(2.5, 9.0, 2.5) * WorldData.CELL
	ch.update(0.05)
	ch.at = Vector3(4.5, 1.0, 4.5) * WorldData.CELL
	ch.update(0.05)
	_check(ch.vitals.health == Vitals.MAX, "a teleport down is no fall")
	ch.at = Vector3(4.5, 1.0, 4.5) * WorldData.CELL
	ch.update(0.05)
	ch.at = Vector3(4.5, 2.4, 4.5) * WorldData.CELL
	ch.update(0.05)
	ch.at = Vector3(4.5, 1.0, 4.5) * WorldData.CELL
	ch.update(0.05)
	_check(ch.vitals.health == Vitals.MAX, "a jump on flat ground is no fall")
	ch.vitals.health = 10.0
	ch.forget_fall()
	ch.at = Vector3(2.5, 9.0, 2.5) * WorldData.CELL
	ch.update(0.05)
	for y in range(8, 0, -1):
		ch.at = Vector3(4.5, float(y), 4.5) * WorldData.CELL
		ch.update(0.05)
	_check(ch.is_dead() and ch.death.cause == "fall" and Survivor.cause_text("fall")[0] == "Вы разбились",
		"a long fall kills, and the death screen says so")


## A death's sack lies Character.SACK_DAYS game days and is then gone from the ground
## and from the maps; its day is kept in the save and stays when part of it is taken.
func _test_sack_ends() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var ch := Survivor.new()
	ch.world = w
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.at = Vector3(5.5, 1.0, 5.5) * WorldData.CELL
	ch.give("resources:branch", 3)
	ch.vitals.satiety = 0.0
	ch.vitals.health = 0.0
	ch.update(0.1)
	var key := WorldData.chunk_key(5, 5)
	var sack: Array = w.drops[key][0]
	var start: float = ch.clock.now()
	_check(sack[0] == Items.SACK and sack.size() == 6 and is_equal_approx(sack[4], start + Survivor.SACK_DAYS)
		and ch.sack_ends.size() == 1, "a death's sack knows the day it is gone")
	_check(sack[5] is Dictionary and sack[5].name == "" and sack[5].cause == ch.death.cause and sack[5].day == ch.death.day,
		"and who died there, for the cross (%s)" % [sack[5]])
	_check(ch.death.sack_days == Survivor.SACK_DAYS, "the death screen is told how long it lies")
	var again := Survivor.new()
	again.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())))
	_check(again.sack_ends.size() == 1 and is_equal_approx(again.sack_ends[0], ch.sack_ends[0]), "the day is kept in the save")
	var old := Survivor.new()
	old.from_dict({"sacks": [[1.0, 2.0, 3.0]]})
	_check(old.sacks.size() == 1 and old.sack_ends == [INF], "a sack of an old save stays")
	var acts := WorldActions.new(w, ch.clock, Rules.new())
	acts.expire_sacks(start + 1.0, [ch])
	_check(w.drops.get(key, []).has(sack) and ch.sacks.size() == 1, "after a day the sack still lies")
	ch.revive(Vector3(5.5, 1.0, 5.5) * WorldData.CELL)
	for i in 40:
		if ch.inventory.room_for("resources:branch") == 0:
			break
		ch.inventory.add("resources:stone", 20)
	ch.inventory.add("resources:branch", Items.get_item("resources:branch").stack - 1)
	ch.at = sack[1]
	ch.said.clear()
	acts.pick_up_near(ch)
	var rest: Array = w.drops.get(key, [[""]])[0]
	_check(ch.sacks.size() == 1 and rest[0] == Items.SACK and rest.size() == 6 and rest[4] == sack[4] and rest[5] == sack[5],
		"a sack taken in part keeps its day and who died there")
	for i in 5:
		acts.pick_up_near(ch)
	_check(ch.said.is_empty(), "standing by a sack that does not fit the bag does not say so at every pickup (%s)" % [ch.said])
	_check(not acts.pick_up(ch, key, 0) and not acts.pick_up(ch, key, 0) and ch.said == ["Забрано не всё: сумка полна"],
		"a tap on it says so, but not twice in a row (%s)" % [ch.said])
	var changed := []
	acts.drops_changed.connect(func(k: Vector2i) -> void: changed.append(k))
	var gone: Array = acts.expire_sacks(start + Survivor.SACK_DAYS + 0.01, [ch])
	_check(w.drops.get(key, []).is_empty() and ch.sacks.is_empty() and ch.sack_ends.is_empty() and changed == [key],
		"after two days the sack is gone, and the maps forget it")
	_check(gone.size() == 1 and gone[0][0] == sack[1] and gone[0][1] == sack[5], "the world is told where it lay and who died there")
	var other := Survivor.new()
	other.clock = ch.clock
	other.sacks.append(Vector3.ONE)
	other.sack_ends.append(start)
	other.vitals.health = Vitals.MAX
	other.world = w
	other.body = Body.new()
	other._forget_old_sacks()
	_check(other.sacks.is_empty(), "a sack in a chunk not made is forgotten by the maps on its day too")


## Where a death's sack was once its days are up a cross stands (Placed.put_grave), in
## its cell or the nearest free one; it keeps who died there in the save and tells it
## (DeathScreen.grave_text); taken up in the build mode it is gone, the bag gets nothing.
func _test_graves() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var camp := Placed.new()
	camp.world = w
	camp.read_footprints()
	_check(Items.grave() != "", "core has a cross")
	var g := {"name": "Ёж\u202e", "cause": "cold", "day": 7, "days": 2.25, "life": {"walked": 3200.0, "trees": 14.0, "dug": 3.0, "jumps": 40.0}}
	var at := Vector3(5.5, 1.0, 5.5) * WorldData.CELL
	var e: Dictionary = camp.put_grave(at, g)
	_check(not e.is_empty() and e.cell == Vector3i(5, 1, 5) and Placed.is_grave(e) and not Placed.is_sign(e),
		"a cross stands in the sack's cell")
	_check(e.grave.name == "Ёж" and e.grave.day == 7 and e.grave.life.trees == 14.0, "it keeps who died, the name made safe (%s)" % [e.grave])
	var other: Dictionary = camp.put_grave(at, {})
	_check(not other.is_empty() and other.cell != e.cell and absi(other.cell.x - 5) <= 1 and absi(other.cell.z - 5) <= 1
		and other.cell.y == 1, "a second one stands beside it (%s)" % [other.get("cell")])
	var copy := Placed.new()
	copy.world = WorldData.new(8, Vector2i(16, 16))
	copy.read_footprints()
	copy.from_list(JSON.parse_string(JSON.stringify(camp.to_list())))
	_check(copy.at(e.cell).get("grave", {}).get("name") == "Ёж" and copy.at(other.cell).has("grave"), "the save keeps it")
	var text := DeathScreen.grave_text(e.grave)
	_check(text.contains("«Ёж»") and text.contains("холод") and text.contains("2 дн 6 ч") and text.contains("пройдено 3")
		and text.contains("прыгнули") and text.contains("срублено") and not text.contains("выкопано"),
		"it tells who, why, how long, the way walked and the two largest counts (%s)" % text)
	_check(DeathScreen.grave_text(Placed.grave_record({})).begins_with("Здесь покоится путник"), "a cross of an old sack names no one")
	var ch := Survivor.new()
	ch.world = w
	ch.placed = camp
	_check(camp.take_up(ch, e) and camp.at(e.cell).is_empty() and ch.inventory.is_empty() and ch.said == ["Крест убран"],
		"taken up it is gone, nothing in the bag")
	var full := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			full.set_cell(x, 0, z, Mat.STONE)
			full.set_cell(x, 1, z, Mat.STONE)
			full.set_cell(x, 2, z, Mat.STONE)
	camp.world = full
	_check(camp.put_grave(at, g).is_empty(), "no cross where there is no room")
	camp.world = w
	var poor := Survivor.new()
	poor.world = w
	poor.placed = camp
	poor.clock = Clock.new()
	poor.body = Body.new()
	poor.at = Vector3(10.5, 1.0, 10.5) * WorldData.CELL
	poor.vitals.satiety = 0.0
	poor.vitals.health = 0.0
	poor.update(0.1)
	var crosses := camp.things.filter(func(t: Dictionary) -> bool: return Placed.is_grave(t))
	_check(poor.is_dead() and w.drops.get(WorldData.chunk_key(10, 10), []).is_empty() and crosses.size() == 2
		and crosses.any(func(t: Dictionary) -> bool: return absi(t.cell.x - 10) <= 1 and absi(t.cell.z - 10) <= 1),
		"a death with an empty bag leaves no sack but a cross at once")


## Coming back after death: at the last bed the character set down, lying in it, before
## their fire and the spawn's campfire; a bed of someone else is not theirs.
func _test_bed_respawn() -> void:
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
	var camp := Placed.new()
	camp.world = w
	camp.read_footprints()
	var ch := Survivor.new()
	ch.world = w
	ch.placed = camp
	ch.home = Vector3(1.0, 1.0, 1.0)
	camp.put("core:campfire", Vector3i(2, 1, 2), null, true, -1.0, 0)
	camp.put("tools:fur_bedroll", Vector3i(10, 1, 10), null, true, -1.0, 7)
	ch.find_respawns(camp, null)
	_check(ch.respawn_points()[0][0] == "У своего костра", "with no bed of their own they come back at their fire")
	var bed: Dictionary = camp.put("tools:fur_bedroll", Vector3i(8, 1, 8), null, true, -1.0, 0)
	_check(ch.find_respawns(camp, null) and ch.respawn_points()[0][0] == "У своей кровати"
		and ch.respawn_points()[0][1] == camp.lying_spot(bed) and ch.respawn_points()[1][0] == "У своего костра"
		and ch.respawn_points().back()[0] == "У костра старта", "their bed comes first, lying in it")


## A poultice gives its health back over its time, even hungry, one at a time; a bandage
## at once.
func _test_poultice() -> void:
	_check(Items.has("plants:poultice") and Items.heal_time("plants:poultice") > 0.0 and Items.heal_time("plants:bandage") == 0.0,
		"the poultice heals over time, the bandage at once")
	var ch := Survivor.new()
	ch.clock = Clock.new()
	ch.body = Body.new()
	ch.vitals.health = 20.0
	ch.vitals.satiety = 0.0
	ch.vitals.hunger = false
	ch.give("plants:poultice", 2)
	var slot := ch.inventory.slots.find(ch.inventory.slots.filter(func(s: Variant) -> bool: return s != null)[0])
	_check(ch.eat(slot) and ch.inventory.count("plants:poultice") == 1 and ch.vitals.health == 20.0,
		"a poultice put on does not heal at once")
	_check(not ch.eat(slot) and ch.inventory.count("plants:poultice") == 1, "a second waits for the first to finish")
	var heal := Items.heal("plants:poultice")
	var t := Items.heal_time("plants:poultice")
	ch.vitals.step(t * 0.5, 0.0, false)
	_check(absf(ch.vitals.health - (20.0 + heal * 0.5)) < 0.5, "half its time gives half its health back, hungry too")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(ch.vitals.to_dict())))
	_check(is_equal_approx(copy.mending, ch.vitals.mending), "what a poultice has left is kept in the save")
	ch.vitals.step(t, 0.0, false)
	_check(absf(ch.vitals.health - (20.0 + heal)) < 0.5 and ch.vitals.mending == 0.0, "and then it is done")
