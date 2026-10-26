extends "res://tests/unit/test_case.gd"
## The character: the bag, tool wear, vitals, the change log and death.


func run() -> void:
	_test_inventory()
	_test_wear()
	_test_torch()
	_test_vitals()
	_test_changes()
	_test_death()


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
	var d: int = Items.get_item("tools:torch").durability
	_check(Items.get_item("tools:torch").light > 0.0 and d > 0, "a torch gives light and burns for a while")
	ch.give("tools:torch", 1)
	_check(ch.light_held() == "", "a torch in the bag gives no light")
	ch.hands = ["tools:torch", "tools:torch"]
	_check(ch.lights_held().size() == 1, "one torch in both hands lights once")
	ch.hands = ["tools:torch", ""]
	_check(ch.light_held() == "tools:torch", "a torch in either hand does")
	for i in 30:
		ch.update(0.5)
	_check(ch.inventory.worn(0) == 15, "it burns down a unit a second while held")
	ch.body.swimming = true
	ch.update(5.0)
	_check(ch.light_held() == "tools:torch" and ch.inventory.worn(0) == 16, "in water it is held up and keeps burning")
	ch.body.swimming = false
	ch.give("tools:torch", 1)
	ch.hands = ["tools:torch", "tools:torch"]
	ch.update(1.0)
	_check(ch.lights_held().size() == 2 and ch.inventory.worn(0) == 17 and ch.inventory.worn(1) == 1,
		"two torches, one in each hand, both burn")
	ch.hands = ["tools:torch", ""]
	for i in d:
		ch.update(1.0)
	_check(ch.inventory.count("tools:torch") == 1, "burned out, it is gone")
	var bag := Inventory.new(4)
	bag.add("tools:torch", 5)
	_check(bag.slots[0] == ["tools:torch", 5], "torches stack by five")
	bag.wear_tool("tools:torch", d)
	_check(bag.slots[0] == ["tools:torch", 4] and bag.slots[1] == ["tools:torch", 1, 1], "a burning one lies apart from the new")
	bag.wear_tool("tools:torch", d)
	_check(bag.worn(1) == 2 and bag.slots[0][1] == 4, "and keeps burning first")
	bag.add("tools:torch", 1)
	_check(bag.slots[0][1] == 5, "a new one joins the new")


func _test_vitals() -> void:
	var v := Vitals.new()
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
	WorldActions.new(w, ch.clock, {"free_build": false}).pick_up_near(ch)
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
	WorldActions.new(w, ch.clock, {"free_build": false}).pick_up_near(ch)
	_check(ch.inventory.count("resources:branch") == 3 and ch.sacks.is_empty(), "the sack taken back is no longer marked")
	# What lies at the feet flies into the bag only as far as the weight limit goes, so
	# digging with the button held does not leave the body too heavy to jump.
	ch.at = ch.back_at
	var heap := Vector3(ch.at.x, 1.0 * WorldData.CELL, ch.at.z)
	w.heap_drop("resources:stone", heap, 30, 0.0)
	WorldActions.new(w, ch.clock, {"free_build": false}).pick_up_near(ch)
	var left := 0
	for d: Array in w.drops.get(WorldData.chunk_key(floori(heap.x / WorldData.CELL), floori(heap.z / WorldData.CELL)), []):
		left += WorldActions.count(d) if d[0] == "resources:stone" else 0
	_check(ch.inventory.count("resources:stone") > 0 and not ch.inventory.overloaded() and left > 0
		and ch.inventory.count("resources:stone") + left == 30, "things are taken up by themselves only up to the weight limit")
	WorldActions.new(w, ch.clock, {"free_build": false}).pick_up_near(ch, WorldActions.PICKUP_ALL, true)
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
	var acts := WorldActions.new(w, ch.clock, {"free_build": false})
	acts.pick_up_near(ch, WorldActions.PICKUP_NONE)
	_check(ch.inventory.count("resources:branch") == 1 and ch.inventory.count(food) == 0, "pickup «ничего» takes nothing")
	acts.pick_up_near(ch, WorldActions.PICKUP_FOOD)
	_check(ch.inventory.count(food) == 1 and ch.inventory.count("resources:branch") == 1, "pickup «еду» takes only food")
	acts.pick_up_near(ch, WorldActions.PICKUP_KNOWN)
	_check(ch.inventory.count("resources:branch") == 3 and ch.inventory.count("core:stick") == 0,
		"pickup «что есть» takes only what the bag already has")
	acts.pick_up_near(ch, WorldActions.PICKUP_ALL)
	_check(ch.inventory.count("core:stick") == 2, "pickup «всё» takes the rest")
